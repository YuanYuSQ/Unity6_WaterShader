Shader "Custom/ToonWater_Interaction_Reviewed"
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
        _WaterAlpha ("水体染色强度 (Tint Strength)", Range(0, 1)) = 1.0
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
        _NormalSpeed ("双层法线速度 (XY / ZW)", Vector) = (0.03, 0.0, 0, 0)

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
        _GlintStrength ("碎斑爆发亮度 (Glint Str)", Range(0, 50)) = 14.9
        _GlintSpeed ("碎斑流动速度 (Glint Speed XY)", Vector) = (0.02, 0.02, 0, 0)

        [HDR] _PBRSpecularColor ("PBR 高光颜色 (GGX Color)", Color) = (1.0, 1.0, 1.0, 1.0)
        _PBRSmoothness ("PBR 高光集中度 (GGX Smoothness)", Range(10.0, 1000.0)) = 187
        _PBRSpecularIntensity ("PBR 高光强度 (GGX Intensity)", Range(0.0, 10.0)) = 0

        // ==========================================
        // 10. SSR V13 屏幕空间反射
        // ==========================================
        [Header(9. SSR V13 Module)]
        _SSRIntensity ("总反射强度 (SSR + Probe)", Range(0, 1)) = 0
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
        // 11. 泡沫流动速度
        // ==========================================
        [Header(10. Foam Flow Speed)]
        _FoamSpeed ("泡沫流动速度 (Foam Speed XY)", Vector) = (0.01, 0.01, 0, 0)

        // ==========================================
        // 12. 反射探针过渡
        // ==========================================
        [Header(11. Fallback Probe Reflection)]
        _ProbeIntensity ("反射探针强度 (Probe Intensity)", Range(0.0, 5.0)) = 0.05

        // ==========================================
        // 13. 水面交互系统 (RenderTexture 高度场)
        // ==========================================
        [Header(13. Water Interaction)]
        [NoScaleOffset] _RippleTex ("涟漪高度图 (运行时自动注入)", 2D) = "black" {}
        _RippleIntensity ("交互涟漪高度强度 (Ripple Height)", Range(0, 5)) = 1.0
        _RippleNormalStrength ("交互涟漪法线扰动 (Normal Strength)", Range(0, 8)) = 4
        _RippleCrestStrength ("涟漪波峰亮边", Range(0, 1)) = 0.5
        [HideInInspector] _RippleTexelSize ("涟漪图单个纹素尺寸 (由Simulator自动设置)", Float) = 0.02
        [HideInInspector] _WaterCenter ("水面中心XZ (由Simulator自动设置)", Vector) = (0, 0, 0, 0)
        [HideInInspector] _RippleReady ("新版涟漪有效标记", Float) = 0
        [HideInInspector] _RippleOriginSize ("新版涟漪中心XZ与范围XZ", Vector) = (0, 0, 1, 1)
        [HideInInspector] _RippleGrid ("纹素UV间距与世界米间距", Vector) = (1, 1, 1, 1)

        // ==========================================
        // ==========================================
        // 12. Debug View
        // ==========================================
        [Header(12. Debug View)]
        [WaterReviewDebug] _DebugMode ("调试视图 (选择即启用)", Float) = 0
        [Header(Reviewed Controls)]
        _NormalSeamBlend ("非无缝法线贴图接缝修补", Range(0,0.25)) = 0.15
        _ContactSoftness ("物体接触柔化（视线深度米）", Range(0,0.5)) = 0.08
        _WaterOpacity ("整体可见度 (0 = 完全隐藏)", Range(0,1)) = 1
        _NormalLayer2Scale ("第二层法线缩放", Float) = 1.73
        [Toggle(_WATER_SSR)] _SSREnabled ("启用 SSR (关闭保留探针)", Float) = 1
        _SSRMaxDistance ("SSR 最大追踪距离 (米)", Float) = 20
        _SSRRefineSteps ("SSR 交点精化次数", Int) = 5
        _SSREdgeFade ("SSR 屏幕边缘淡出宽度", Range(0.001,0.25)) = 0.05
        _SSRNormalBias ("SSR 起点法线偏移 (米)", Float) = 0.03
        [Toggle] _FoamEnabled ("启用泡沫", Float) = 1
        _SpecularF0 ("水面正视角反射率", Range(0,1)) = 0.02
        _SpecularAA ("高光抗锯齿", Range(0,1)) = 0.2
        [HideInInspector] _DebugEnabled ("调试状态 (由模式自动控制)", Float) = 0
        [Toggle] _LegacyWaterlineEnabled ("启用旧吃水线 (需有效高度图)", Float) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent+100" }
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
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma shader_feature_local_fragment _ _WATER_SSR
            #pragma shader_feature_local_fragment _ _WATER_DEBUG
            #define _SURFACE_TYPE_TRANSPARENT 1
            #include "ToonWaterReviewed.hlsl"
            ENDHLSL
        }
    }
    CustomEditor "WaterReview20260923.Editor.ToonWaterReviewedGUI"
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
