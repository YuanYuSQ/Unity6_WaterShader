using System.Collections.Generic;
using UnityEngine;

namespace WaterReview20260923
{
    /// <summary>World XZ height/velocity wave field. No edit-mode allocation or shared material writes.</summary>
    [DisallowMultipleComponent, DefaultExecutionOrder(100)]
    public sealed class WaterRippleSimulation : MonoBehaviour
    {
        [Header("绑定水面")]
        [Tooltip("水平水面；范围取此 Renderer 的世界包围盒。运行中移动水面会清空旧波纹。")]
        public Renderer waterRenderer;
        [Min(0)] public int materialIndex;
        public Shader simulationShader;
        [Header("传播与质量")]
        [Tooltip("256 较省；512 适合当前约 65 米水面。改分辨率后重新启用组件。")]
        [Range(64, 1024)] public int resolution = 512;
        [Min(0.1f), InspectorName("传播速度（米/秒）")] public float waveSpeed = 3;
        [Min(0.01f), InspectorName("衰减（每秒）")] public float damping = 1.2f;
        [Min(0.1f), InspectorName("边界吸收宽度（米）")] public float edgeAbsorption = 3;
        [Range(0.01f, 1), InspectorName("最大波高（米）")] public float maxHeight = 0.35f;

        public const float StepSeconds = 1f / 60;
        public const int MaxImpulses = 32;
        const int MaxCatchupSteps = 4;
        static readonly Dictionary<Renderer, WaterRippleSimulation> Owners = new Dictionary<Renderer, WaterRippleSimulation>();
        static readonly int TextureID = Shader.PropertyToID("_RippleTex");
        static readonly int ReadyID = Shader.PropertyToID("_RippleReady");
        static readonly int OriginID = Shader.PropertyToID("_RippleOriginSize");
        static readonly int GridID = Shader.PropertyToID("_RippleGrid");
        static readonly int ImpulsesID = Shader.PropertyToID("_Impulses");
        static readonly int CountID = Shader.PropertyToID("_ImpulseCount");
        static readonly int ParamsID = Shader.PropertyToID("_Simulation");
        static readonly int LimitsID = Shader.PropertyToID("_Limits");
        Vector4[] impulses;
        MaterialPropertyBlock block;
        RenderTexture current, next;
        Material simulationMaterial, waterMaterial;
        Renderer boundRenderer;
        int boundSlot, queued;
        Vector4 originSize, grid;
        float accumulator, baseHeight;
        Vector4 waveA, waveB, waveC;
        float previewUntil, nextPreview;
        Vector3 previewPoint;
        static readonly Vector2[] PreviewCandidates = { new Vector2(.5f,.4f), new Vector2(.4f,.4f), new Vector2(.6f,.4f), new Vector2(.5f,.55f), new Vector2(.3f,.5f), new Vector2(.7f,.5f) };

        public bool IsReady => current != null && current.IsCreated();
        public RenderTexture HeightTexture => current;
        public Vector4 OriginSize => originSize;
        public float CellSize => Mathf.Max(grid.z, grid.w);
        public float EffectiveWaveSpeed { get; private set; }
        public int LastStepCount { get; private set; }
        public int DroppedImpulses { get; private set; }
        public int DroppedCatchupFrames { get; private set; }
        public int AcceptedImpulses { get; private set; }
        public bool PreviewActive => IsReady && previewUntil > Time.time;
        public string PreviewMessage { get; private set; }

        void OnEnable()
        {
            if (!Application.isPlaying) return;
            block = new MaterialPropertyBlock();
            impulses = new Vector4[MaxImpulses];
            if (waterRenderer == null || simulationShader == null || !simulationShader.isSupported ||
                !SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.RGFloat))
            { Fail("请绑定水面和传播 Shader，并确认设备支持 RGFloat。"); return; }
            var materials = waterRenderer.sharedMaterials;
            if (materialIndex < 0 || materialIndex >= materials.Length || materials[materialIndex] == null)
            { Fail("水面材质槽无效。"); return; }
            waterMaterial = materials[materialIndex];
            if (!waterMaterial.HasProperty(ReadyID)) { Fail("请使用新版 Reviewed 水体 Shader。"); return; }
            if (Owners.TryGetValue(waterRenderer, out var owner) && owner != null && owner != this)
            { Fail("此水面已有一个涟漪模拟器。"); return; }
            boundRenderer = waterRenderer; boundSlot = materialIndex;
            Owners[boundRenderer] = this;
            resolution = Mathf.ClosestPowerOfTwo(Mathf.Clamp(resolution, 64, 1024));
            simulationMaterial = new Material(simulationShader) { hideFlags = HideFlags.HideAndDontSave };
            current = CreateTexture("WaterRipple HeightVelocity A");
            next = CreateTexture("WaterRipple HeightVelocity B");
            if (!current.IsCreated() || !next.IsCreated()) { Fail("涟漪纹理创建失败。"); return; }
            UpdateBounds(true);
            ReadWaves();
            Bind();
        }

