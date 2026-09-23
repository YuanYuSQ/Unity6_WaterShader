[← 首页](../README.md) · [使用手册](usage.md) · [参数参考](parameters.md) · [技术文档](technical-design.md) · [后续更新](roadmap.md)

# 水体参数参考

> 基线：Reviewed 2026-09-23；整理：2026-09-24。下表直接核对当前 Shader Properties。默认值是新建材质的声明值，不是演示场景材质的调参结果。

[使用手册](usage.md) · [技术文档](technical-design.md)

## 阅读前先区分

- 染色强度 `_WaterAlpha` 与整体可见度 `_WaterOpacity` 不同；直接高光粗糙度与环境反射粗糙度不同。
- `Range` 是面板范围，`Float / Int` 并不表示无限有效；实现还会夹取数值。
- 中文面板将方向、速度、波长、高光粗糙度和浪尖高度换算显示；下表保留底层字段，便于脚本和旧材质排查。
- `[HDR]` 颜色可大于 1；颜色 Alpha 的使用依模块而异，不能一律当作整体透明度。
- 运行时字段由模拟器按 Renderer 材质槽注入，不要手工修改共享材质来替代绑定。

## Shader 完整属性

按效果分组展开，日常调参优先看前六组；运行时绑定和兼容字段位于末尾。每张表均保留底层字段名、类型和声明默认值。

<details open>
<summary><strong>01 · 水色与可见度 · 8 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_ShallowColor` | 浅水颜色 (Shallow) | `Color` | `(0.0, 0.45, 0.54, 1.0)` | HDR 颜色 |
| `_DeepColor` | 深水颜色 (Deep) | `Color` | `(0.0, 0.162, 0.487, 1.0)` | HDR 颜色 |
| `_DeepRange` | 深水感度 (Deep Range) | `Float` | `16.19` |  |
| `_WaterAlpha` | 水体染色强度 (Tint Strength) | `Range(0, 1)` | `1.0` |  |
| `_BottomRetain` | 水底纹理保留 (Retain) | `Range(0, 1)` | `1.0` |  |
| `_BottomExposure` | 水底亮度补偿 (Exposure) | `Range(1, 5)` | `1.0` |  |
| `_DiffuseContribution` | 漫反射光照强度 (Diffuse) | `Range(0, 1)` | `0` |  |
| `_WaterOpacity` | 整体可见度 (0 = 完全隐藏) | `Range(0,1)` | `1` |  |

</details>

<details>
<summary><strong>02 · 几何波浪 · 6 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_TessellationUniform` | 细分倍数 (Factor) | `Range(1, 64)` | `7` |  |
| `_TessellationMinDist` | 最高精度距离 (Min Dist) | `Float` | `3.0` |  |
| `_TessellationMaxDist` | 细分消退距离 (Max Dist) | `Float` | `100.0` |  |
| `_WaveA` | 主波浪 A (DirX, DirZ, Steep, Length) | `Vector` | `(5.0, 5.0, 0.15, 10.0)` |  |
| `_WaveB` | 副波浪 B (DirX, DirZ, Steep, Length) | `Vector` | `(-2.29, 1.0, -0.1, 20.0)` |  |
| `_WaveC` | 碎波浪 C (DirX, DirZ, Steep, Length) | `Vector` | `(4.0, -4.4, 0.14, 2.89)` |  |

</details>

<details>
<summary><strong>03 · 细波纹与法线 · 5 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_NormalMap` | 波纹法线贴图 (Normal) | `2D` | `"bump" {}` | 法线贴图导入 |
| `_NormalScale` | 波纹凸起强度 (Scale) | `Float` | `1.0` |  |
| `_NormalSpeed` | 双层法线速度 (XY / ZW) | `Vector` | `(0.03, 0.0, 0, 0)` |  |
| `_NormalSeamBlend` | 非无缝法线贴图接缝修补 | `Range(0,0.25)` | `0.15` |  |
| `_NormalLayer2Scale` | 第二层法线缩放 | `Float` | `1.73` |  |

</details>

<details>
<summary><strong>04 · 水下折射 · 3 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_UnderWaterDistort` | 水下折射扭曲力 (Distort) | `Float` | `1.57` |  |
| `_ChromaticAberration` | 色散强度 (Chromatic Aberration) | `Range(0.0, 5)` | `0.05` |  |
| `_ContactSoftness` | 物体接触柔化（视线深度米） | `Range(0,0.5)` | `0.08` |  |

