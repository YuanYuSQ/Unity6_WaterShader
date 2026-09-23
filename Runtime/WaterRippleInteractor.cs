using UnityEngine;

namespace WaterReview20260923
{
    [DisallowMultipleComponent]
    public sealed class WaterRippleInteractor : MonoBehaviour
    {
        [Header("交互绑定")]
        public WaterRippleSimulation simulation;
        [Tooltip("按碰撞体包围盒判断接触；为空时使用下方半径作为球形范围。")]
        public Collider contactCollider;
        [Min(0.05f), InspectorName("涟漪半径（米）")] public float radius = 0.65f;
        [Min(0), InspectorName("水面接触容差（米）")] public float contactMargin = 0.12f;
        [Header("入水与尾波")]
        [Range(0, 8), InspectorName("入水力度（米/秒）")] public float splashStrength = 1.5f;
        [Range(0, 4), InspectorName("移动尾波力度")] public float wakeStrength = 0.5f;
        [Min(0.03f), InspectorName("最短触发间隔（秒）")] public float minInterval = 0.1f;
        [Min(0.05f), InspectorName("尾波间距（米）")] public float wakeSpacing = 0.25f;
        [Min(0), InspectorName("尾波最低速度（米/秒）")] public float minWakeSpeed = 0.2f;

        bool initialized, wasContact;
        Vector3 previousPosition, lastEmissionPosition;
        float previousRelativeHeight, lastEmissionTime;
        public int EmittedCount { get; private set; }

        void Reset() { contactCollider = GetComponent<Collider>(); }
        void OnEnable() { initialized = false; lastEmissionTime = float.NegativeInfinity; }

        void Update()
        {
            if (simulation == null || !simulation.IsReady) { initialized = false; return; }
            Bounds bounds = contactCollider != null && contactCollider.enabled
                ? contactCollider.bounds : new Bounds(transform.position, Vector3.one * Mathf.Max(radius * 2, 0.1f));
            Vector3 position = bounds.center;
            float surface = simulation.SurfaceHeight(position);
            float relativeHeight = position.y - surface;
            bool contact = bounds.min.y <= surface + contactMargin && bounds.max.y >= surface - contactMargin;
            Vector3 movement = initialized ? position - previousPosition : Vector3.zero;
            float dt = Mathf.Max(Time.deltaTime, 0.0001f);
            float speed = new Vector2(movement.x, movement.z).magnitude / dt;
            float verticalSpeed = Mathf.Abs(movement.y) / dt;
            bool crossedSurface = initialized && previousRelativeHeight * relativeHeight < 0;
            bool entry = contact && (!initialized || !wasContact);
            bool leaving = initialized && wasContact && !contact;
            bool due = Time.time - lastEmissionTime >= Mathf.Max(0.03f, minInterval);

            if (due && (entry || leaving || crossedSurface))
            {
                // Swept center crossing also catches fast objects that traverse the surface between frames.
                Vector3 hit = position;
                if (crossedSurface)
                    hit = Vector3.Lerp(previousPosition, position, Mathf.Abs(previousRelativeHeight) /
                        Mathf.Max(Mathf.Abs(previousRelativeHeight) + Mathf.Abs(relativeHeight), 0.0001f));
                float sign = relativeHeight < previousRelativeHeight || !initialized ? -1 : 1;
                Emit(hit, sign * splashStrength * (1 + Mathf.Min(verticalSpeed, 5) * 0.2f) * (leaving ? 0.5f : 1));
            }
            else if (due && contact && speed >= minWakeSpeed)
            {
                Vector2 distance = new Vector2(position.x - lastEmissionPosition.x, position.z - lastEmissionPosition.z);
                if (distance.sqrMagnitude >= wakeSpacing * wakeSpacing)
                    Emit(position, -wakeStrength * Mathf.Min(speed, 3));
            }
            initialized = true; previousPosition = position; previousRelativeHeight = relativeHeight; wasContact = contact;
        }

        void Emit(Vector3 position, float velocity)
        {
            if (Mathf.Abs(velocity) < 0.0001f || !simulation.EmitRipple(position, radius, velocity)) return;
            lastEmissionPosition = position; lastEmissionTime = Time.time; EmittedCount++;
        }
    }
}
