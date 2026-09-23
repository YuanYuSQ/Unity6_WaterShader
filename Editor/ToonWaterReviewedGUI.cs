using System;
using UnityEditor;
using UnityEngine;

namespace WaterReview20260923.Editor
{
    [CustomEditor(typeof(WaterRippleSimulation))]
    public sealed class WaterRippleSimulationInspector : UnityEditor.Editor
    {
        public override void OnInspectorGUI()
        {
            var simulation = (WaterRippleSimulation)target;
            EditorGUILayout.HelpBox("运行后点击下面的按钮，在主相机前连续产生明显波纹。此测试不依赖 Sphere；实际物体交互需要启用物体及其 Interactor。", MessageType.Info);
            using (new EditorGUI.DisabledScope(!Application.isPlaying || !simulation.IsReady))
            {
                if (GUILayout.Button("在镜头前测试涟漪 · 12 秒", GUILayout.Height(30))) simulation.StartVisiblePreview();
                if (GUILayout.Button("停止测试并清空涟漪")) simulation.StopVisiblePreview();
            }
            EditorGUILayout.LabelField("模拟状态", simulation.IsReady ? "已就绪" : "未运行 / 未就绪");
            EditorGUILayout.LabelField("连续测试", simulation.PreviewActive ? "正在产生波纹" : "未运行");
            EditorGUILayout.LabelField("成功接收交互次数", simulation.AcceptedImpulses.ToString());
            if (!string.IsNullOrEmpty(simulation.PreviewMessage)) EditorGUILayout.HelpBox(simulation.PreviewMessage, MessageType.Info);
            EditorGUILayout.Space();
            DrawDefaultInspector();
        }
        public override bool RequiresConstantRepaint() { return Application.isPlaying && ((WaterRippleSimulation)target).PreviewActive; }
    }
}

namespace WaterReview20260923.Editor
{
    /// <summary>Presentation and explicit presets only. Repainting never migrates material values.</summary>
    public sealed class ToonWaterReviewedGUI : ShaderGUI
    {
        MaterialEditor editor;
        MaterialProperty[] properties;
        const string FoldoutPrefix = "WaterReview.Inspector.";
        static readonly string[] QualityNames = { "自定义（保留当前值）", "低", "中", "高" };
        static readonly string[] SsrFields = { "_SSRMaxSteps", "_SSRRefineSteps", "_SSRBaseStep", "_SSRAdaptiveStep", "_SSRJitter" };
        static readonly float[][] SsrValues = {
            new[] { 24f, 3f, 0.001f, 0.075f, 1f },
            new[] { 48f, 5f, 0.001f, 0.05f, 1f },
            new[] { 80f, 6f, 0.001f, 0.025f, 1f }
        };
        static readonly string[] TessFields = { "_TessellationUniform", "_TessellationMinDist", "_TessellationMaxDist" };
        static readonly float[][] TessValues = {
            new[] { 3f, 3f, 40f }, new[] { 6f, 3f, 100f }, new[] { 12f, 5f, 150f }
        };

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
        {
            editor = materialEditor;
            properties = props;
            float oldLabel = EditorGUIUtility.labelWidth;
            float oldField = EditorGUIUtility.fieldWidth;
            EditorGUIUtility.labelWidth = Mathf.Clamp(EditorGUIUtility.currentViewWidth * 0.46f, 130, 230);
            EditorGUIUtility.fieldWidth = 55;
            try
            {
                EditorGUILayout.LabelField("卡通交互水体", EditorStyles.boldLabel);
                EditorGUILayout.LabelField("常用参数直接调整 · 更多选项位于各组高级设置", EditorStyles.wordWrappedMiniLabel);
                if (P("_DebugMode").floatValue > 0 || P("_DebugMode").hasMixedValue)
                {
                    Note("当前正在显示调试视图。调整水色等参数前，请先恢复正常渲染。");
                    if (GUILayout.Button("恢复正常渲染")) SetMode(0);
                }
                if (P("_WaterOpacity").floatValue <= 0 && !P("_WaterOpacity").hasMixedValue)
                    Note("整体可见度为 0，水面和调试输出均被隐藏。", MessageType.Warning);
                Section("color", "水色与可见度", true, DrawColor);
                Section("waves", "几何波浪", false, DrawWaves);
                Section("normal", "细波纹与法线", false, DrawNormals);
                Section("refraction", "水下折射", false, DrawRefraction);
                Section("foam", "岸边与泡沫", false, DrawFoam);
                Section("reflection", "环境反射", true, DrawReflection);
                Section("caustics", "水底焦散", false, DrawCaustics);
                Section("glints", "阳光碎斑", false, DrawGlints);
                Section("specular", "主光高光", false, DrawSpecular);
                Section("transmission", "透光", false, DrawTransmission);
                Section("glow", "边缘泛光", false, DrawGlow);
                Section("interaction", "交互涟漪", false, DrawInteraction);
                Section("diagnostics", "调试与系统数据", false, DrawDiagnostics);
            }
            finally { EditorGUIUtility.labelWidth = oldLabel; EditorGUIUtility.fieldWidth = oldField; }
        }