</details>

<details>
<summary><strong>05 · 岸边与泡沫 · 14 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_EdgeErosion` | 岸边消融剔除 (Erosion) | `Range(0, 1)` | `0.527` |  |
| `_FoamColor` | 泡沫颜色 (Foam Color) | `Color` | `(1, 1, 1, 1)` | HDR 颜色 |
| `_FoamDistance` | 泡沫基础宽度 (Foam Dist) | `Float` | `1.33` |  |
| `_FoamWaveSpeed` | 海浪冲刷速度 (Foam Speed) | `Float` | `1.36` |  |
| `_FoamWaveFrequency` | 海浪冲刷频次 (Foam Freq) | `Float` | `-0.11` |  |
| `_FoamPushPull` | 海浪推拉幅度 (Foam Amp) | `Float` | `0.27` |  |
| `_FoamNoiseTex` | 泡沫噪波图 (Noise) | `2D` | `"white" {}` |  |
| `_FoamDissolve` | 泡沫溶解度 (Dissolve) | `Range(0, 1)` | `0.041` |  |
| `_FoamThickness` | 泡沫硬边厚度 (Thickness) | `Range(0.01, 0.5)` | `0.066` |  |
| `_FoamMaxDepth` | 泡沫极限水深 (Max Depth) | `Float` | `1.03` |  |
| `_CrestFoamThreshold` | 浪尖起泡高度阈值 (Crest Foam Thr) | `Float` | `1.41` |  |
| `_CrestFoamStrength` | 浪尖白沫浓度 (Crest Foam Str) | `Float` | `9.18` |  |
| `_FoamSpeed` | 泡沫流动速度 (Foam Speed XY) | `Vector` | `(0.01, 0.01, 0, 0)` |  |
| `_FoamEnabled` | 启用泡沫 | `Float` | `1` |  |

</details>

<details>
<summary><strong>06 · 环境反射 · 17 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_SSRIntensity` | 总反射强度 (SSR + Probe) | `Range(0, 1)` | `0` |  |
| `_SSRMinReflect` | 最低反射率 (Min Reflect) | `Range(0.0, 1.0)` | `0.143` |  |
| `_SSRJitter` | 倒影噪点抖动 (Jitter) | `Range(0.0, 2.0)` | `1.87` |  |
| `_SSRMaxSteps` | 最大步进次数 (Max Steps) | `Int` | `20` |  |
| `_SSRBaseStep` | 初始步长 (Base Step) | `Float` | `0.1` |  |
| `_SSRAdaptiveStep` | 步长增长率 (Adaptive Step) | `Range(0.0, 0.2)` | `0.036` |  |
| `_SSRBaseThickness` | 防穿透容差厚度 (Thickness) | `Float` | `0.18` |  |
| `_SSRRoughness` | 倒影粗糙度 → Mipmap模糊层级 (Roughness) | `Range(0.0, 1.0)` | `0` |  |
| `_SSRBrightness` | 倒影亮度 (Brightness) | `Range(0.0, 3.0)` | `1.2` |  |
| `_SSRContrast` | 倒影对比度 (Contrast) | `Range(0.1, 3.0)` | `1` |  |
| `_SSRWaterPlaneBias` | 水面穿透容差 (Water Plane Bias) | `Range(0.0, 2.0)` | `0` |  |
| `_ProbeIntensity` | 反射探针强度 (Probe Intensity) | `Range(0.0, 5.0)` | `0.05` |  |
| `_SSREnabled` | 启用 SSR (关闭保留探针) | `Float` | `1` |  |
| `_SSRMaxDistance` | SSR 最大追踪距离 (米) | `Float` | `20` |  |
| `_SSRRefineSteps` | SSR 交点精化次数 | `Int` | `5` |  |
| `_SSREdgeFade` | SSR 屏幕边缘淡出宽度 | `Range(0.001,0.25)` | `0.05` |  |
| `_SSRNormalBias` | SSR 起点法线偏移 (米) | `Float` | `0.03` |  |

