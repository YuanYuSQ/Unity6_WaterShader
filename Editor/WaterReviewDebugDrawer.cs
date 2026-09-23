using UnityEditor;
using UnityEngine;

namespace WaterReview20260923.Editor
{
    /// <summary>One selector owns both the diagnostic mode and its stripped shader variant.</summary>
    public sealed class WaterReviewDebugDrawer : MaterialPropertyDrawer
    {
        static readonly string[] Labels =
        {
            "None — 正常渲染", "SSR Only — 屏幕反射", "Probe Only — 反射探针",
            "Mixed — 混合反射", "Normal — 世界空间法线", "Foam — 泡沫遮罩",
            "Shore Gradient — 岸线梯度", "Fresnel Factor — 反射菲涅尔",
            "Fresnel Glow — 边缘泛光", "Fresnel Glow Factor — 泛光系数",
            "SSR LOD Level — 命中采样层级", "Ripple Height — 涟漪高度",
            "Ripple Normal — 涟漪梯度", "SSR Confidence — 命中置信度",
            "SSR Steps — 步进次数"
        };

        public override void OnGUI(Rect position, MaterialProperty prop, string label, MaterialEditor editor)
        {
            bool previousMixed = EditorGUI.showMixedValue;
            EditorGUI.showMixedValue = prop.hasMixedValue;
            EditorGUI.BeginChangeCheck();
            int mode = EditorGUI.Popup(position, label, Mathf.Clamp(Mathf.RoundToInt(prop.floatValue), 0, Labels.Length - 1), Labels);
            if (EditorGUI.EndChangeCheck())
            {
                editor.RegisterPropertyChangeUndo(label);
                prop.floatValue = mode;
                Apply(prop);
            }
            EditorGUI.showMixedValue = previousMixed;
        }

        public override void Apply(MaterialProperty prop)
        {
            foreach (var target in prop.targets)
            {
                var material = target as Material;
                if (material == null || !material.HasProperty(prop.name)) continue;
                bool enabled = material.GetFloat(prop.name) > 0.5f;
                if (enabled) material.EnableKeyword("_WATER_DEBUG");
                else material.DisableKeyword("_WATER_DEBUG");
                if (material.HasProperty("_DebugEnabled")) material.SetFloat("_DebugEnabled", enabled ? 1f : 0f);
            }
        }
    }
}