        void DrawColor()
        {
            Color("_ShallowColor", "浅水颜色"); Color("_DeepColor", "深水颜色");
            Number("_DeepRange", "深浅过渡深度", "基于视线深度差；也影响透光权重和泛光衰减。", 0.001f);
            Slider("_WaterAlpha", "染色强度", 0, 1, "只改变水色混合；不会关闭反射、泡沫或高光。");
            Slider("_WaterOpacity", "整体可见度", 0, 1, "0 隐藏整个水面，1 完整显示。");
            Advanced("color", () => {
                Alpha("_ShallowColor", "浅水染色权重"); Alpha("_DeepColor", "深水染色权重");
                Slider("_BottomRetain", "水底纹理保留", 0, 1);
                Slider("_BottomExposure", "水底亮度补偿", 1, 5);
                Slider("_DiffuseContribution", "漫反射染色", 0, 1);
            });
        }

        void DrawWaves()
        {
            Wave("_WaveA", "主波浪 A"); Wave("_WaveB", "副波浪 B"); Wave("_WaveC", "碎波浪 C");
            Advanced("waves", () => {
                Preset("曲面质量", TessFields, TessValues);
                Integer("_TessellationUniform", "细分倍数", 1, 63);
                Number("_TessellationMinDist", "最高细分距离（米）", null, 0);
                Number("_TessellationMaxDist", "最低细分距离（米）", null, 0.01f);
                if (P("_TessellationMaxDist").floatValue <= P("_TessellationMinDist").floatValue)
                    Note("消退结束距离应大于最高细分距离。", MessageType.Warning);
                Note("质量档位仅在主动选择时应用。切换会替换细分倍数和两个距离，可撤销。");
            });
        }

        void DrawNormals()
        {
            Texture("_NormalMap", "波纹法线贴图");
            Slider("_NormalScale", "法线凸起强度", 0, 4);
            Slider("_NormalSeamBlend", "贴图接缝修补宽度", 0, 0.25f, "用于上下左右不连续的贴图；在平铺边界混合半格偏移采样。0 关闭，0.1–0.2 通常够用；接缝区域会增加采样。");
            Vector2("_NormalSpeed", "第一层流速", false);
            Vector2("_NormalSpeed", "第二层流速", true);
            Advanced("normal", () => Number("_NormalLayer2Scale", "第二层频率倍率", "越大越密，不改变几何浪高。", 0.01f));
        }

        void DrawRefraction()
        {
            Slider("_ContactSoftness", "物体接触柔化（米）", 0, 0.5f, "按视线深度差柔化水与物体的交界，并排除前景深度误生成的白色泡沫。过大会产生透明边带。");
            Number("_UnderWaterDistort", "水底扭曲强度", "只改变折射背景偏移，不改变水面浪高。", 0);
            Advanced("refraction", () => Slider("_ChromaticAberration", "边缘色散", 0, 5));
        }