</details>

<details>
<summary><strong>07 · 水底焦散 · 5 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_CausticsTex` | 焦散噪波图 (Tex) | `2D` | `"black" {}` |  |
| `_CausticsIntensity` | 焦散亮度 (Intensity) | `Float` | `3.8` |  |
| `_CausticsRange` | 焦散可见深度 (Range) | `Float` | `9.0` |  |
| `_CausticsSpeed1` | 底层光斑流速 (Speed 1) | `Vector` | `(0.13, 0.07, 0, 0)` |  |
| `_CausticsSpeed2` | 表层光斑流速 (Speed 2) | `Vector` | `(-0.07, -0.04, 0, 0)` |  |

</details>

<details>
<summary><strong>08 · 阳光碎斑 · 5 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_GlintColor` | 波光碎斑颜色 (Glint Color) | `Color` | `(1.0, 0.891, 0.692, 1.0)` | HDR 颜色 |
| `_GlintScale` | 碎斑密集度 (Glint Scale) | `Range(1, 50)` | `1.0` |  |
| `_GlintThreshold` | 碎斑过滤阈值 (Glint Thr) | `Range(0.1, 1.0)` | `0.506` |  |
| `_GlintStrength` | 碎斑爆发亮度 (Glint Str) | `Range(0, 50)` | `14.9` |  |
| `_GlintSpeed` | 碎斑流动速度 (Glint Speed XY) | `Vector` | `(0.02, 0.02, 0, 0)` |  |

</details>

<details>
<summary><strong>09 · 主光高光 · 5 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_PBRSpecularColor` | PBR 高光颜色 (GGX Color) | `Color` | `(1.0, 1.0, 1.0, 1.0)` | HDR 颜色 |
| `_PBRSmoothness` | PBR 高光集中度 (GGX Smoothness) | `Range(10.0, 1000.0)` | `187` |  |
| `_PBRSpecularIntensity` | PBR 高光强度 (GGX Intensity) | `Range(0.0, 10.0)` | `0` |  |
| `_SpecularF0` | 水面正视角反射率 | `Range(0,1)` | `0.02` |  |
| `_SpecularAA` | 高光抗锯齿 | `Range(0,1)` | `0.2` |  |

</details>

<details>
<summary><strong>10 · 透光 · 4 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_SSSColor` | 浪尖透光颜色 (SSS Color) | `Color` | `(0.194, 0.991, 1.0, 1.0)` | HDR 颜色 |
| `_SSSIntensity` | 透光亮度 (SSS Intensity) | `Float` | `4.73` |  |
| `_SSSPower` | 透光集中度 (SSS Power) | `Float` | `2.92` |  |
| `_SSSDistortion` | 透光光线偏折 (SSS Distort) | `Range(0, 1)` | `0.043` |  |

</details>

<details>
<summary><strong>11 · 边缘泛光 · 5 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_FresnelColor` | 边缘泛光滤镜色 (Glow Tint) | `Color` | `(1.0, 1.0, 1.0, 1.0)` | HDR 颜色 |
| `_FresnelPower` | 反射菲涅尔集中度 (Reflection Fresnel Power) | `Range(1.0, 100.0)` | `1.0` |  |
| `_GlowReflectionSplit` | 泛光与反射分离度 (Split) | `Range(0.0, 1.0)` | `0` |  |
| `_FresnelGlowPower` | 边缘泛光范围集中度 (Glow Power) | `Range(0.1, 50.0)` | `36.8` |  |
| `_FresnelGlowIntensity` | 边缘泛光强度 (Glow Intensity) | `Range(0.0, 10.0)` | `1.66` |  |

</details>

<details>
<summary><strong>12 · 交互涟漪 · 9 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_RippleTex` | 涟漪高度图 (运行时自动注入) | `2D` | `"black" {}` |  |
| `_RippleIntensity` | 交互涟漪高度强度 (Ripple Height) | `Range(0, 5)` | `1.0` |  |
| `_RippleNormalStrength` | 交互涟漪法线扰动 (Normal Strength) | `Range(0, 8)` | `4` |  |
| `_RippleCrestStrength` | 涟漪波峰亮边 | `Range(0, 1)` | `0.5` |  |
| `_RippleTexelSize` | 涟漪图单个纹素尺寸 (由Simulator自动设置) | `Float` | `0.02` | 隐藏兼容 / 系统字段 |
| `_WaterCenter` | 水面中心XZ (由Simulator自动设置) | `Vector` | `(0, 0, 0, 0)` | 隐藏兼容 / 系统字段 |
| `_RippleReady` | 新版涟漪有效标记 | `Float` | `0` | 隐藏兼容 / 系统字段 |
| `_RippleOriginSize` | 新版涟漪中心XZ与范围XZ | `Vector` | `(0, 0, 1, 1)` | 隐藏兼容 / 系统字段 |
| `_RippleGrid` | 纹素UV间距与世界米间距 | `Vector` | `(1, 1, 1, 1)` | 隐藏兼容 / 系统字段 |

