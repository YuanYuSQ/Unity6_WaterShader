Shader "Custom/ToonWater_Interaction"
{
    Properties
    {
        // ==========================================
        // 细分曲面 (Tessellation)
        // ==========================================
        [Header(Tessellation)]
        _TessellationUniform ("细分倍数 (Factor)", Range(1, 64)) = 7
        _TessellationMinDist ("最高精度距离 (Min Dist)", Float) = 3.0
        _TessellationMaxDist ("细分消退距离 (Max Dist)", Float) = 100.0

        // ==========================================
        // 1. 水体颜色与透明度
        // ==========================================
        [Header(1. Color)]
        [HDR] _ShallowColor ("浅水颜色 (Shallow)", Color) = (0.0, 0.45, 0.54, 1.0)
        [HDR] _DeepColor ("深水颜色 (Deep)", Color) = (0.0, 0.162, 0.487, 1.0)
        _DeepRange ("深水感度 (Deep Range)", Float) = 16.19
        _WaterAlpha ("整体透明度 (Alpha)", Range(0, 1)) = 1.0
        _BottomRetain ("水底纹理保留 (Retain)", Range(0, 1)) = 1.0
        _BottomExposure ("水底亮度补偿 (Exposure)", Range(1, 5)) = 1.0
        _DiffuseContribution ("漫反射光照强度 (Diffuse)", Range(0, 1)) = 0

        // ==========================================
        // 2. 菲涅尔与边缘环境泛光
        // ==========================================
        [Header(2. Fresnel Glow)]
        [HDR] _FresnelColor ("边缘泛光滤镜色 (Glow Tint)", Color) = (1.0, 1.0, 1.0, 1.0)
        _FresnelPower ("反射菲涅尔集中度 (Reflection Fresnel Power)", Range(1.0, 100.0)) = 1.0
        _GlowReflectionSplit ("泛光与反射分离度 (Split)", Range(0.0, 1.0)) = 0
        _FresnelGlowPower ("边缘泛光范围集中度 (Glow Power)", Range(0.1, 50.0)) = 36.8
        _FresnelGlowIntensity ("边缘泛光强度 (Glow Intensity)", Range(0.0, 10.0)) = 1.66

        // ==========================================
        // 3. 表面波纹法线
        // ==========================================
        [Header(3. Normal)]
        [Normal] _NormalMap ("波纹法线贴图 (Normal)", 2D) = "bump" {}
        _NormalScale ("波纹凸起强度 (Scale)", Float) = 1.0
        _NormalSpeed ("波纹流动速度 (Speed XY)", Vector) = (0.03, 0.0, 0, 0)

        // ==========================================
        // 4. 水下折射与色散
        // ==========================================
        [Header(4. Distortion)]
        _UnderWaterDistort ("水下折射扭曲力 (Distort)", Float) = 1.57
        _ChromaticAberration ("色散强度 (Chromatic Aberration)", Range(0.0, 5)) = 0.05

        // ==========================================
        // 5. 焦散系统
        // ==========================================
        [Header(5. Caustics)]
        _CausticsTex ("焦散噪波图 (Tex)", 2D) = "black" {}
        _CausticsIntensity ("焦散亮度 (Intensity)", Float) = 3.8
        _CausticsRange ("焦散可见深度 (Range)", Float) = 9.0
        _CausticsSpeed1 ("底层光斑流速 (Speed 1)", Vector) = (0.13, 0.07, 0, 0)
        _CausticsSpeed2 ("表层光斑流速 (Speed 2)", Vector) = (-0.07, -0.04, 0, 0)

        // ==========================================
        // 6. 岸边与动态全向泡沫
        // ==========================================
        [Header(6. Shore and Foam)]
        _EdgeErosion ("岸边消融剔除 (Erosion)", Range(0, 1)) = 0.527
        [HDR] _FoamColor ("泡沫颜色 (Foam Color)", Color) = (1, 1, 1, 1)
        _FoamDistance ("泡沫基础宽度 (Foam Dist)", Float) = 1.33
        _FoamWaveSpeed ("海浪冲刷速度 (Foam Speed)", Float) = 1.36
        _FoamWaveFrequency ("海浪冲刷频次 (Foam Freq)", Float) = -0.11
        _FoamPushPull ("海浪推拉幅度 (Foam Amp)", Float) = 0.27
        _FoamNoiseTex ("泡沫噪波图 (Noise)", 2D) = "white" {}
        _FoamDissolve ("泡沫溶解度 (Dissolve)", Range(0, 1)) = 0.041
        _FoamThickness ("泡沫硬边厚度 (Thickness)", Range(0.01, 0.5)) = 0.066
        _FoamMaxDepth ("泡沫极限水深 (Max Depth)", Float) = 1.03

        // ==========================================
        // 7. 顶点物理波浪
        // ==========================================
        [Header(7. Waves)]
        _WaveA ("主波浪 A (DirX, DirZ, Steep, Length)", Vector) = (5.0, 5.0, 0.15, 10.0)
        _WaveB ("副波浪 B (DirX, DirZ, Steep, Length)", Vector) = (-2.29, 1.0, -0.1, 20.0)
        _WaveC ("碎波浪 C (DirX, DirZ, Steep, Length)", Vector) = (4.0, -4.4, 0.14, 2.89)
        _CrestFoamThreshold ("浪尖起泡高度阈值 (Crest Foam Thr)", Float) = 1.41
        _CrestFoamStrength ("浪尖白沫浓度 (Crest Foam Str)", Float) = 9.18

        // ==========================================
        // 8. 阳光碎斑与 PBR 透光
        // ==========================================
        [Header(8. SSS and Glints and PBR Specular)]
        [HDR] _SSSColor ("浪尖透光颜色 (SSS Color)", Color) = (0.194, 0.991, 1.0, 1.0)
        _SSSIntensity ("透光亮度 (SSS Intensity)", Float) = 4.73
        _SSSPower ("透光集中度 (SSS Power)", Float) = 2.92
        _SSSDistortion ("透光光线偏折 (SSS Distort)", Range(0, 1)) = 0.043

        [HDR] _GlintColor ("波光碎斑颜色 (Glint Color)", Color) = (1.0, 0.891, 0.692, 1.0)
        _GlintScale ("碎斑密集度 (Glint Scale)", Range(1, 50)) = 1.0
        _GlintThreshold ("碎斑过滤阈值 (Glint Thr)", Range(0.1, 1.0)) = 0.506
        _GlintStrength ("碎斑爆发亮度 (Glint Str)", Range(1, 50)) = 14.9
        _GlintSpeed ("碎斑流动速度 (Glint Speed XY)", Vector) = (0.02, 0.02, 0, 0)

        [HDR] _PBRSpecularColor ("PBR 高光颜色 (GGX Color)", Color) = (1.0, 1.0, 1.0, 1.0)
        _PBRSmoothness ("PBR 高光集中度 (GGX Smoothness)", Range(10.0, 1000.0)) = 187
        _PBRSpecularIntensity ("PBR 高光强度 (GGX Intensity)", Range(0.0, 10.0)) = 0

        // ==========================================
        // 10. 水面交互系统 (RenderTexture 高度场)
        // ==========================================
        [Header(10. Water Interaction)]
        [NoScaleOffset] _RippleTex ("涟漪高度图 (运行时自动注入)", 2D) = "black" {}
        _RippleIntensity ("交互涟漪高度强度 (Ripple Height)", Range(0, 5)) = 1.0
        _RippleNormalStrength ("交互涟漪法线扰动 (Normal Strength)", Range(0, 2)) = 0.5
        [HideInInspector] _RippleTexelSize ("涟漪图单个纹素尺寸 (由Simulator自动设置)", Float) = 0.02
        [HideInInspector] _WaterCenter ("水面中心XZ (由Simulator自动设置)", Vector) = (0, 0, 0, 0)

        // ==========================================
        // 11. SSR V13 屏幕空间反射
        // ==========================================
        [Header(11. SSR V13 Module)]
        _SSRIntensity ("倒影总透明度 (SSR Intensity)", Range(0, 1)) = 0
        _SSRMinReflect ("最低反射率 (Min Reflect)", Range(0.0, 1.0)) = 0.143
        _SSRJitter ("倒影噪点抖动 (Jitter)", Range(0.0, 2.0)) = 1.87
        _SSRMaxSteps ("最大步进次数 (Max Steps)", Int) = 20
        _SSRBaseStep ("初始步长 (Base Step)", Float) = 0.1
        _SSRAdaptiveStep ("步长增长率 (Adaptive Step)", Range(0.0, 0.2)) = 0.036
        _SSRBaseThickness ("防穿透容差厚度 (Thickness)", Float) = 0.18
        _SSRRoughness ("倒影粗糙度 → Mipmap模糊层级 (Roughness)", Range(0.0, 1.0)) = 0
        _SSRBrightness ("倒影亮度 (Brightness)", Range(0.0, 3.0)) = 1.2
        _SSRContrast ("倒影对比度 (Contrast)", Range(0.1, 3.0)) = 1
        _SSRWaterPlaneBias ("水面穿透容差 (Water Plane Bias)", Range(0.0, 2.0)) = 0

        // ==========================================
        // 9. 泡沫流动速度
        // ==========================================
        [Header(9. Foam Flow Speed)]
        _FoamSpeed ("泡沫流动速度 (Foam Speed XY)", Vector) = (0.01, 0.01, 0, 0)

        // ==========================================
        // 12. 反射探针过渡
        // ==========================================
        [Header(12. Fallback Probe Reflection)]
        _ProbeIntensity ("反射探针强度 (Probe Intensity)", Range(0.0, 5.0)) = 0.05

        // ==========================================
        // 13. TA 调试视图
        // ==========================================
        [Enum(None, 0, SSR_Only, 1, Probe_Only, 2, Mixed, 3, Normal, 4, Foam, 5, Shore_Gradient, 6, Fresnel_Factor, 7, Fresnel_Glow, 8, Fresnel_Glow_Factor, 9, SSR_LOD_Level, 10, Ripple_Height, 11, Ripple_Normal, 12)] _DebugMode ("Debug view", Float) = 0
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma target 4.6
            #pragma vertex vert
            #pragma hull hullShader
            #pragma domain domainShader
            #pragma fragment frag

            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; float3 normalOS : NORMAL; float4 tangentOS : TANGENT; };
            struct VaryingsTess { float3 positionWS : TEXCOORD0; float2 uv : TEXCOORD1; float3 normalWS : TEXCOORD2; float4 tangentWS : TEXCOORD3; };
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; float4 screenPos : TEXCOORD1; float3 positionWS : TEXCOORD2; float3 normalWS : TEXCOORD3; float3 tangentWS : TEXCOORD4; float3 bitangentWS : TEXCOORD5; float crestFoam : TEXCOORD6; float2 rippleUV : TEXCOORD7; };

            CBUFFER_START(UnityPerMaterial)
                float _TessellationUniform, _TessellationMinDist, _TessellationMaxDist;
                half4 _ShallowColor, _DeepColor, _FresnelColor, _FoamColor;
                float _DeepRange, _WaterAlpha, _BottomRetain, _BottomExposure, _FresnelPower, _NormalScale, _DiffuseContribution;
                float4 _NormalSpeed, _NormalMap_ST;
                float _UnderWaterDistort, _ChromaticAberration, _CausticsIntensity, _CausticsRange;
                float4 _CausticsSpeed1, _CausticsSpeed2, _CausticsTex_ST;
                float _EdgeErosion, _FoamDistance, _FoamPushPull, _FoamDissolve, _FoamThickness, _FoamWaveSpeed, _FoamWaveFrequency;
                float4 _FoamNoiseTex_ST, _WaveA, _WaveB, _WaveC;
                half4 _SSSColor, _GlintColor;
                float _SSSIntensity, _SSSPower, _SSSDistortion, _CrestFoamThreshold, _CrestFoamStrength;
                float _GlintScale, _GlintThreshold, _GlintStrength;
                float4 _GlintSpeed, _FoamSpeed;

                half4 _PBRSpecularColor;
                float _PBRSmoothness, _PBRSpecularIntensity;

                float _RippleIntensity, _RippleNormalStrength, _RippleTexelSize;
                float4 _WaterCenter;

                float _SSRIntensity, _SSRMinReflect, _SSRJitter, _SSRBaseStep, _SSRAdaptiveStep, _SSRBaseThickness;
                float _ProbeIntensity, _FoamMaxDepth, _FresnelGlowPower, _FresnelGlowIntensity, _GlowReflectionSplit;
                float _SSRRoughness, _SSRBrightness, _SSRContrast, _SSRWaterPlaneBias;
                int _SSRMaxSteps;
                float _DebugMode;
            CBUFFER_END

            TEXTURE2D(_NormalMap);      SAMPLER(sampler_NormalMap);
            TEXTURE2D(_CausticsTex);    SAMPLER(sampler_CausticsTex);
            TEXTURE2D(_FoamNoiseTex);   SAMPLER(sampler_FoamNoiseTex);
            TEXTURE2D(_RippleTex);      SAMPLER(sampler_RippleTex);

            float3 GerstnerWave(float3 pWS, float4 wave, float t, inout float3 tan, inout float3 bin) {
                float2 dir = normalize(wave.xy); float k = 6.28 / wave.w; float f = k * (dot(dir, pWS.xz) - length(wave.xy) * t); float a = wave.z / k;
                tan += float3(-dir.x * dir.x * (wave.z * sin(f)), dir.x * (wave.z * cos(f)), -dir.x * dir.y * (wave.z * sin(f)));
                bin += float3(-dir.x * dir.y * (wave.z * sin(f)), dir.y * (wave.z * cos(f)), 1 - dir.y * dir.y * (wave.z * sin(f)));
                return float3(dir.x * (a * cos(f)), a * sin(f), dir.y * (a * cos(f)));
            }

            float3 CalculateWaves(float3 pWS, out float3 tan, out float3 bin) {
                float t = fmod(_Time.y, 3600); tan = float3(1,0,0); bin = float3(0,0,1); float3 o = 0;
                o += GerstnerWave(pWS, _WaveA, t, tan, bin); o += GerstnerWave(pWS, _WaveB, t, tan, bin); o += GerstnerWave(pWS, _WaveC, t, tan, bin); return o;
            }

            VaryingsTess vert (Attributes i) { VaryingsTess o; o.positionWS = TransformObjectToWorld(i.positionOS.xyz); o.uv = i.uv; o.normalWS = TransformObjectToWorldNormal(i.normalOS); o.tangentWS = float4(TransformObjectToWorldDir(i.tangentOS.xyz), i.tangentOS.w); return o; }

            struct TessFactors { float edge[3] : SV_TessFactor; float inside : SV_InsideTessFactor; };

            float CalcTess(float3 p) { float d = distance(p, GetCameraPositionWS()); return lerp(1, _TessellationUniform, saturate((_TessellationMaxDist - d) / (_TessellationMaxDist - _TessellationMinDist))); }

            TessFactors ConstHS(InputPatch<VaryingsTess, 3> p) { TessFactors f; f.edge[0] = (CalcTess(p[1].positionWS) + CalcTess(p[2].positionWS)) * 0.5; f.edge[1] = (CalcTess(p[2].positionWS) + CalcTess(p[0].positionWS)) * 0.5; f.edge[2] = (CalcTess(p[0].positionWS) + CalcTess(p[1].positionWS)) * 0.5; f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) / 3.0; return f; }

            [domain("tri")] [partitioning("fractional_odd")] [outputtopology("triangle_cw")] [outputcontrolpoints(3)] [patchconstantfunc("ConstHS")]
            VaryingsTess hullShader(InputPatch<VaryingsTess, 3> p, uint id : SV_OutputControlPointID) { return p[id]; }

            [domain("tri")]
            Varyings domainShader(TessFactors f, OutputPatch<VaryingsTess, 3> p, float3 bary : SV_DomainLocation) {
                Varyings o;
                float3 pB = p[0].positionWS*bary.x + p[1].positionWS*bary.y + p[2].positionWS*bary.z;
                float3 t, b;
                float3 wO = CalculateWaves(pB, t, b);
                float3 fP = pB + wO;

                // === 水面交互：采样 RenderTexture 高度场 ===
                // UV = worldXZ / worldSize + 0.5，映射世界原点→RT中心
                float2 rippleUV = (fP.xz - _WaterCenter.xy) * _RippleTexelSize * 0.9 + 0.5;
                float rippleHeight = SAMPLE_TEXTURE2D_LOD(_RippleTex, sampler_RippleTex, rippleUV, 0).r;
                fP.y += rippleHeight * _RippleIntensity;

                o.positionWS = fP;
                o.positionCS = TransformWorldToHClip(fP);
                o.screenPos = ComputeScreenPos(o.positionCS);
                o.uv = p[0].uv*bary.x + p[1].uv*bary.y + p[2].uv*bary.z;
                o.normalWS = normalize(cross(b, t));
                o.tangentWS = normalize(t);
                o.bitangentWS = normalize(b);
                o.crestFoam = saturate(((wO.y/3.0) - _CrestFoamThreshold) * _CrestFoamStrength);
                o.rippleUV = rippleUV;    // 传递到片元，用于法线扰动计算
                return o;
            }

            half4 frag (Varyings input) : SV_Target
            {
                // ==========================================
                // 1. 深度与法线采样
                // ==========================================
                float2 pureScreenUV = input.screenPos.xy / input.screenPos.w;
                float rawZ = SampleSceneDepth(pureScreenUV);
                float sceneZ = LinearEyeDepth(rawZ, _ZBufferParams);
                float surfZ = input.screenPos.w;
                float depthDiff = max(0, sceneZ - surfZ);

                // 双层法线混合
                half3 n1 = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv * _NormalMap_ST.xy + _Time.y * _NormalSpeed.xy), _NormalScale);
                half3 n2 = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv * _NormalMap_ST.zw + _Time.y * _NormalSpeed.zw), _NormalScale);
                half3 tangentN = normalize(n1 + n2);

                // === 交互涟漪法线扰动 ===
                // 用 positionWS 直接算 UV，不走 Varyings 插值（避免 hull/domain 阶段的语义传递问题）
                float2 rippleUV = (input.positionWS.xz - _WaterCenter.xy) * _RippleTexelSize * 0.9 + 0.5;
                float rippleH = SAMPLE_TEXTURE2D(_RippleTex, sampler_RippleTex, rippleUV).r;
                float rippleR = SAMPLE_TEXTURE2D(_RippleTex, sampler_RippleTex, rippleUV + float2(_RippleTexelSize, 0)).r;
                float rippleU = SAMPLE_TEXTURE2D(_RippleTex, sampler_RippleTex, rippleUV + float2(0, _RippleTexelSize)).r;
                float2 rippleGrad = float2(rippleR - rippleH, rippleU - rippleH) * _RippleNormalStrength * _RippleIntensity;
                tangentN.xy += rippleGrad;
                tangentN = normalize(tangentN);

                half3 finalN = normalize(tangentN.x * input.tangentWS + tangentN.y * input.bitangentWS + tangentN.z * input.normalWS);

                // ==========================================
                // 2. 水下折射与色散
                // ==========================================
                float distortMask = smoothstep(0.0, 0.5, depthDiff);
                float2 distOffset = tangentN.xy * _UnderWaterDistort * 0.01 * distortMask;

                float2 uvG = pureScreenUV + distOffset;
                float2 uvR = pureScreenUV + distOffset * (1.0 + _ChromaticAberration);
                float2 uvB = pureScreenUV + distOffset * (1.0 - _ChromaticAberration);

                float rawZDist = SampleSceneDepth(uvG);
                float sceneZDist = LinearEyeDepth(rawZDist, _ZBufferParams);

                if (sceneZDist < surfZ) {
                    uvR = pureScreenUV; uvG = pureScreenUV; uvB = pureScreenUV;
                    rawZDist = rawZ; sceneZDist = sceneZ;
                }
                float depthDiffDist = max(0, sceneZDist - surfZ);
                float3 seabedWS = ComputeWorldSpacePosition(uvG, rawZDist, UNITY_MATRIX_I_VP);

                // ==========================================
                // 3. 全向海岸线梯度雷达 (动态白沫)
                // ==========================================
                float2 texelSize = float2(1.0 / _ScreenParams.x, 1.0 / _ScreenParams.y);
                float depthL = LinearEyeDepth(SampleSceneDepth(pureScreenUV + float2(-texelSize.x, 0)), _ZBufferParams);
                float depthR = LinearEyeDepth(SampleSceneDepth(pureScreenUV + float2(texelSize.x, 0)), _ZBufferParams);
                float depthB = LinearEyeDepth(SampleSceneDepth(pureScreenUV + float2(0, -texelSize.y)), _ZBufferParams);
                float depthT = LinearEyeDepth(SampleSceneDepth(pureScreenUV + float2(0, texelSize.y)), _ZBufferParams);

                float2 shoreGrad = float2(depthL - depthR, depthB - depthT);
                float gradLen = length(shoreGrad);
                float2 shoreDir = gradLen > 0.001 ? shoreGrad / gradLen : float2(0, 0);

                float2 foamUV = input.positionWS.xz * _FoamNoiseTex_ST.xy + _Time.y * _FoamSpeed.xy;
                float wavePush = sin(_Time.y * _FoamWaveSpeed - depthDiffDist * _FoamWaveFrequency) * _FoamPushPull;
                float dynamicFoamDist = _FoamDistance + wavePush;

                float fN = SAMPLE_TEXTURE2D(_FoamNoiseTex, sampler_FoamNoiseTex, foamUV).r;
                clip(depthDiffDist - (1.0 - fN) * _EdgeErosion);

                float depthCutoff = 1.0 - smoothstep(0.0, _FoamMaxDepth, depthDiffDist);
                float foamMask = smoothstep(_FoamDissolve, _FoamDissolve + _FoamThickness, (1.0 - saturate(depthDiffDist / max(dynamicFoamDist, 0.01))) * fN * depthCutoff);
                float totalFoam = saturate(max(foamMask, input.crestFoam * fN));

                // ==========================================
                // 4. 水体吸收与焦散渲染
                // ==========================================
                half r = SampleSceneColor(uvR).r;
                half g = SampleSceneColor(uvG).g;
                half b = SampleSceneColor(uvB).b;
                half3 refrCol = half3(r, g, b);

                float fogFactor = pow(saturate(depthDiffDist / max(_DeepRange, 0.01)), 0.8);
                half3 waterBaseColor = lerp(_ShallowColor.rgb, _DeepColor.rgb, fogFactor);
                half3 finalBottom = lerp(waterBaseColor, refrCol * waterBaseColor * _BottomExposure, _BottomRetain);
                half3 finalWaterColor = lerp(refrCol, finalBottom, lerp(_ShallowColor.a, _DeepColor.a, fogFactor) * _WaterAlpha);

                float causticsFade = pow(smoothstep(_CausticsRange, 0.0, depthDiffDist), 2.0);
                float2 cauUV = seabedWS.xz * _CausticsTex_ST.xy + _CausticsTex_ST.zw;
                half3 cauCol = min(
                    SAMPLE_TEXTURE2D(_CausticsTex, sampler_CausticsTex, cauUV + _Time.y * _CausticsSpeed1.xy).rgb,
                    SAMPLE_TEXTURE2D(_CausticsTex, sampler_CausticsTex, cauUV + _Time.y * _CausticsSpeed2.xy).rgb
                );
                finalWaterColor += cauCol * lerp(half3(1, 1, 1), waterBaseColor, 0.6) * _CausticsIntensity * causticsFade;

                // ==========================================
                // 5. 基础光照 (漫反射 NdotL)
                // ==========================================
                Light mainLight = GetMainLight();
                float3 viewDir = normalize(GetCameraPositionWS() - input.positionWS);
                float NdotL = saturate(dot(finalN, mainLight.direction));
                float NdotV = saturate(dot(finalN, viewDir));

                half3 surfaceDiffuse = mainLight.color * NdotL * waterBaseColor * _DiffuseContribution;
                finalWaterColor += surfaceDiffuse;

                // ==========================================
                // 6. SSR 倒影与环境探针混合
                // ==========================================
                float3 rDir = reflect(-viewDir, finalN);

                half3 ssrColor = half3(0,0,0);
                float ssrWeight = 0;
                float jitter = frac(sin(dot(pureScreenUV * _ScreenParams.xy, float2(12.9898, 78.233))) * 43758.5453);
                float3 rP = input.positionWS + rDir * 0.1 + rDir * _SSRBaseStep * jitter * _SSRJitter;
                float currentStepSize = _SSRBaseStep;

                [loop]
                for(int i = 0; i < 150; i++)
                {
                    if(i >= _SSRMaxSteps) break;
                    currentStepSize += currentStepSize * _SSRAdaptiveStep;
                    rP += rDir * currentStepSize;
                    float4 rCP = TransformWorldToHClip(rP);
                    float2 rUV = ComputeScreenPos(rCP).xy / rCP.w;

                    if(rUV.x < 0 || rUV.x > 1 || rUV.y < 0 || rUV.y > 1) break;
                    if(rP.y < input.positionWS.y - _SSRWaterPlaneBias) break;

                    float sceneDepthSSR = LinearEyeDepth(SampleSceneDepth(rUV), _ZBufferParams);
                    if(sceneDepthSSR - rCP.w > 0 && sceneDepthSSR - rCP.w < (_SSRBaseThickness + i * _SSRAdaptiveStep))
                    {
                        float blurLOD = _SSRRoughness * 5.0;
                        ssrColor = SAMPLE_TEXTURE2D_LOD(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, rUV, blurLOD).rgb;
                        ssrWeight = 1.0 - saturate(max(abs(rUV.x * 2 - 1), abs(rUV.y * 2 - 1)));
                        break;
                    }
                }

                if(ssrWeight > 0.001)
                {
                    ssrColor *= _SSRBrightness;
                    ssrColor = saturate((ssrColor - 0.5) * _SSRContrast + 0.5);
                }

                half3 probeColor = half3(0,0,0);
                #if defined(_FORWARD_PLUS)
                    probeColor = GlossyEnvironmentReflection(rDir, input.positionWS, 0.0, 1.0, pureScreenUV);
                #else
                    probeColor = GlossyEnvironmentReflection(rDir, input.positionWS, 0.0, 1.0);
                #endif
                if (Luminance(probeColor) < 0.01) {
                    half4 rawCube = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, rDir, 0);
                    probeColor = DecodeHDREnvironment(rawCube, unity_SpecCube0_HDR);
                }
                half3 rawProbe = probeColor;
                probeColor *= _ProbeIntensity;

                half3 finalReflection = lerp(probeColor, ssrColor, ssrWeight);

                // ==========================================
                // 7. 高级物理环境泛光
                // ==========================================
                float fresnelFactor = pow(1.0 - NdotV, _FresnelPower);
                float fresnelWeight = lerp(_SSRMinReflect, 1.0, fresnelFactor);
                float fresnelGlowFactor = pow(1.0 - NdotV, _FresnelGlowPower);
                half3 envGlowColor = rawProbe;
                half3 mixedGlowColor = envGlowColor * _FresnelColor.rgb;

                float glowDepthFade = 1.0 - smoothstep(0.0, _DeepRange * 0.5, depthDiffDist);
                half3 fresnelGlow = mixedGlowColor * fresnelGlowFactor * _FresnelGlowIntensity * glowDepthFade;

                float reflectionMask = lerp(1.0, 1.0 - fresnelFactor, _GlowReflectionSplit);
                finalWaterColor = lerp(finalWaterColor, finalReflection, _SSRIntensity * fresnelWeight * reflectionMask);
                finalWaterColor += fresnelGlow;

                // ==========================================
                // 8. 太阳高光与光透 (碎斑 + PBR GGX + SSS)
                // ==========================================
                float3 h = normalize(mainLight.direction + viewDir);

                float gN = SAMPLE_TEXTURE2D(_FoamNoiseTex, sampler_FoamNoiseTex, input.positionWS.xz * _FoamNoiseTex_ST.xy * _GlintScale + _Time.y * _GlintSpeed.xy).r;
                half3 specG = _GlintColor.rgb * smoothstep(_GlintThreshold, _GlintThreshold + 0.05, pow(saturate(dot(finalN, h)), 16.0) * gN) * _GlintStrength * mainLight.color * fresnelFactor;

                half3 sssE = _SSSColor.rgb * pow(saturate(dot(viewDir, -normalize(mainLight.direction + finalN * _SSSDistortion))), _SSSPower) * _SSSIntensity * mainLight.color;

                float NdotH = saturate(dot(finalN, h));
                float roughness = (2.0 / (_PBRSmoothness + 2.0));
                float D = (roughness * roughness) / (PI * pow(NdotH * NdotH * (roughness * roughness - 1.0) + 1.0, 2.0));
                half3 pbrSpecular = _PBRSpecularColor.rgb * mainLight.color * D * _PBRSpecularIntensity * NdotL;

                finalWaterColor += specG + sssE + pbrSpecular;
                finalWaterColor = lerp(finalWaterColor, _FoamColor.rgb, totalFoam * _FoamColor.a);

                // ==========================================
                // 9. TA 调试视图 (Debug Mode)
                // ==========================================
                if (_DebugMode == 1.0) return half4(ssrColor * ssrWeight, 1.0);
                if (_DebugMode == 2.0) return half4(probeColor, 1.0);
                if (_DebugMode == 3.0) return half4(finalReflection, 1.0);
                if (_DebugMode == 4.0) return half4(finalN * 0.5 + 0.5, 1.0);
                if (_DebugMode == 5.0) return half4(totalFoam, totalFoam, totalFoam, 1.0);
                if (_DebugMode == 6.0) return half4(shoreDir * 0.5 + 0.5, 0.0, 1.0);
                if (_DebugMode == 7.0) return half4(fresnelFactor, fresnelFactor, fresnelFactor, 1.0);
                if (_DebugMode == 8.0) return half4(fresnelGlow, 1.0);
                if (_DebugMode == 9.0) return half4(fresnelGlowFactor, fresnelGlowFactor, fresnelGlowFactor, 1.0);
                if (_DebugMode == 10.0) return half4(_SSRRoughness.xxx, 1.0);
                // 诊断用：Debug 11 = 固定UV(0.5,0.5)采样 → 排除UV映射问题
                if (_DebugMode == 11.0) {
                    float diagH = SAMPLE_TEXTURE2D(_RippleTex, sampler_RippleTex, float2(0.5, 0.5)).r;
                    return half4(diagH, rippleH, 0, 1);  // R=RT中心, G=当前像素UV采样, B=0
                }
                if (_DebugMode == 12.0) return half4(rippleGrad * 0.5 + 0.5, 0.0, 1.0);

                return half4(finalWaterColor, 1.0);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