        void DrawFoam()
        {
            Toggle("_FoamEnabled", "启用泡沫");
            if (Active("_FoamEnabled"))
            {
                ColorAlpha("_FoamColor", "泡沫颜色", "覆盖强度");
                Number("_FoamDistance", "岸边泡沫范围", "基于视线深度差，不是恒定的岸线水平宽度。", 0.01f);
                Slider("_FoamDissolve", "覆盖阈值", 0, 1, "越高，泡沫通常越少。");
                Slider("_FoamThickness", "边缘柔和度", 0.01f, 0.5f);
                Vector2("_FoamSpeed", "噪声流速", false);
            }
            else Note("泡沫已关闭；岸边消融与共享噪声仍可单独调整。");
            Advanced("foam", () => {
                Texture("_FoamNoiseTex", "共享噪声贴图");
                Note("这张图的平铺同时影响泡沫、岸边消融和阳光碎斑。");
                Slider("_EdgeErosion", "岸边消融", 0, 1);
                if (!Active("_FoamEnabled")) return;
                Number("_FoamMaxDepth", "泡沫衰减深度", null, 0.001f);
                EditorGUILayout.LabelField("冲刷动画", EditorStyles.boldLabel);
                Number("_FoamWaveSpeed", "时间相位速度", "弧度/秒；可为负，0 表示不随时间变化。");
                Number("_FoamWaveFrequency", "深度相位变化", "沿视线深度的相位变化，负值改变方向；不是时间频率。");
                Number("_FoamPushPull", "范围变化幅度", null, 0);
                EditorGUILayout.LabelField("浪尖泡沫", EditorStyles.boldLabel);
                CrestThreshold();
                Number("_CrestFoamStrength", "浪尖泡沫增长强度", null, 0);
            });
        }

        void DrawReflection()
        {
            Slider("_SSRIntensity", "总反射强度", 0, 1, "同时控制 SSR 和探针；不控制独立边缘泛光。");
            Slider("_SSRRoughness", "环境反射粗糙度", 0, 1, "越大越模糊，同时作用于 SSR 和探针。");
            Toggle("_SSREnabled", "启用屏幕反射 SSR", "_WATER_SSR");
            if (Active("_SSREnabled"))
            {
                Preset("SSR 质量", SsrFields, SsrValues);
                Number("_SSRMaxDistance", "最大追踪距离（米）", null, 0.05f, 1000);
            }
            else Note("SSR 已关闭，反射使用探针回退。");
            if (!Active("_SSRIntensity")) Note("总反射强度为 0，正常视图中没有环境反射。");
            Advanced("reflection", () => {
                Slider("_SSRMinReflect", "正视角反射下限", 0, 1);
                Slider("_FresnelPower", "掠射角集中度", 1, 100, "同时影响阳光碎斑的角度权重。");
                Slider("_ProbeIntensity", "探针亮度校准", 0, 5, "只影响探针回退；不影响独立泛光。");
                if (!Active("_SSREnabled")) return;
                Slider("_SSRBrightness", "SSR 亮度校准", 0, 3);
                Slider("_SSRContrast", "SSR 对比度（兼容）", 0.1f, 3);
                Integer("_SSRMaxSteps", "追踪步数预算", 1, 150);
                Integer("_SSRRefineSteps", "交点精化次数", 0, 8);
                Number("_SSRBaseStep", "初始步长下限（米）", "过大会提前走完整个距离，实际步数可能少于预算。", 0.001f);
                Slider("_SSRAdaptiveStep", "步长增长率", 0, 0.2f);
                Slider("_SSRJitter", "起点抖动", 0, 2);
                Number("_SSRBaseThickness", "深度命中容差（米）", null, 0.005f, 5);
                Number("_SSRNormalBias", "起点法线偏移（米）", null, 0.001f);
                Slider("_SSRWaterPlaneBias", "水面以下追踪容差", 0, 2);
                Slider("_SSREdgeFade", "屏幕边缘淡出宽度", 0.001f, 0.25f, "归一化屏幕宽度；0.05 约为对应轴长的 5%。");
                Note("质量档位替换步数、精化、步长下限、增长率和抖动，不改变最大距离或容差。当前自定义值不会自动改写。");
            });
        }