</details>

<details>
<summary><strong>13 · 调试与兼容字段 · 3 项</strong></summary>

| 字段 | Shader 显示名称 | 类型 / 面板范围 | 声明默认值 | 备注 |
|---|---|---|---|---|
| `_DebugMode` | 调试视图 (选择即启用) | `Float` | `0` |  |
| `_DebugEnabled` | 调试状态 (由模式自动控制) | `Float` | `0` | 隐藏兼容 / 系统字段 |
| `_LegacyWaterlineEnabled` | 启用旧吃水线 (需有效高度图) | `Float` | `1` |  |

</details>

本表共 89 项；包含隐藏兼容字段，不等于用户需要手动调节的参数数量。

## 关键语义与运行时限制

| 字段 | 当前含义 / 边界 |
|---|---|
| `_WaveA/B/C` | XY 的方向是传播方向，长度是速度；Z 是带符号陡峭度，W 是波长。速度为 0 整层无效；负陡峭度不是倒转传播方向 |
| `_TessellationUniform` | 面板 1–64，HLSL 实际夹取 1–63 |
| `_TessellationMinDist/MaxDist` | 世界空间相机距离；实现保护负近距与远距不大于近距的情况 |
| `_NormalSpeed` | XY 第一层速度，ZW 第二层速度，按 UV 每秒理解 |
| `_NormalLayer2Scale` | 第二层法线频率倍率，越大越密，不控制几何波高 |
| `_NormalSeamBlend` | 单块 UV 边缘混合宽度，非米；0 关闭，最大 0.25，默认 0.15 |
| `_NormalScale` | 细法线采样处夹取 0–4 |
| `_ContactSoftness` | 视线深度差米数，非水平岸线宽度；默认 0.08，0 保留前景保护 |
| `_WaterAlpha` | 水底背景向着色结果混合的染色强度 |
| `_WaterOpacity` | 整体覆盖率；0 在调试输出前剔除水面 |
| `_FoamDistance/MaxDepth` | 基于视线深度差的泡沫带控制，不能直接当作地面上的米宽 |
| `_FoamColor.a` | 泡沫覆盖强度，和 HDR RGB 亮度不同 |
| `_FoamEnabled` | 关闭岸边 / 浪尖泡沫；噪声消融、涟漪亮边仍独立 |
| `_CrestFoamThreshold` | 面板米值等于该值 ×3；原算法 W10 未完成重构 |
| `_PBRSmoothness` | 面板直接高光粗糙度为 sqrt(max(2/(值+2),0.02))，不会在打开面板时迁移旧值 |
| `_SpecularF0` | 只控制 GGX 直接高光，不控制总反射强度 |
| `_SpecularAA` | 法线变化驱动的高光过滤，非全屏抗锯齿开关 |
| `_SSRIntensity` | 屏幕反射和探针混合链的总强度，默认 0；与菲涅尔泛光是独立项 |
| `_SSREnabled` | 与 `_WATER_SSR` 关键词同步；关 SSR 后仍可显示探针 |
| `_SSRMaxDistance/NormalBias` | 视空间射线的米尺度距离预算 / 起点法线偏移 |
| `_SSRRefineSteps` | 深度跨越后的二分精化，实际 0–8 |
| `_SSRMaxSteps` | 实际夹取 1–150；增加步数会增加深度查询，不会无限延长追踪距离 |
| `_SSRBaseStep/_SSRAdaptiveStep` | 初始步长是距离预算分配中的下限；增长率实际 0–0.2，两者与最大距离、步数共同决定采样位置 |
| `_SSREdgeFade` | 归一化屏幕 UV 宽度，例如 0.05；非米 |
| `_SSRRoughness` | 环境倒影的 Mipmap 粗糙度，需真实反射 Mipmap 资源 |
| `_SSRWaterPlaneBias` | 水面穿透排除的容差，不是抗锯齿宽度 |
| `_RippleIntensity` | 全水面涟漪位移与梯度增益，0 使涟漪采样无效 |
| `_RippleNormalStrength` | 法线扰动增益，默认 4，范围 0–8，不改变初始模拟半径 |
| `_RippleCrestStrength` | 正高度波峰亮边，使用泡沫色，不依赖泡沫开关 |
| `_RippleTex` | 运行时 RGFloat 状态纹理；着色读取 R，高度零点为 0 |
| `_RippleReady` | 模拟器绑定成功标记，失效时归零 |
| `_RippleOriginSize` | XY 世界中心 XZ，ZW 世界范围 XZ |
| `_RippleGrid` | XY 纹素 UV 间距，ZW 世界网格间距 |
| `_RippleTexelSize/_WaterCenter` | 旧兼容字段，新模拟器不依赖它们进行映射 |
| `_DebugMode/_DebugEnabled` | 自定义面板同步 `_WATER_DEBUG`；脚本操作同样需同步 |
| `_LegacyWaterlineEnabled` | Shader 默认 1，但独立新版使用应设 0；旧高度捕获链未统一 |

