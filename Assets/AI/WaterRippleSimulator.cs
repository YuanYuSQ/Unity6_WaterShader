using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 水面涟漪模拟器 — 基于波方程的 GPU RenderTexture 高度场
///
/// 使用两张 RenderTexture 交替读写实现每帧波方程迭代：
///   h_new = (2*h_cur - h_old + c² * Laplacian) * damping
///
/// 将最终的 _currentRT 暴露给水 Shader 的 _RippleTex 全局属性。
///
/// ===== 使用步骤 =====
/// 1. 将此脚本挂到场景中任意 GameObject 上
/// 2. 把 WaterRipplePropagation.shader 拖入 Propagation Shader 字段
/// 3. 设置 World Size 匹配水面 Plane 的世界尺寸
/// 4. 点击 Play / 在 Inspector 右键 → "手动发射测试涟漪"
/// ===== 调试 =====
/// - 勾选 Show Debug GUI 可在 Game 视图左上角看到 RT
/// - 右键脚本标题 → "手动发射测试涟漪" 可直接测试
/// </summary>
[ExecuteAlways]
public class WaterRippleSimulator : MonoBehaviour
{
    [Header("涟漪传播 Shader（必填）")]
    [Tooltip("将 WaterRipplePropagation.shader 拖入此处")]
    public Shader propagationShader;

    [Header("水面材质（可选）")]
    [Tooltip("使用 ToonWater_Interaction 的水面材质。拖入后纹理直接注入，无需依赖全局变量")]
    public Material waterMaterial;

    [Header("分辨率")]
    [Range(64, 1024)]
    public int resolution = 512;

    [Header("物理参数")]
    [Range(0.01f, 1.0f)]
    [Tooltip("扩散速度 — 越大涟漪扩散越快越自然。类似热传导，无条件稳定")]
    public float diffusion = 0.25f;

    [Range(0.9f, 1.0f)]
    [Tooltip("每帧衰减 — 越接近1.0涟漪持续越久")]
    public float damping = 0.97f;

    [Header("世界空间映射")]
    [Tooltip("水面覆盖的世界尺寸（米）。0=自动检测")]
    public float worldSize = 0f;

    [Tooltip("水面中心 XZ。留空=自动检测水面 Renderer 的 bounds 中心")]
    public bool autoDetectCenter = true;

    [Tooltip("手动覆盖水面中心（autoDetectCenter=false 时生效）")]
    public Vector2 manualWaterCenter = Vector2.zero;

    // 运行时计算值（只读）
    [Header("运行时（只读）")]
    [SerializeField] private float _effectiveWorldSize;
    [SerializeField] private Vector2 _effectiveWaterCenter;

    [Header("调试")]
    [Tooltip("在 Scene 视图中生成一个 Debug 平面实时渲染 RT 内容")]
    public bool showDebugPlane = true;

    [Tooltip("Debug 平面的世界位置")]
    public Vector3 debugPlanePosition = new Vector3(0, 3, 0);

    [Tooltip("Debug 平面的显示尺寸")]
    public float debugPlaneSize = 5f;

    [Tooltip("手动发射一个测试涟漪（仅 Editor 模式）")]
    public bool emitTestRipple = false;

    // --- 内部状态 ---
    private RenderTexture _currentRT;
    private RenderTexture _previousRT;
    private Material _propagationMaterial;
    private Material _debugMaterial;
    private GameObject _debugPlane;
    private List<Material> _sceneWaterMaterials = new List<Material>();
    private bool _initialized;
    private string _errorMessage;

    private static readonly int PrevTexId = Shader.PropertyToID("_PrevTex");
    private static readonly int RippleTexId = Shader.PropertyToID("_RippleTex");
    private static readonly int DiffusionId = Shader.PropertyToID("_Diffusion");
    private static readonly int DampingId = Shader.PropertyToID("_Damping");
    private static readonly int BrushXId = Shader.PropertyToID("_BrushX");
    private static readonly int BrushYId = Shader.PropertyToID("_BrushY");
    private static readonly int BrushRadiusId = Shader.PropertyToID("_BrushRadius");
    private static readonly int BrushStrengthId = Shader.PropertyToID("_BrushStrength");
    private static readonly int RippleTexelSizeId2 = Shader.PropertyToID("_RippleTexelSize");
    private static readonly int WaterCenterId = Shader.PropertyToID("_WaterCenter");