        void DrawCaustics()
        {
            Number("_CausticsIntensity", "焦散强度", "0 关闭焦散。", 0);
            if (!EnabledBody("_CausticsIntensity", "焦散")) return;
            Texture("_CausticsTex", "焦散贴图");
            Number("_CausticsRange", "可见深度", null, 0.001f);
            Advanced("caustics", () => {
                Vector2("_CausticsSpeed1", "第一层流速", false); Vector2("_CausticsSpeed2", "第二层流速", false);
            });
        }
        void DrawGlints()
        {
            ColorStrength("_GlintColor", "_GlintStrength", "碎斑颜色 / 强度");
            if (!EnabledBody("_GlintStrength", "碎斑")) return;
            Slider("_GlintScale", "碎斑密集倍率", 1, 50, "相对于共享泡沫噪声的平铺频率。");
            Slider("_GlintThreshold", "碎斑出现阈值", 0.1f, 1, "越高通常越稀疏；不等于亮度。");
            Advanced("glints", () => Vector2("_GlintSpeed", "碎斑流速", false));
        }
        void DrawSpecular()
        {
            ColorStrength("_PBRSpecularColor", "_PBRSpecularIntensity", "高光颜色 / 强度");
            if (!EnabledBody("_PBRSpecularIntensity", "主光高光")) return;
            Roughness();
            Advanced("specular", () => {
                Slider("_SpecularF0", "正视角基础反射率", 0, 1, "仅影响主光 GGX 高光；常用参考值 0.02。");
                Slider("_SpecularAA", "高光抗锯齿", 0, 1, "增加时可降低闪烁，也可能让高光变宽。");
            });
        }
        void DrawTransmission()
        {
            ColorStrength("_SSSColor", "_SSSIntensity", "透光颜色 / 强度");
            if (!EnabledBody("_SSSIntensity", "透光")) return;
            Advanced("transmission", () => {
                Number("_SSSPower", "透光集中度", null, 0.01f, 128);
                Slider("_SSSDistortion", "透光方向偏折", 0, 1);
            });
        }
        void DrawGlow()
        {
            ColorStrength("_FresnelColor", "_FresnelGlowIntensity", "泛光颜色 / 强度");
            if (!EnabledBody("_FresnelGlowIntensity", "泛光")) return;
            Slider("_FresnelGlowPower", "泛光集中度", 0.1f, 50);
            Advanced("glow", () => Slider("_GlowReflectionSplit", "抑制边缘反射（兼容）", 0, 1, "越高越抑制掠射角反射；通常保持 0。"));
        }
        void DrawInteraction()
        {
            Note("运行场景中的 Water Ripple Simulation 控制传播速度、衰减和分辨率；物体上的 Water Ripple Interactor 控制入水力度、半径和尾波。模拟纹理按水面单独绑定。运行时可在模拟器组件菜单中测试一圈涟漪。");
            Slider("_RippleIntensity", "涟漪位移强度", 0, 5);
            if (!EnabledBody("_RippleIntensity", "交互涟漪")) return;
            Slider("_RippleNormalStrength", "涟漪可见度（法线增益）", 0, 8, "1 对应物理坡度；3–5 适合在当前大浪和细波纹中突出交互，不增加模拟计算量。");
            Slider("_RippleCrestStrength", "涟漪波峰亮边", 0, 1, "借用泡沫颜色突出正在传播的波峰，随模拟自然消退；0 关闭，仅保留位移与法线。");
        }
        void DrawDiagnostics()
        {
            new WaterReviewDebugDrawer().OnGUI(EditorGUILayout.GetControlRect(), P("_DebugMode"), "调试视图", editor);
            Note("SSR 相关模式需要启用 SSR 及配套渲染器。没有命中时，黑色可能是正常诊断结果。");
            Note("涟漪高度图通过 Renderer 属性块绑定，不写入此共享材质。高度调试：灰色是静止，亮色是波峰，暗色是波谷；法线调试：红/绿显示世界 X/Z 方向坡度。编辑模式或模拟器未启用时显示中性颜色。");
            Advanced("diagnostics", () => {
                Toggle("_LegacyWaterlineEnabled", "启用旧水线裁剪");
                if (Active("_LegacyWaterlineEnabled")) Note("旧高度编码问题尚未整体修复。没有匹配的高度图时，建议关闭旧裁剪。", MessageType.Warning);
                editor.RenderQueueField(); editor.EnableInstancingField(); editor.DoubleSidedGIField();
            });
        }