## 涟漪模拟器

| 字段 | 默认 | 单位 / 说明 |
|---|---|---|
| `waterRenderer` | 未绑定 | 绘制水面的 Renderer，一个 Renderer 一个所有者 |
| `materialIndex` | 0 | 水材质槽下标 |
| `simulationShader` | 未绑定 | `Hidden/WaterReview/RippleWave`，需拖入资源 |
| `resolution` | 512 | 64–1024，运行时取最接近的 2 次幂；修改后重新启用 |
| `waveSpeed` | 3 | 米/秒，实际速度受稳定性限制 |
| `damping` | 1.2 | 每秒，越大消失越快 |
| `edgeAbsorption` | 3 | 米，边缘吸收区域；实现至少两格 |
| `maxHeight` | 0.35 | 米，运行时 0.01–1；模拟高度限幅，不含材质再放大 |

## 物体交互器

| 字段 | 默认 | 单位 / 说明 |
|---|---|---|
| `simulation` | 未绑定 | 显式指定目标模拟器 |
| `contactCollider` | Reset 时尝试同对象 Collider | 世界 AABB 接触判定；未绑定 / 禁用时按半径建立包围盒 |
| `radius` | 0.65 | 米，初始扰动半径；有效半径受网格与水域限制 |
| `contactMargin` | 0.12 | 米，接触上下容差 |
| `splashStrength` | 1.5 | 入水基础速度力度；结合垂直速度增强，离开事件半强度 |
| `wakeStrength` | 0.5 | 移动尾波力度，0 关闭尾波 |
| `minInterval` | 0.1 | 秒，各事件共用；实现不小于 0.03 |
| `wakeSpacing` | 0.25 | 米，尾波与上次发射点的 XZ 距离 |
| `minWakeSpeed` | 0.2 | 米/秒，尾波最低水平速度 |

## 颜色捕获 Feature

| 字段 | 默认 | 说明 |
|---|---|---|
| `preWaterTransparentLayers` | Nothing | 提前绘制层；须从普通透明层掩码排除，不能含水体 |
| `waterMaterial` | 未绑定 | 单材质优化判断；多材质需求不同时留空以始终准备反射资源 |
| `reflectionDownsample` | 2 | 1–4，反射目标宽高各除以该值，并生成 Mipmap |
| `refractionDownsample` | 1 | 1–4，折射目标宽高各除以该值，无 Mipmap |

运行诊断字段如 Ready、AcceptedImpulses、DroppedImpulses、EffectiveWaveSpeed 用于读状态，不是调参入口；不建议逐帧输出日志。