    private void OnEnable()
    {
        TryInitialize();
    }

    private void OnDisable()
    {
        ReleaseResources();
    }

    private void TryInitialize()
    {
        if (_initialized) return;
        _errorMessage = null;

        // 1. 获取 Shader
        if (propagationShader == null)
        {
            propagationShader = Shader.Find("Hidden/WaterRipplePropagation");
        }
        if (propagationShader == null)
        {
            _errorMessage = "未找到 WaterRipplePropagation Shader！请将 Assets/AI/WaterRipplePropagation.shader 拖入 Propagation Shader 字段。";
            Debug.LogWarning($"[WaterRippleSimulator] {_errorMessage}");
            return;
        }
        _propagationMaterial = new Material(propagationShader);
        if (_propagationMaterial == null || _propagationMaterial.shader == null)
        {
            _errorMessage = "Propagation Shader 编译失败，请检查 Console 中的 Shader 错误。";
            Debug.LogError($"[WaterRippleSimulator] {_errorMessage}");
            return;
        }

        // 2. 创建 RT
        _currentRT = CreateRippleRT("RippleCurrent");
        _previousRT = CreateRippleRT("RipplePrevious");
        ClearRT(_currentRT);
        ClearRT(_previousRT);

        // 3. 设置纹理（双通道：全局 + 材质直注）
        Shader.SetGlobalTexture(RippleTexId, _currentRT);
        Shader.SetGlobalFloat(RippleTexelSizeId2, 1f / _effectiveWorldSize);
        if (waterMaterial != null)
        {
            waterMaterial.SetTexture(RippleTexId, _currentRT);
            waterMaterial.SetFloat(RippleTexelSizeId2, 1f / _effectiveWorldSize);
        }

        // 4. 自动查找场景中所有使用 ToonWater_Interaction 的材质
        FindWaterMaterials();

        // 5. 创建 Debug 平面
        CreateDebugPlane();

        _initialized = true;
        Debug.Log($"[WaterRippleSimulator] 初始化成功 — 分辨率:{resolution}x{resolution} 世界尺寸:{_effectiveWorldSize}m");
    }

    private void FindWaterMaterials()
    {
        // 编辑器模式下不修改材质，避免污染资源文件
        if (!Application.isPlaying) return;
        _sceneWaterMaterials.Clear();
        var allRenderers = FindObjectsByType<Renderer>();
        foreach (var r in allRenderers)
        {
            if (r == null) continue;
            foreach (var m in r.sharedMaterials)
            {
                if (m != null && m.shader != null && m.shader.name.Contains("ToonWater_Interaction"))
                {
                    _sceneWaterMaterials.Add(m);
                }
            }
        }

        // 也加上手动指定的材质
        if (waterMaterial != null && !_sceneWaterMaterials.Contains(waterMaterial))
            _sceneWaterMaterials.Add(waterMaterial);

        // 自动检测水面位置和尺寸
        AutoDetectWaterBounds();

        if (_sceneWaterMaterials.Count > 0)
            Debug.Log($"[WaterRippleSimulator] 找到 {_sceneWaterMaterials.Count} 个水面材质，" +
                      $"世界尺寸:{_effectiveWorldSize:F1}m 中心:({_effectiveWaterCenter.x:F1},{_effectiveWaterCenter.y:F1})");
        else
            Debug.LogWarning("[WaterRippleSimulator] 未找到使用 ToonWater_Interaction 的材质！请确认水面材质 Shader 已切换。");
    }

