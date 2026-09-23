Shader "Hidden/WaterReview/RippleWave"
{
    Properties { [HideInInspector] _MainTex ("Height / Velocity", 2D) = "black" {} }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            #pragma target 3.5
            #include "UnityCG.cginc"
            sampler2D _MainTex;
            float4 _RippleGrid, _RippleOriginSize, _Simulation, _Limits;
            float4 _Impulses[32];
            int _ImpulseCount;
            float4 frag(v2f_img i) : SV_Target
            {
                float2 uv = i.uv, texel = _RippleGrid.xy, cell = _RippleGrid.zw;
                float2 state = tex2D(_MainTex, uv).rg;
                float lap = (tex2D(_MainTex, uv + float2(texel.x,0)).r + tex2D(_MainTex, uv - float2(texel.x,0)).r - 2*state.x)/(cell.x*cell.x);
                lap += (tex2D(_MainTex, uv + float2(0,texel.y)).r + tex2D(_MainTex, uv - float2(0,texel.y)).r - 2*state.x)/(cell.y*cell.y);
                float2 p = (uv - 0.5) * _RippleOriginSize.zw;
                float impulse = 0;
                [loop] for (int n = 0; n < _ImpulseCount; n++)
                {
                    float2 delta = (p - _Impulses[n].xy) / _Impulses[n].z;
                    float q = saturate(dot(delta,delta));
                    // Compact, zero-area pressure profile: depression plus displaced rim.
                    // Integral over the disk of (1-q)^2*(1-4q) is zero, avoiding a persistent water-level bias.
                    impulse += (1-q)*(1-q)*(1-4*q)*_Impulses[n].w;
                }
                float2 toEdge = min(uv, 1-uv) * _RippleOriginSize.zw;
                float edge = 1 - saturate(min(toEdge.x,toEdge.y)/_Simulation.w);
                float dt = _Simulation.x;
                float velocity = (state.y + impulse + _Simulation.y * lap * dt) * exp(-(_Simulation.z + 12*edge*edge)*dt);
                velocity = clamp(velocity, -_Limits.y, _Limits.y);
                float height = clamp(state.x + velocity*dt, -_Limits.x, _Limits.x);
                if (abs(height) >= _Limits.x) velocity = 0;
                // Outer two texels tend continuously to zero; outside sampling is explicitly masked by water shader.
                float border = smoothstep(0, 2*max(cell.x,cell.y), min(toEdge.x,toEdge.y));
                return float4(height*border, velocity*border, 0, 0);
            }
            ENDHLSL
        }
    }
}
