# Unity6 Toon Water Shader

卡通风格水体 Shader，基于 Unity 6 URP。

## Shader 列表

| Shader | 说明 |
|--------|------|
| `Shader/ToonWater_Interaction.shader` | 主水体 Shader，含 Gerstner 波浪、SSR 屏幕空间反射、焦散、SSS 透光、动态泡沫、菲涅尔泛光、水面交互涟漪系统 |
| `Shader/ToonWater_旧水体.shader` | 旧版水体 Shader（参考） |

## 主要特性

- **Gerstner 波浪**：三层叠加物理波浪，逼真水面起伏
- **SSR 屏幕空间反射**：实时倒影，支持自适应步长、粗糙度模糊
- **焦散 (Caustics)**：水下光斑模拟
- **SSS 透光**：浪尖透光效果
- **动态泡沫**：全向海岸线梯度检测 + 波浪冲刷动画
- **菲涅尔泛光**：边缘环境光
- **色散 (Chromatic Aberration)**：水下折射色散
- **曲面细分 (Tessellation)**：近距离自动细分
- **水面交互**：通过 RenderTexture 高度场驱动涟漪，支持实时物体碰撞交互

## 使用

```
Shader "Custom/ToonWater_Interaction"
```

将 Shader 文件放入 Unity 项目的任意 `Shader/` 目录下即可使用。
