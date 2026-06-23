# 🌊 Unity6 Toon Water Shader

[![Unity](https://img.shields.io/badge/Unity-6-222222?logo=unity)](https://unity.com/)
[![URP](https://img.shields.io/badge/Pipeline-URP-blue)](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@latest)
[![ShaderLab](https://img.shields.io/badge/Shader-HLSL-965ba5)](#)

卡通渲染风格的高品质水体 Shader，专为 **Unity 6 URP** 构建。支持 Gerstner 波浪、SSR 屏幕空间反射、焦散、SSS 透光、动态泡沫、水面交互等完整特性。

<p align="center">
  <br>
  <em>Shader "Custom/ToonWater_Interaction"</em>
</p>

---

## 📦 文件结构

```
Unity6_WaterShader/
├── README.md
└── Shader/
    ├── ToonWater_Interaction.shader    ← 主水体 Shader
    └── ToonWater_旧水体.shader         ← 旧版参考
```

## ✨ 特性总览

| 模块 | 说明 |
|------|------|
| 🌀 **Gerstner 波浪** | 三层叠加物理波浪 (`WaveA/B/C`)，顶点级位移 + 法线重算 |
| 🔺 **曲面细分** | 近距离自适应 Tessellation，远距离自动降级 |
| 🪞 **SSR 屏幕空间反射** | 自适应步长 Ray Marching，支持粗糙度 Mipmap 模糊 |
| 🔮 **菲涅尔泛光** | 边缘 Fresnel 环境光，可调范围、强度与颜色滤镜 |
| 🌈 **色散** | RGB 三通道分离偏移，模拟水下折射色差 |
| ✨ **焦散** | 双层光斑 UV 叠加，取 min 增强锐利度 |
| 💡 **SSS 透光** | 浪尖半透明透光，模拟次表面散射 |
| 🌟 **波光碎斑** | 高频 Glint 闪烁，阈值过滤 + 流速控制 |
| 🫧 **动态泡沫** | 全向海岸线深度梯度检测 + 正弦波浪冲刷 + 浪尖白沫 |
| 🎮 **水面交互** | RenderTexture 高度场驱动，法线扰动 + 高度位移 |
| 🔍 **TA 调试** | 12 种 Debug 视图，逐模块排查渲染问题 |

---

## 🖼️ 所需贴图

Shader 需要以下 **3 张贴图**，缺一不可：

### 1. 波纹法线贴图 `_NormalMap`

| 属性 | 值 |
|------|-----|
| 参数名 | `_NormalMap` |
| 类型 | Normal Map |
| 默认回退 | `bump`（Unity 内置） |
| 用途 | 水面波纹法线，控制折射扭曲方向与强度 |
| 备注 | 双层采样混合，需可平铺。建议 512×512 以上 |

### 2. 焦散噪波图 `_CausticsTex`

| 属性 | 值 |
|------|-----|
| 参数名 | `_CausticsTex` |
| 类型 | Texture（RGB） |
| 默认回退 | `black` |
| 用途 | 水下光斑焦散图案，投射到水底物体上 |
| 备注 | 任意焦散风格的平铺图。无贴图时焦散不显示 |

### 3. 泡沫噪波图 `_FoamNoiseTex`

| 属性 | 值 |
|------|-----|
| 参数名 | `_FoamNoiseTex` |
| 类型 | Texture（单通道 R） |
| 默认回退 | `white` |
| 用途 | 泡沫边缘不规则形状 + 波光碎斑细节 |
| 备注 | 影响泡沫形态、海岸线过渡、Glint 分布，非常关键 |

### 4. 涟漪高度图（运行时注入） `_RippleTex`

| 属性 | 值 |
|------|-----|
| 参数名 | `_RippleTex` |
| 类型 | RenderTexture（R8） |
| 默认回退 | `black` |
| 用途 | 水面交互系统实时写入的高度场 |
| 备注 | 由 C# 脚本 `WaterRippleSimulator` 运行时注入，材质面板无需手动设置 |

---

## 📋 参数详解

### 🔺 Tessellation | 曲面细分

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `_TessellationUniform` | `7` | `1 ~ 64` | 细分倍数，越高顶点越密 |
| `_TessellationMinDist` | `3` | — | 最高精度距离（此范围内满细分） |
| `_TessellationMaxDist` | `100` | — | 细分消退距离（超过此距离不再细分） |

### 🎨 Color | 水体颜色与透明度

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `_ShallowColor` | `(0, 0.45, 0.54)` | HDR | 浅水颜色，岸边/薄水处可见 |
| `_DeepColor` | `(0, 0.16, 0.49)` | HDR | 深水颜色，深水处渐变为该色 |
| `_DeepRange` | `16.19` | — | 深水感度，值越小深色来得越快 |
| `_WaterAlpha` | `1` | `0 ~ 1` | 整体透明度 |
| `_BottomRetain` | `1` | `0 ~ 1` | 水底纹理保留度，1=完全保留 |
| `_BottomExposure` | `1` | `1 ~ 5` | 水底亮度补偿 |
| `_DiffuseContribution` | `0` | `0 ~ 1` | 漫反射光照强度（NdotL） |

### 🌅 Fresnel Glow | 菲涅尔与边缘泛光

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `_FresnelColor` | `(1, 1, 1)` | HDR | 边缘泛光滤镜色 |
| `_FresnelPower` | `1` | `1 ~ 100` | 反射菲涅尔集中度，越小边缘越宽 |
| `_GlowReflectionSplit` | `0` | `0 ~ 1` | 泛光与反射分离度 |
| `_FresnelGlowPower` | `36.8` | `0.1 ~ 50` | 边缘泛光范围集中度 |
| `_FresnelGlowIntensity` | `1.66` | `0 ~ 10` | 边缘泛光强度 |

### 🌊 Normal | 表面波纹法线

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `_NormalMap` | `bump` | 波纹法线贴图，双 UV 混合采样 |
| `_NormalScale` | `1` | 波纹凸起强度 |
| `_NormalSpeed` | `(0.03, 0)` | 波纹流动速度 (XY) |

### 🔮 Distortion | 水下折射与色散

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `_UnderWaterDistort` | `1.57` | — | 水下折射扭曲力 |
| `_ChromaticAberration` | `0.05` | `0 ~ 5` | 色散强度，RGB 通道分离偏移 |

### ✨ Caustics | 焦散系统

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `_CausticsTex` | `black` | 焦散噪波图 |
| `_CausticsIntensity` | `3.8` | 焦散亮度 |
| `_CausticsRange` | `9` | 焦散可见深度，超过此深度焦散淡出 |
| `_CausticsSpeed1` | `(0.13, 0.07)` | 底层光斑流速 |
| `_CausticsSpeed2` | `(-0.07, -0.04)` | 表层光斑流速（两者取 min 增强锐度） |

### 🫧 Shore and Foam | 岸边与动态泡沫

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `_EdgeErosion` | `0.527` | `0 ~ 1` | 岸边消融剔除 |
| `_FoamColor` | `(1, 1, 1)` | HDR | 泡沫颜色 |
| `_FoamDistance` | `1.33` | — | 泡沫基础宽度（从岸边向内延伸） |
| `_FoamWaveSpeed` | `1.36` | — | 海浪冲刷速度 |
| `_FoamWaveFrequency` | `-0.11` | — | 海浪冲刷频次 |
| `_FoamPushPull` | `0.27` | — | 海浪推拉幅度（泡沫带前后移动） |
| `_FoamNoiseTex` | `white` | — | 泡沫噪波图（决定泡沫不规则边缘） |
| `_FoamDissolve` | `0.041` | `0 ~ 1` | 泡沫溶解度，越高泡沫越少 |
| `_FoamThickness` | `0.066` | `0.01 ~ 0.5` | 泡沫硬边厚度 |
| `_FoamMaxDepth` | `1.03` | — | 泡沫极限水深，超过不显示泡沫 |
| `_FoamSpeed` | `(0.01, 0.01)` | — | 泡沫流动速度 (XY) |

### 🌊 Waves | 顶点物理波浪

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `_WaveA` | `(5, 5, 0.15, 10)` | 主波浪 — DirX, DirZ, Steepness, Wavelength |
| `_WaveB` | `(-2.29, 1, -0.1, 20)` | 副波浪 — 负 Steepness 允许反向 |
| `_WaveC` | `(4, -4.4, 0.14, 2.89)` | 碎波浪 — 小波长高频率，增加细节 |
| `_CrestFoamThreshold` | `1.41` | 浪尖起泡高度阈值 |
| `_CrestFoamStrength` | `9.18` | 浪尖白沫浓度 |

### 💡 SSS & Glints & PBR Specular | 阳光碎斑与透光

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `_SSSColor` | `(0.19, 0.99, 1)` | HDR | 浪尖透光颜色 |
| `_SSSIntensity` | `4.73` | 透光亮度 |
| `_SSSPower` | `2.92` | 透光集中度（NdotL 的幂次） |
| `_SSSDistortion` | `0.043` | `0 ~ 1` | 透光光线偏折 |
| `_GlintColor` | `(1, 0.89, 0.69)` | HDR | 波光碎斑颜色 |
| `_GlintScale` | `1` | `1 ~ 50` | 碎斑密集度 |
| `_GlintThreshold` | `0.506` | `0.1 ~ 1` | 碎斑过滤阈值，越高碎斑越少越集中 |
| `_GlintStrength` | `14.9` | `1 ~ 50` | 碎斑爆发亮度 |
| `_GlintSpeed` | `(0.02, 0.02)` | 碎斑流动速度 (XY) |
| `_PBRSpecularColor` | `(1, 1, 1)` | HDR | PBR 高光颜色 (GGX) |
| `_PBRSmoothness` | `187` | `10 ~ 1000` | GGX 高光集中度，越高光斑越小 |
| `_PBRSpecularIntensity` | `0` | `0 ~ 10` | PBR 高光强度 |

### 🪞 SSR V13 | 屏幕空间反射

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `_SSRIntensity` | `0` | `0 ~ 1` | 倒影总透明度 |
| `_SSRMinReflect` | `0.143` | `0 ~ 1` | 最低反射率（正对水面时的反射） |
| `_SSRJitter` | `1.87` | `0 ~ 2` | 倒影噪点抖动，减少条带伪影 |
| `_SSRMaxSteps` | `20` | — | Ray March 最大步进次数，越高越远但越费 |
| `_SSRBaseStep` | `0.1` | — | 初始步长 |
| `_SSRAdaptiveStep` | `0.036` | `0 ~ 0.2` | 步长增长率（每步递增），加快远处收敛 |
| `_SSRBaseThickness` | `0.18` | — | 防穿透容差厚度 |
| `_SSRRoughness` | `0` | `0 ~ 1` | 倒影粗糙度 → Mipmap 模糊层级 |
| `_SSRBrightness` | `1.2` | `0 ~ 3` | 倒影亮度 |
| `_SSRContrast` | `1` | `0.1 ~ 3` | 倒影对比度 |
| `_SSRWaterPlaneBias` | `0` | `0 ~ 2` | 水面穿透容差，防止倒影穿透水底 |

### 🎛️ Other | 其他

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `_ProbeIntensity` | `0.05` | `0 ~ 5` | 反射探针强度（SSR 失效时的回退） |
| `_RippleIntensity` | `1` | `0 ~ 5` | 交互涟漪高度强度 |
| `_RippleNormalStrength` | `0.5` | `0 ~ 2` | 交互涟漪法线扰动强度 |
| `_DebugMode` | `0` | 枚举 | TA 调试视图切换 |

---

## 🐞 Debug 模式速查

| 值 | 显示内容 |
|----|----------|
| `0` | 正常渲染（None） |
| `1` | SSR 倒影 |
| `2` | 反射探针 |
| `3` | 混合反射 |
| `4` | 世界法线 |
| `5` | 泡沫遮罩 |
| `6` | 海岸线梯度方向 |
| `7` | 菲涅尔因子 |
| `8` | 菲涅尔泛光 |
| `9` | 菲涅尔泛光因子 |
| `10` | SSR 粗糙度 LOD |
| `11` | 涟漪高度图 (R=中心值, G=UV采样值) |
| `12` | 涟漪法线扰动 |

---

## 🚀 快速开始

1. 将 `Shader/` 文件夹复制到 Unity 项目的 `Assets/` 下任意位置
2. 创建 Material，选择 `Custom/ToonWater_Interaction`
3. 必须设置三张贴图：**法线贴图**、**焦散噪波图**、**泡沫噪波图**
4. 将材质赋给水面 Plane / Mesh
5. SSR 需要开启 `_CameraOpaqueTexture`，URP 中勾选 Opaque Texture
6. 如需水面交互效果，额外引入 `WaterRippleSimulator` 和 `WaterRippleEmitter` C# 脚本

---

## ⚙️ 依赖

- Unity 6+
- Universal Render Pipeline (URP)
- `_CameraOpaqueTexture`（SSR 倒影必需）
- `_CameraDepthTexture`（自动启用）

---

<p align="center">
  Made with ❤️ for Unity URP
</p>