    private void AutoDetectWaterBounds()
    {
        if (autoDetectCenter && _sceneWaterMaterials.Count > 0)
        {
            // 查找第一个使用水面材质的 Renderer 的包围盒
            var allRenderers = FindObjectsByType<Renderer>();
            foreach (var r in allRenderers)
            {
                if (r == null) continue;
                foreach (var m in r.sharedMaterials)
                {
                    if (m != null && _sceneWaterMaterials.Contains(m))
                    {
                        var bounds = r.bounds;
                        _effectiveWaterCenter = new Vector2(bounds.center.x, bounds.center.z);
                        _effectiveWorldSize = worldSize > 0 ? worldSize : Mathf.Max(bounds.size.x, bounds.size.z);
                        return;
                    }
                }
            }
        }

        // 手动模式或未找到 Renderer
        if (!autoDetectCenter)
            _effectiveWaterCenter = manualWaterCenter;
        _effectiveWorldSize = worldSize > 0 ? worldSize : 50f;
    }

    private void InjectToAllMaterials()
    {
        foreach (var m in _sceneWaterMaterials)
        {
            if (m != null)
            {
                m.SetTexture(RippleTexId, _currentRT);
                m.SetFloat(RippleTexelSizeId2, 1f / _effectiveWorldSize);
                m.SetVector(WaterCenterId, new Vector4(_effectiveWaterCenter.x, _effectiveWaterCenter.y, 0, 0));
            }
        }
    }

    private void CreateDebugPlane()
    {
        if (_debugPlane != null) return;

        var debugShader = Shader.Find("Hidden/DebugRippleViewer");
        if (debugShader == null)
        {
            Debug.LogWarning("[WaterRippleSimulator] 未找到 DebugRippleViewer shader，跳过 Debug 平面创建");
            return;
        }

        _debugMaterial = new Material(debugShader);
        _debugMaterial.SetTexture(RippleTexId, _currentRT);

        _debugPlane = GameObject.CreatePrimitive(PrimitiveType.Quad);
        _debugPlane.name = "DebugRipplePlane";
        _debugPlane.transform.position = debugPlanePosition;
        _debugPlane.transform.localScale = new Vector3(debugPlaneSize, debugPlaneSize, 1);
        _debugPlane.GetComponent<MeshRenderer>().material = _debugMaterial;
        _debugPlane.hideFlags = HideFlags.DontSave;
    }

    private void UpdateDebugPlane()
    {
        if (_debugPlane == null || !showDebugPlane)
        {
            if (_debugPlane != null) _debugPlane.SetActive(false);
            return;
        }
        _debugPlane.SetActive(true);
        _debugPlane.transform.position = debugPlanePosition;
        _debugPlane.transform.localScale = new Vector3(debugPlaneSize, debugPlaneSize, 1);

        if (_debugMaterial != null)
            _debugMaterial.SetTexture(RippleTexId, _currentRT);
    }

