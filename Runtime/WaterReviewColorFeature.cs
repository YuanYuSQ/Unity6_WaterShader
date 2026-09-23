using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

namespace WaterReview20260923
{
    /// <summary>Independent opaque reflection mip chain and optional pre-water transparent background.</summary>
    public sealed class WaterReviewColorFeature : ScriptableRendererFeature
    {
        [Tooltip("Optional transparent-only layers. Exclude the same layers from this renderer's normal Transparent Layer Mask. Do not include Water.")]
        public LayerMask preWaterTransparentLayers;
        [Tooltip("Optional: skips the reflection mip chain when SSR is disabled on this material.")]
        public Material waterMaterial;
        [Range(1, 4)] public int reflectionDownsample = 2;
        [Range(1, 4)] public int refractionDownsample = 1;
        [System.NonSerialized] public int lastReflectionWidth, lastReflectionHeight, lastReflectionMipCount;
        [System.NonSerialized] public bool requestMipReadback;
        [System.NonSerialized] public string mipReadbackResult = "Not requested";
        ColorPass pass;

        public override void Create()
        {
            pass = new ColorPass(this) { renderPassEvent = RenderPassEvent.BeforeRenderingTransparents };
            pass.ConfigureInput(ScriptableRenderPassInput.Color | ScriptableRenderPassInput.Depth);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (pass != null) renderer.EnqueuePass(pass);
        }

        sealed class ColorPass : ScriptableRenderPass
        {
            static readonly int ReflectionTex = Shader.PropertyToID("_WaterReviewReflectionTexture");
            static readonly int BackgroundTex = Shader.PropertyToID("_WaterReviewBackgroundTexture");
            static readonly int ColorInfo = Shader.PropertyToID("_WaterReviewColorInfo");
            static readonly int BackgroundInfo = Shader.PropertyToID("_WaterReviewBackgroundInfo");
            static readonly List<ShaderTagId> Tags = new List<ShaderTagId>
            {
                new ShaderTagId("UniversalForward"), new ShaderTagId("UniversalForwardOnly"), new ShaderTagId("SRPDefaultUnlit")
            };
            readonly WaterReviewColorFeature owner;
            public ColorPass(WaterReviewColorFeature owner) { this.owner = owner; }
            sealed class CopyData { public TextureHandle source, target; public bool mip; public Vector4 info; public int infoId; public WaterReviewColorFeature owner; }
            sealed class DrawData { public RendererListHandle list; }
            sealed class ResetData { }

            public override void RecordRenderGraph(RenderGraph graph, ContextContainer frame)
            {
                var camera = frame.Get<UniversalCameraData>();
                var resources = frame.Get<UniversalResourceData>();
                using (var builder = graph.AddUnsafePass<ResetData>("Water Review: reset camera bindings", out _))
                {
                    builder.AllowGlobalStateModification(true);
                    builder.AllowPassCulling(false);
                    builder.SetRenderFunc((ResetData data, UnsafeGraphContext context) =>
                    {
                        context.cmd.SetGlobalVector(ColorInfo, Vector4.zero);
                        context.cmd.SetGlobalVector(BackgroundInfo, Vector4.zero);
                    });
                }
                if (camera.camera == null || camera.cameraType == CameraType.Preview ||
                    camera.cameraType == CameraType.Reflection || camera.camera.targetTexture != null ||
                    resources.isActiveTargetBackBuffer || !resources.activeColorTexture.IsValid()) return;

                // Before transparents: this color has the same opaque geometry as the sampled scene depth.
                bool debug = owner.waterMaterial != null && owner.waterMaterial.IsKeywordEnabled("_WATER_DEBUG");
                bool needReflection = owner.waterMaterial == null ||
                    (owner.waterMaterial.IsKeywordEnabled("_WATER_SSR") &&
                    (owner.waterMaterial.GetFloat("_SSRIntensity") > 0f || debug));
                if (!needReflection) owner.lastReflectionMipCount = 0;
                if (needReflection)
                    Copy(graph, resources.activeColorTexture, camera.cameraTargetDescriptor,
                        Mathf.Clamp(owner.reflectionDownsample, 1, 4), true, ReflectionTex, ColorInfo,
                        "Water Review: opaque reflection mip chain");

                int layers = owner.preWaterTransparentLayers.value & camera.camera.cullingMask;
                if (layers != 0 && resources.activeDepthTexture.IsValid())
                {
                    var rendering = frame.Get<UniversalRenderingData>();
                    var lights = frame.Get<UniversalLightData>();
                    var drawing = RenderingUtils.CreateDrawingSettings(Tags, rendering, camera, lights, SortingCriteria.CommonTransparent);
                    var filtering = new FilteringSettings(RenderQueueRange.transparent, layers);
                    var list = graph.CreateRendererList(new RendererListParams(rendering.cullResults, drawing, filtering));
                    using (var builder = graph.AddRasterRenderPass<DrawData>("Water Review: pre-water transparents", out var data))
                    {
                        data.list = list;
                        builder.UseRendererList(list);
                        builder.SetRenderAttachment(resources.activeColorTexture, 0, AccessFlags.ReadWrite);
                        builder.SetRenderAttachmentDepth(resources.activeDepthTexture, AccessFlags.ReadWrite);
                        builder.UseAllGlobalTextures(true);
                        builder.SetRenderFunc((DrawData d, RasterGraphContext context) => context.cmd.DrawRendererList(d.list));
                    }
                }
                Copy(graph, resources.activeColorTexture, camera.cameraTargetDescriptor,
                    Mathf.Clamp(owner.refractionDownsample, 1, 4), false, BackgroundTex, BackgroundInfo,
                    "Water Review: refraction background");
            }

