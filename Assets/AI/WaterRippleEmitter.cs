using UnityEngine;

public class WaterRippleEmitter : MonoBehaviour
{
    [Header("绑定")]
    [Tooltip("场景中的 WaterRippleSimulator。留空自动查找")]
    public WaterRippleSimulator simulator;

    [Header("涟漪参数")]
    [Range(0.1f, 5f)]  public float rippleRadius = 0.5f;
    [Range(0.01f, 2f)] public float rippleStrength = 0.3f;
    [Range(0, 2f)]     public float velocityMultiplier = 2f;

    [Header("触发")]
    [Tooltip("水面世界 Y 坐标。0=自动检测")]
    public float waterSurfaceY = 0f;

    [Tooltip("自动从 Simulator 检测水面 Y 位置")]
    public bool autoDetectWaterY = true;

    [Range(0.05f, 1f)] public float minInterval = 0.1f;

    [Header("尾迹")]
    public bool enableWake = true;
    [Range(0.5f, 5f)]  public float wakeIntervalMultiplier = 2f;
    [Range(0.1f, 5f)]  public float minWakeSpeed = 0.3f;

    [Header("调试")]
    public bool showDebugInfo = true;

    private Rigidbody _rb;
    private float _lastEmitTime;
    private float _lastWakeTime;
    private bool _wasInWater;
    private float _effectiveWaterY;

    private void Start()
    {
        _rb = GetComponent<Rigidbody>();
        if (_rb == null)
            Debug.LogWarning($"[WaterRippleEmitter] {name} 无 Rigidbody，速度相关增强不生效");

        if (simulator == null)
            simulator = FindAnyObjectByType<WaterRippleSimulator>();

        if (autoDetectWaterY && simulator != null)
        {
            // 从场景中找到水面 Renderer 获取 Y 坐标
            var renderers = FindObjectsByType<Renderer>();
            foreach (var r in renderers)
            {
                if (r.sharedMaterial != null && r.sharedMaterial.shader != null &&
                    r.sharedMaterial.shader.name.Contains("ToonWater"))
                {
                    _effectiveWaterY = r.bounds.center.y;
                    Debug.Log($"[WaterRippleEmitter] 自动检测水面 Y = {_effectiveWaterY:F2} (来自 {r.name})");
                    break;
                }
            }
        }
        else
        {
            _effectiveWaterY = waterSurfaceY;
        }

        Debug.Log($"[WaterRippleEmitter] {name} 就绪 — 水面Y={_effectiveWaterY:F2} 物体Y={transform.position.y:F2} " +
                  $"Simulator={simulator != null}");
    }

    private void Update()
    {
        if (simulator == null) return;

        float objY = transform.position.y;
        bool isInWater = objY < _effectiveWaterY;

        if (showDebugInfo)
        {
            string state = isInWater ? "水中" : "空中";
            if (_wasInWater != isInWater)
                Debug.Log($"[WaterRippleEmitter] {name} 状态切换: {(_wasInWater ? "水中" : "空中")} → {state}  Y={objY:F2} 水面={_effectiveWaterY:F2}");
        }

        // 入水瞬间
        if (isInWater && !_wasInWater && Time.time - _lastEmitTime >= minInterval)
            EmitSplash();

        // 水中尾迹
        if (isInWater && enableWake && Time.time - _lastWakeTime >= minInterval * wakeIntervalMultiplier)
            EmitWake();

        _wasInWater = isInWater;
    }

    private void EmitSplash()
    {
        float speed = _rb != null ? _rb.linearVelocity.magnitude : 0;
        float str = Mathf.Clamp(rippleStrength + speed * velocityMultiplier, 0.01f, 2f);

        Vector3 p = transform.position;
        p.y = _effectiveWaterY;
        simulator.EmitRipple(p, rippleRadius * 1.5f, str * 2f);
        _lastEmitTime = Time.time;
        _lastWakeTime = Time.time;  // 重置尾迹计时器，防止同一帧双重发射

        Debug.Log($"[WaterRippleEmitter] {name} 溅射! 位置=({p.x:F1},{p.z:F1}) 强度={str * 2f:F2}");
    }

    private void EmitWake()
    {
        float speed = _rb != null ? _rb.linearVelocity.magnitude : 0;
        if (speed < minWakeSpeed) return;

        float str = Mathf.Clamp(speed * 0.1f * rippleStrength, 0.01f, 1f);
        Vector3 p = transform.position;
        p.y = _effectiveWaterY;
        simulator.EmitRipple(p, rippleRadius, str);
        _lastWakeTime = Time.time;
    }

#if UNITY_EDITOR
    [ContextMenu("手动发射测试涟漪")]
    private void EditorEmitTest()
    {
        if (simulator == null) simulator = FindAnyObjectByType<WaterRippleSimulator>();
        if (simulator == null) { Debug.LogError("未找到 Simulator"); return; }
        Vector3 p = transform.position;
        p.y = _effectiveWaterY;
        simulator.EmitRipple(p, rippleRadius, rippleStrength);
        Debug.Log($"[WaterRippleEmitter] 手动发射 @ ({p.x:F1},{p.z:F1})");
    }

    private void OnDrawGizmosSelected()
    {
        float y = Application.isPlaying ? _effectiveWaterY : waterSurfaceY;

        // 触发球
        Vector3 p = transform.position;
        p.y = y;
        Gizmos.color = new Color(0, 0.7f, 1f, 0.3f);
        Gizmos.DrawSphere(p, rippleRadius);

        // 水面参考线
        if (transform.position.y < y)
        {
            // 物体在水下 → 蓝色
            Gizmos.color = Color.blue;
        }
        else
        {
            // 物体在水上 → 白色
            Gizmos.color = Color.white;
        }
        Gizmos.DrawLine(transform.position, p);

        // 水面高度标记
        Gizmos.color = Color.yellow;
        Vector3 hPos = new Vector3(transform.position.x + rippleRadius + 0.3f, y, transform.position.z);
        Gizmos.DrawWireSphere(hPos, 0.1f);
    }
#endif
}