    private RenderTexture CreateRippleRT(string name)
    {
        var rt = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.RFloat)
        {
            name = name,
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Clamp,
            useMipMap = false,
            enableRandomWrite = false,
            hideFlags = HideFlags.DontSave
        };
        rt.Create();
        return rt;
    }

    private void ClearRT(RenderTexture rt)
    {
        var prev = RenderTexture.active;
        RenderTexture.active = rt;
        GL.Clear(true, true, Color.black);
        RenderTexture.active = prev;
    }

    private void Update()
    {
        if (!_initialized)
        {
            TryInitialize();
            return;
        }

        // 传播步：current → previous (swap)
        _propagationMaterial.SetTexture(PrevTexId, _currentRT);
        _propagationMaterial.SetFloat(DiffusionId, diffusion);
        _propagationMaterial.SetFloat(DampingId, damping);

        // Pass 0: 波方程迭代，从 _currentRT 读取，写入 _previousRT
        Graphics.Blit(_currentRT, _previousRT, _propagationMaterial, 0);

        // 交换指针
        var temp = _previousRT;
        _previousRT = _currentRT;
        _currentRT = temp;

        // 更新纹理引用（全局 + 所有水面材质直注 + Debug 平面）
        Shader.SetGlobalTexture(RippleTexId, _currentRT);
        InjectToAllMaterials();
        UpdateDebugPlane();

        // 测试涟漪（Editor 专用）
#if UNITY_EDITOR
        if (emitTestRipple)
        {
            emitTestRipple = false;
            Vector3 center = new Vector3(_effectiveWaterCenter.x, 0, _effectiveWaterCenter.y);
            EmitRipple(center, _effectiveWorldSize * 0.1f, 1.5f);
            Debug.Log($"[WaterRippleSimulator] 已发射测试涟漪到水面中心 ({_effectiveWaterCenter.x}, {_effectiveWaterCenter.y}) 半径={_effectiveWorldSize * 0.1f:F1}m");
        }
#endif
    }

    /// <summary>
    /// 在指定世界坐标写入一个涟漪扰动。由 WaterRippleEmitter 调用。
    /// </summary>
    public void EmitRipple(Vector3 worldPos, float radius, float strength)
    {
        if (!_initialized)
        {
            Debug.LogWarning("[WaterRippleSimulator] EmitRipple 调用失败：模拟器未初始化");
            return;
        }

        // 世界坐标 → UV，留 5% 边界防 RT 边缘反射
        float halfSize = _effectiveWorldSize * 0.5f;
        float u = (worldPos.x - _effectiveWaterCenter.x) / _effectiveWorldSize * 0.9f + 0.5f;
        float v = (worldPos.z - _effectiveWaterCenter.y) / _effectiveWorldSize * 0.9f + 0.5f;

        // 边界检查
        if (u < 0 || u > 1 || v < 0 || v > 1)
        {
            Debug.LogWarning($"[WaterRippleSimulator] 发射位置 {worldPos} 超出水面范围 (±{halfSize}m)，UV=({u:F2},{v:F2})");
            return;
        }

        float normalizedRadius = radius / _effectiveWorldSize;

        _propagationMaterial.SetFloat(BrushXId, u);
        _propagationMaterial.SetFloat(BrushYId, v);
        _propagationMaterial.SetFloat(BrushRadiusId, normalizedRadius);
        _propagationMaterial.SetFloat(BrushStrengthId, strength);

        // Pass 1 直接合成：读取当前高度 + 叠加笔刷 → 输出到临时 RT → 写回
        Debug.Log($"[EmitRipple] 世界=({worldPos.x:F1},{worldPos.z:F1}) → UV=({u:F3},{v:F3}) 半径={normalizedRadius:F4} 强度={strength:F2} 调用栈=\n{System.Environment.StackTrace}");

        var tempRT = RenderTexture.GetTemporary(resolution, resolution, 0, RenderTextureFormat.RFloat);
        Graphics.Blit(_currentRT, tempRT, _propagationMaterial, 1);
        Graphics.Blit(tempRT, _currentRT);
        RenderTexture.ReleaseTemporary(tempRT);
    }

    private void ReleaseResources()
    {
        if (_currentRT != null) { _currentRT.Release(); DestroyImmediate(_currentRT); _currentRT = null; }
        if (_previousRT != null) { _previousRT.Release(); DestroyImmediate(_previousRT); _previousRT = null; }
        if (_propagationMaterial != null) { DestroyImmediate(_propagationMaterial); _propagationMaterial = null; }
        if (_debugMaterial != null) { DestroyImmediate(_debugMaterial); _debugMaterial = null; }
        if (_debugPlane != null) { DestroyImmediate(_debugPlane); _debugPlane = null; }
        _initialized = false;
    }

    // --- Editor 菜单 ---