            void Copy(RenderGraph graph, TextureHandle source, RenderTextureDescriptor descriptor,
                int downsample, bool mip, int textureId, int infoId, string label)
            {
                descriptor.width = Mathf.Max(1, descriptor.width / downsample);
                descriptor.height = Mathf.Max(1, descriptor.height / downsample);
                descriptor.depthBufferBits = 0;
                descriptor.msaaSamples = 1;
                descriptor.bindMS = false;
                descriptor.useMipMap = mip;
                descriptor.autoGenerateMips = false;
                descriptor.mipCount = mip ? 0 : 1;
                descriptor.useDynamicScale = false;
                // URP's RenderTextureDescriptor helper does not copy useMipMap in 17.4.
                // Describe the RenderGraph resource directly so GenerateMips has real storage.
                var texture = new TextureDesc(descriptor.width, descriptor.height)
                {
                    name = label, format = descriptor.graphicsFormat, dimension = descriptor.dimension,
                    slices = descriptor.volumeDepth, msaaSamples = MSAASamples.None,
                    useMipMap = mip, autoGenerateMips = false, useDynamicScale = false,
                    filterMode = mip ? FilterMode.Trilinear : FilterMode.Bilinear,
                    wrapMode = TextureWrapMode.Clamp, clearBuffer = false
                };
                var destination = graph.CreateTexture(texture);
                using (var builder = graph.AddUnsafePass<CopyData>(label, out var data))
                {
                    data.source = source; data.target = destination; data.mip = mip; data.infoId = infoId; data.owner = owner;
                    data.info = new Vector4(descriptor.width, descriptor.height,
                        mip ? Mathf.Floor(Mathf.Log(Mathf.Max(descriptor.width, descriptor.height), 2f)) : 0f, 1f);
                    builder.UseTexture(source, AccessFlags.Read);
                    builder.UseTexture(destination, AccessFlags.ReadWrite);
                    builder.AllowGlobalStateModification(true);
                    builder.SetGlobalTextureAfterPass(destination, textureId);
                    builder.AllowPassCulling(false);
                    builder.SetRenderFunc((CopyData d, UnsafeGraphContext context) =>
                    {
                        var cmd = CommandBufferHelpers.GetNativeCommandBuffer(context.cmd);
                        Blitter.BlitCameraTexture(cmd, d.source, d.target, 0f, true);
                        if (d.mip)
                        {
                            RTHandle target = d.target;
                            cmd.GenerateMips(target.nameID);
                            d.owner.lastReflectionWidth = target.rt.width;
                            d.owner.lastReflectionHeight = target.rt.height;
                            d.owner.lastReflectionMipCount = target.rt.mipmapCount;
                            if (d.owner.requestMipReadback && SystemInfo.supportsAsyncGPUReadback)
                            {
                                d.owner.requestMipReadback = false;
                                var reportOwner = d.owner;
                                int level = Mathf.Min(3, target.rt.mipmapCount - 1);
                                cmd.RequestAsyncReadback(target.rt, level, TextureFormat.RGBAFloat, request =>
                                {
                                    if (reportOwner == null) return;
                                    if (request.hasError) { reportOwner.mipReadbackResult = "GPU readback error"; return; }
                                    var pixels = request.GetData<float>();
                                    int invalid = 0; double sum = 0, square = 0; int count = 0;
                                    for (int i = 0; i + 3 < pixels.Length; i += 4)
                                    {
                                        float value = (pixels[i] + pixels[i + 1] + pixels[i + 2]) / 3f;
                                        if (float.IsNaN(value) || float.IsInfinity(value)) invalid++;
                                        else { sum += value; square += value * value; count++; }
                                    }
                                    double mean = sum / System.Math.Max(count, 1);
                                    reportOwner.mipReadbackResult = $"Mip {level}: pixels={count}, invalid={invalid}, mean={mean:F5}, variance={square / System.Math.Max(count, 1) - mean * mean:F5}";
                                });
                            }
                        }
                        cmd.SetGlobalVector(d.infoId, d.info);
                    });
                }
            }
        }
    }
}