        MaterialProperty P(string name) { return FindProperty(name, properties); }
        static GUIContent Label(string text, string tooltip = null) { return new GUIContent(text, tooltip); }
        void Note(string text, MessageType type = MessageType.Info) { EditorGUILayout.HelpBox(text, type); }
        bool Active(string name) { var p = P(name); return p.hasMixedValue || p.floatValue > 0; }
        bool EnabledBody(string name, string title) { if (Active(name)) return true; Note(title + "强度为 0，已收起细节参数。提高强度即可继续调整。"); return false; }
        void Section(string key, string title, bool initiallyOpen, Action draw)
        {
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            bool open = SessionState.GetBool(FoldoutPrefix + key, initiallyOpen);
            bool next = EditorGUILayout.Foldout(open, title, true, EditorStyles.foldoutHeader);
            if (next != open) SessionState.SetBool(FoldoutPrefix + key, next);
            if (next) { EditorGUILayout.Space(3); draw(); EditorGUILayout.Space(3); }
            EditorGUILayout.EndVertical();
        }
        void Advanced(string key, Action draw)
        {
            string pref = FoldoutPrefix + key + ".advanced";
            bool open = SessionState.GetBool(pref, false);
            bool next = EditorGUILayout.Foldout(open, "高级设置", true);
            if (next != open) SessionState.SetBool(pref, next);
            if (next) { EditorGUI.indentLevel++; try { draw(); } finally { EditorGUI.indentLevel--; } }
        }
        void Begin(MaterialProperty p) { EditorGUI.showMixedValue = p.hasMixedValue; EditorGUI.BeginChangeCheck(); }
        bool End(string label) { bool changed = EditorGUI.EndChangeCheck(); EditorGUI.showMixedValue = false; if (changed) editor.RegisterPropertyChangeUndo(label); return changed; }
        void Number(string name, string label, string hint = null, float min = float.NegativeInfinity, float max = float.PositiveInfinity)
        {
            var p = P(name); Begin(p); float value = EditorGUILayout.FloatField(Label(label, hint), p.floatValue);
            if (End(label) && !float.IsNaN(value) && !float.IsInfinity(value)) p.floatValue = Mathf.Clamp(value, min, max);
        }
        void Slider(string name, string label, float min, float max, string hint = null)
        {
            var p = P(name); Begin(p); float value = EditorGUILayout.Slider(Label(label, hint), p.floatValue, min, max);
            if (End(label)) p.floatValue = value;
        }
        void Integer(string name, string label, int min, int max)
        {
            var p = P(name); Begin(p); int value = EditorGUILayout.IntSlider(label, Mathf.RoundToInt(p.floatValue), min, max);
            if (End(label)) p.floatValue = value;
        }
        void Toggle(string name, string label, string keyword = null)
        {
            var p = P(name); Begin(p); bool value = EditorGUILayout.Toggle(label, p.floatValue > 0.5f);
            if (!End(label)) return;
            p.floatValue = value ? 1 : 0;
            if (keyword != null) foreach (var target in p.targets) { var m = target as Material; if (m != null) SetKeyword(m, keyword, value); }
        }
        void Color(string name, string label)
        {
            var p = P(name); Begin(p);
            var value = EditorGUILayout.ColorField(Label(label), p.colorValue, true, false, true);
            if (End(label)) foreach (var target in p.targets) { var m = target as Material; if (m != null) { value.a = m.GetColor(name).a; m.SetColor(name, value); EditorUtility.SetDirty(m); } }
        }
        void Alpha(string name, string label)
        {
            var p = P(name); Begin(p); float value = EditorGUILayout.Slider(label, p.colorValue.a, 0, 1);
            if (End(label)) foreach (var target in p.targets) { var m = target as Material; if (m != null) { var c = m.GetColor(name); c.a = value; m.SetColor(name, c); EditorUtility.SetDirty(m); } }
        }
        void ColorAlpha(string name, string label, string alphaLabel) { Color(name, label); Alpha(name, alphaLabel); }
        void ColorStrength(string color, string strength, string label)
        {
            Rect area = EditorGUI.PrefixLabel(EditorGUILayout.GetControlRect(), Label(label, "左侧调颜色，右侧调强度；强度为 0 时关闭效果。"));
            float width = Mathf.Min(65, area.width * 0.45f);
            Rect colorRect = new Rect(area.x, area.y, Mathf.Max(20, area.width - width - 5), area.height);
            Rect strengthRect = new Rect(area.xMax - width, area.y, width, area.height);
            var c = P(color); Begin(c);
            var rgb = EditorGUI.ColorField(colorRect, GUIContent.none, c.colorValue, true, false, true);
            if (End(label)) foreach (var target in c.targets) { var m = target as Material; if (m != null) { rgb.a = m.GetColor(color).a; m.SetColor(color, rgb); EditorUtility.SetDirty(m); } }
            var s = P(strength); Begin(s);
            float value = EditorGUI.FloatField(strengthRect, s.floatValue);
            if (End(label) && !float.IsNaN(value) && !float.IsInfinity(value)) s.floatValue = Mathf.Max(0, value);
        }
        void Texture(string name, string label)
        {
            var p = P(name); editor.TexturePropertySingleLine(Label(label), p);
            editor.TextureScaleOffsetProperty(p);
        }
        void Vector2(string name, string label, bool secondPair)
        {
            var p = P(name); var v = p.vectorValue; Begin(p);
            var value = EditorGUILayout.Vector2Field(label, secondPair ? new Vector2(v.z, v.w) : new Vector2(v.x, v.y));
            if (End(label)) foreach (var target in p.targets) { var m = target as Material; if (m != null) { var old = m.GetVector(name); if (secondPair) { old.z = value.x; old.w = value.y; } else { old.x = value.x; old.y = value.y; } m.SetVector(name, old); EditorUtility.SetDirty(m); } }
        }
        void Wave(string name, string title)
        {
            EditorGUILayout.LabelField(title, EditorStyles.miniBoldLabel);
            var p = P(name); var v = p.vectorValue;
            float angle = Mathf.Atan2(v.y, v.x) * Mathf.Rad2Deg;
            float speed = new Vector2(v.x, v.y).magnitude;
            Begin(p); float newAngle = EditorGUILayout.FloatField(Label("方向（度）", "0 沿世界 +X，90 沿世界 +Z。速度为 0 时方向无定义。"), angle);
            if (End("波浪方向")) ModifyWave(name, 0, newAngle);
            Begin(p); float newSpeed = EditorGUILayout.FloatField("速度（米/秒）", speed);
            if (End("波浪速度")) ModifyWave(name, 1, Mathf.Max(0, newSpeed));
            Begin(p); float steepness = EditorGUILayout.Slider("陡峭度", v.z, -0.95f, 0.95f);
            if (End("波浪陡峭度")) ModifyWave(name, 2, steepness);
            Begin(p); float length = EditorGUILayout.FloatField("波长（米）", v.w);
            if (End("波长")) ModifyWave(name, 3, Mathf.Max(0.01f, length));
            EditorGUILayout.Space(3);
        }
        void ModifyWave(string name, int part, float value)
        {
            if (float.IsNaN(value) || float.IsInfinity(value)) return;
            foreach (var target in P(name).targets) { var m = target as Material; if (m != null) { m.SetVector(name, EditWave(m.GetVector(name), part, value)); EditorUtility.SetDirty(m); } }
        }
        public static Vector4 EditWave(Vector4 wave, int part, float value)
        {
            if (part == 0 || part == 1)
            {
                float angle = part == 0 ? value * Mathf.Deg2Rad : Mathf.Atan2(wave.y, wave.x);
                float speed = part == 1 ? value : new Vector2(wave.x, wave.y).magnitude;
                wave.x = Mathf.Cos(angle) * speed; wave.y = Mathf.Sin(angle) * speed;
            }
            else if (part == 2) wave.z = value; else wave.w = value;
            return wave;
        }
        public static float DisplayRoughness(float smoothness) { return Mathf.Sqrt(Mathf.Max(2 / (Mathf.Max(smoothness, 0) + 2), 0.02f)); }
        public static float StoredSmoothness(float roughness) { return 2 / Mathf.Max(roughness * roughness, 0.02f) - 2; }
        void Roughness()
        {
            var p = P("_PBRSmoothness"); Begin(p);
            float value = EditorGUILayout.Slider(Label("直接高光粗糙度", "越大越宽；由旧集中度等价换算。最小值约 0.141，来自当前 Shader 的稳定性下限。"), DisplayRoughness(p.floatValue), Mathf.Sqrt(0.02f), 1);
            if (End("直接高光粗糙度")) p.floatValue = StoredSmoothness(value);
            if (p.floatValue > 98) Note("旧集中度高于 98 的值具有相同有效粗糙度。这里只转换显示，未自动修改旧值。");
        }
        void CrestThreshold()
        {
            var p = P("_CrestFoamThreshold"); Begin(p);
            float meters = EditorGUILayout.FloatField(Label("起泡高度（米）", "以三层几何波的合计向上位移为准；界面已换算旧公式中的除以 3。交互涟漪不参与此遮罩。"), p.floatValue * 3);
            if (End("起泡高度") && !float.IsNaN(meters) && !float.IsInfinity(meters)) p.floatValue = meters / 3;
            if (editor.targets.Length != 1) return;
            float bound = 0;
            foreach (string name in new[] { "_WaveA", "_WaveB", "_WaveC" })
            {
                var w = P(name).vectorValue;
                if (new Vector2(w.x, w.y).magnitude >= 1e-5f && Mathf.Abs(w.w) >= 1e-4f)
                    bound += Mathf.Abs(Mathf.Clamp(w.z, -0.95f, 0.95f)) * Mathf.Max(Mathf.Abs(w.w), 0.01f) / (2 * Mathf.PI);
            }
            if (p.floatValue * 3 >= bound)
                Note($"当前起泡高度 {p.floatValue * 3:F2} 米，不低于波浪理论上界 {bound:F2} 米，因此不会产生浪尖泡沫。请降低阈值；这是上界，不保证所有波峰同时达到。", MessageType.Warning);
        }
        void Preset(string label, string[] fields, float[][] values)
        {
            int selected = 0;
            for (int i = 0; i < values.Length; i++)
            {
                bool same = true;
                for (int j = 0; j < fields.Length; j++) if (P(fields[j]).hasMixedValue || !Mathf.Approximately(P(fields[j]).floatValue, values[i][j])) same = false;
                if (same) selected = i + 1;
            }
            EditorGUI.BeginChangeCheck(); int next = EditorGUILayout.Popup(label, selected, QualityNames);
            if (EditorGUI.EndChangeCheck() && next > 0)
            {
                editor.RegisterPropertyChangeUndo(label);
                for (int j = 0; j < fields.Length; j++) P(fields[j]).floatValue = values[next - 1][j];
            }
        }
        void SetMode(int value)
        {
            editor.RegisterPropertyChangeUndo("调试视图"); P("_DebugMode").floatValue = value;
            new WaterReviewDebugDrawer().Apply(P("_DebugMode"));
        }
        static void SetKeyword(Material m, string keyword, bool enabled) { if (enabled) m.EnableKeyword(keyword); else m.DisableKeyword(keyword); }
        public override void ValidateMaterial(Material material)
        {
            if (material == null) return;
            if (material.HasProperty("_SSREnabled")) SetKeyword(material, "_WATER_SSR", material.GetFloat("_SSREnabled") > 0.5f);
            if (material.HasProperty("_DebugMode"))
            {
                bool debug = material.GetFloat("_DebugMode") > 0.5f;
                SetKeyword(material, "_WATER_DEBUG", debug);
                if (material.HasProperty("_DebugEnabled") && material.GetFloat("_DebugEnabled") != (debug ? 1 : 0)) material.SetFloat("_DebugEnabled", debug ? 1 : 0);
            }
        }
    }
}