#if UNITY_EDITOR
    [ContextMenu("手动发射测试涟漪")]
    private void EditorEmitTest()
    {
        if (!Application.isPlaying) { Debug.Log("仅在 Play 模式下可用。"); return; }
        Vector3 center = new Vector3(_effectiveWaterCenter.x, 0, _effectiveWaterCenter.y);
        EmitRipple(center, _effectiveWorldSize * 0.1f, 1.5f);
        Debug.Log($"[WaterRippleSimulator] 发射测试涟漪到水面中心");
    }

    [ContextMenu("填充测试渐变 (诊断RT管线)")]
    private void EditorFillTestGradient()
    {
        if (!Application.isPlaying) { Debug.Log("仅在 Play 模式下可用。"); return; }
        if (!_initialized || _propagationMaterial == null)
        {
            Debug.Log("模拟器未初始化，先尝试初始化...");
            TryInitialize();
            if (!_initialized) return;
        }

        // 设置笔刷参数覆盖整个 RT → 写入测试图案
        _propagationMaterial.SetFloat(BrushXId, 0.5f);
        _propagationMaterial.SetFloat(BrushYId, 0.5f);
        _propagationMaterial.SetFloat(BrushRadiusId, 0.5f);   // 大半径
        _propagationMaterial.SetFloat(BrushStrengthId, 1.0f);

        var tempRT = RenderTexture.GetTemporary(resolution, resolution, 0, RenderTextureFormat.RFloat);
        Graphics.Blit(_currentRT, tempRT, _propagationMaterial, 1);
        Graphics.Blit(tempRT, _currentRT);
        RenderTexture.ReleaseTemporary(tempRT);

        // 验证：读回像素看有没有数据
        var prevActive = RenderTexture.active;
        RenderTexture.active = _currentRT;
        var readTex = new Texture2D(resolution, resolution, TextureFormat.RFloat, false);
        readTex.ReadPixels(new Rect(0, 0, resolution, resolution), 0, 0);
        readTex.Apply();
        RenderTexture.active = prevActive;

        var centerPixel = readTex.GetPixel(resolution / 2, resolution / 2);
        Debug.Log($"[诊断] RT中心像素值: {centerPixel.r:F4}  (预期 > 0.3)");

        var cornerPixel = readTex.GetPixel(10, 10);
        Debug.Log($"[诊断] RT角像素值: {cornerPixel.r:F4}  (预期 ~ 0)");

        DestroyImmediate(readTex);
    }

    [ContextMenu("清空 RT (停止抽搐)")]
    private void EditorClearRT()
    {
        if (!Application.isPlaying) return;
        if (_currentRT != null) ClearRT(_currentRT);
        if (_previousRT != null) ClearRT(_previousRT);
        Debug.Log("[WaterRippleSimulator] RT 已清空");
    }

    [ContextMenu("重新初始化")]
    private void EditorReinit()
    {
        ReleaseResources();
        TryInitialize();
    }
#endif

    // --- Debug GUI ---
    private void OnGUI()
    {
       // if (!showDebugGUI) return;

        // 半透明背景
        var bgRect = new Rect(5, 5, 270, 310);
        GUI.Box(bgRect, "");
        GUI.color = Color.white;

        if (!_initialized)
        {
            GUI.Label(new Rect(15, 15, 250, 100),
                _errorMessage ?? "未初始化 — 请检查 Propagation Shader 字段");
            return;
        }

        // RT 预览
        GUI.DrawTexture(new Rect(15, 15, 256, 256), _currentRT, ScaleMode.ScaleToFit, false);

        // 黄色边框（即使 RT 全黑也能看到预览框）
        var borderRect = new Rect(14, 14, 258, 258);
        GUI.color = Color.yellow;
        GUI.Box(borderRect, "");

        // 状态信息
        GUI.color = Color.white;
        GUI.Label(new Rect(15, 275, 250, 40),
            $"分辨率: {resolution}x{resolution}\n扩散: {diffusion}  衰减: {damping}\n世界尺寸: {_effectiveWorldSize}m");

        // 如果 RT 全黑，显示提示
        GUI.color = new Color(1, 1, 0, 0.7f);
        GUI.Label(new Rect(15, 290, 250, 20),
            Application.isPlaying ? "" : "（Play 模式下发射涟漪后可见）");
    }
}