        void Fail(string message)
        {
            Debug.LogError("[WaterRippleSimulation] " + message, this);
            enabled = false; // One error per enable, never a per-frame log loop.
        }

        RenderTexture CreateTexture(string label)
        {
            var rt = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.RGFloat, RenderTextureReadWrite.Linear)
            { name = label, filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp, useMipMap = false,
                autoGenerateMips = false, hideFlags = HideFlags.HideAndDontSave };
            rt.Create();
            return rt;
        }

        void UpdateBounds(bool force)
        {
            Bounds b = boundRenderer.bounds;
            var value = new Vector4(b.center.x, b.center.z, Mathf.Max(b.size.x, 0.1f), Mathf.Max(b.size.z, 0.1f));
            baseHeight = b.center.y;
            if (!force && (value - originSize).sqrMagnitude < 0.000001f) return;
            originSize = value;
            grid = new Vector4(1f / current.width, 1f / current.height, value.z / current.width, value.w / current.height);
            ClearRipples();
        }

        public void ClearRipples()
        {
            queued = 0; accumulator = 0;
            if (!IsReady) return;
            var old = RenderTexture.active;
            RenderTexture.active = current; GL.Clear(false, true, Color.clear);
            RenderTexture.active = next; GL.Clear(false, true, Color.clear);
            RenderTexture.active = old;
        }

        void ReadWaves()
        {
            if (waterMaterial == null) return;
            waveA = waterMaterial.GetVector("_WaveA");
            waveB = waterMaterial.GetVector("_WaveB");
            waveC = waterMaterial.GetVector("_WaveC");
        }

        void LateUpdate()
        {
            LastStepCount = 0;
            if (!IsReady) return;
            if (boundRenderer == null) { enabled = false; return; }
            UpdateBounds(false); ReadWaves();
            if (PreviewActive && Time.time >= nextPreview)
            {
                EmitRipple(previewPoint, 1.8f, -6);
                nextPreview = Time.time + 1.5f;
            }
            // Fixed timestep; discard excess debt after a stalled frame instead of a CPU/GPU catchup spiral.
            accumulator += Mathf.Max(0, Time.deltaTime);
            if (accumulator > MaxCatchupSteps * StepSeconds) { accumulator = MaxCatchupSteps * StepSeconds; DroppedCatchupFrames++; }
            EffectiveWaveSpeed = Mathf.Min(Mathf.Max(0.1f, waveSpeed),
                0.9f / (StepSeconds * Mathf.Sqrt(1 / (grid.z * grid.z) + 1 / (grid.w * grid.w))));
            simulationMaterial.SetVector(GridID, grid);
            simulationMaterial.SetVector(OriginID, originSize);
            simulationMaterial.SetVector(ParamsID, new Vector4(StepSeconds, EffectiveWaveSpeed * EffectiveWaveSpeed,
                Mathf.Max(0.01f, damping), Mathf.Max(CellSize * 2, edgeAbsorption)));
            simulationMaterial.SetVector(LimitsID, new Vector4(Mathf.Clamp(maxHeight, 0.01f, 1), 8, 0, 0));
            var previousTarget = RenderTexture.active;
            bool previousSRGB = GL.sRGBWrite;
            GL.sRGBWrite = false;
            try
            {
                while (accumulator + 1e-6f >= StepSeconds && LastStepCount < MaxCatchupSteps)
                {
                    simulationMaterial.SetInt(CountID, queued);
                    if (queued > 0) simulationMaterial.SetVectorArray(ImpulsesID, impulses);
                    Graphics.Blit(current, next, simulationMaterial, 0);
                    var swap = current; current = next; next = swap;
                    queued = 0; accumulator = Mathf.Max(0, accumulator - StepSeconds); LastStepCount++;
                }
            }
            finally { GL.sRGBWrite = previousSRGB; RenderTexture.active = previousTarget; }
            Bind();
        }

        void Bind()
        {
            if (boundRenderer == null) return;
            boundRenderer.GetPropertyBlock(block, boundSlot);
            block.SetTexture(TextureID, current);
            block.SetFloat(ReadyID, 1);
            block.SetVector(OriginID, originSize);
            block.SetVector(GridID, grid);
            boundRenderer.SetPropertyBlock(block, boundSlot);
        }

        /// <summary>Enqueue a signed vertical velocity impulse, in m/s. Radius is a world-space radius.</summary>
        public bool EmitRipple(Vector3 position, float radius, float velocity)
        {
            if (!IsReady || !Finite(position.x) || !Finite(position.z) || !Finite(radius) || !Finite(velocity)) return false;
            float x = position.x - originSize.x, z = position.z - originSize.y;
            if (Mathf.Abs(x) >= originSize.z * 0.5f || Mathf.Abs(z) >= originSize.w * 0.5f) return false;
            if (queued == MaxImpulses) { DroppedImpulses++; return false; }
            impulses[queued++] = new Vector4(x, z, Mathf.Clamp(radius, CellSize * 2, Mathf.Min(originSize.z, originSize.w) * 0.25f), Mathf.Clamp(velocity, -8, 8));
            AcceptedImpulses++;
            return true;
        }

        static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);

        // CPU contact plane follows the three rendered Gerstner waves, without a GPU readback.
        // Fixed-point inversion compensates horizontal displacement; excludes the small ripple itself.
        public float SurfaceHeight(Vector3 worldPosition)
        {
            Vector2 target = new Vector2(worldPosition.x, worldPosition.z), source = target;
            float time = Time.time;
            for (int i = 0; i < 4; i++)
            {
                Vector3 d = Wave(source, waveA, time) + Wave(source, waveB, time) + Wave(source, waveC, time);
                source = target - new Vector2(d.x, d.z);
            }
            return baseHeight + Wave(source, waveA, time).y + Wave(source, waveB, time).y + Wave(source, waveC, time).y;
        }

        static Vector3 Wave(Vector2 p, Vector4 wave, float time)
        {
            Vector2 dir = new Vector2(wave.x, wave.y); float speed = dir.magnitude;
            if (speed < 1e-5f || Mathf.Abs(wave.w) < 1e-4f) return Vector3.zero;
            dir /= speed;
            float k = 2 * Mathf.PI / Mathf.Max(Mathf.Abs(wave.w), 0.01f);
            float phase = Mathf.Repeat(k * (Vector2.Dot(dir, p) - speed * time), 2 * Mathf.PI);
            float a = Mathf.Clamp(wave.z, -0.95f, 0.95f) / k;
            return new Vector3(dir.x * a * Mathf.Cos(phase), a * Mathf.Sin(phase), dir.y * a * Mathf.Cos(phase));
        }

        [ContextMenu("测试：镜头前连续涟漪（12秒）")]
        public void StartVisiblePreview()
        {
            previewUntil = 0;
            if (!Application.isPlaying || !IsReady) { PreviewMessage = "请先进入 Play，并启用模拟器。"; return; }
            if (Time.timeScale <= 0) { PreviewMessage = "时间倍率为 0，请恢复运行后测试。"; return; }
            var cam = Camera.main;
            if (cam == null) { PreviewMessage = "未找到标记为 MainCamera 的相机。"; return; }
            var plane = new Plane(Vector3.up, new Vector3(0, baseHeight, 0));
            foreach (var viewport in PreviewCandidates)
            {
                var ray = cam.ViewportPointToRay(viewport);
                if (!plane.Raycast(ray, out float distance)) continue;
                Vector3 point = ray.GetPoint(distance);
                if (Mathf.Abs(point.x-originSize.x) > originSize.z*.5f-4 || Mathf.Abs(point.z-originSize.y) > originSize.w*.5f-4) continue;
                // Avoid placing the demonstration behind an opaque collider, such as the central rock.
                if (Physics.Raycast(ray, out var hit, Mathf.Max(0, distance-1), cam.cullingMask, QueryTriggerInteraction.Ignore)
                    && hit.collider.gameObject != boundRenderer.gameObject) continue;
                previewPoint = point;
                ClearRipples();
                previewUntil = Time.time + 12;
                nextPreview = Time.time;
                PreviewMessage = "正在镜头前测试：半径 1.8 米、力度 6，每 1.5 秒一圈，持续 12 秒。";
                return;
            }
            PreviewMessage = "镜头前没有找到无遮挡的水面，请对准开阔水面再测试。";
        }

        public void StopVisiblePreview() { previewUntil = 0; PreviewMessage = "测试已停止。"; ClearRipples(); }

        void OnDisable()
        {
            previewUntil = 0;
            if (boundRenderer != null && block != null && Owners.TryGetValue(boundRenderer, out var owner) && owner == this)
            {
                boundRenderer.GetPropertyBlock(block, boundSlot);
                block.SetFloat(ReadyID, 0); block.SetTexture(TextureID, Texture2D.blackTexture);
                boundRenderer.SetPropertyBlock(block, boundSlot); Owners.Remove(boundRenderer);
            }
            Release(current); Release(next); current = next = null;
            if (simulationMaterial != null) Destroy(simulationMaterial);
            simulationMaterial = null; boundRenderer = null; waterMaterial = null; queued = 0; accumulator = 0;
        }
        static void Release(RenderTexture texture) { if (texture != null) { texture.Release(); Destroy(texture); } }
    }
}
