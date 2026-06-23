Shader "Hidden/WaterRipplePropagation"
{
    Properties
    {
        _MainTex ("Current Height", 2D) = "black" {}
        _Diffusion ("扩散速度", Float) = 0.25
        _Damping ("衰减", Float) = 0.97
        _BrushX ("笔刷中心 X (UV)", Float) = 0.5
        _BrushY ("笔刷中心 Y (UV)", Float) = 0.5
        _BrushRadius ("笔刷半径 (UV)", Float) = 0.05
        _BrushStrength ("笔刷强度", Float) = 0.5
    }

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        // =============================================
        // Pass 0: 扩散式涟漪衰减
        // h_new = (hC + (hL+hR+hB+hT)/4 * diffusion) * damping
        // 等价于简化的热传导方程——无条件稳定，无边界反射
        // =============================================
        Pass
        {
            Name "RippleDiffusion"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv  : TEXCOORD0;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                o.pos = float4(v.vertex.xy * 2.0 - 1.0, 0.0, 1.0);
                o.uv  = v.texcoord;
                return o;
            }

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _Diffusion, _Damping;

            half4 frag(v2f i) : SV_Target
            {
                float2 texel = _MainTex_TexelSize.xy;

                float hC = tex2D(_MainTex, i.uv).r;
                float hL = tex2D(_MainTex, i.uv + float2(-texel.x, 0)).r;
                float hR = tex2D(_MainTex, i.uv + float2( texel.x, 0)).r;
                float hB = tex2D(_MainTex, i.uv + float2(0, -texel.y)).r;
                float hT = tex2D(_MainTex, i.uv + float2(0,  texel.y)).r;

                // 热扩散：中心保持 + 邻域平均混合
                float neighborAvg = (hL + hR + hB + hT) * 0.25;
                float hNew = lerp(hC, neighborAvg, _Diffusion) * _Damping;

                if (abs(hNew) < 0.002) hNew = 0;
                return half4(hNew, 0, 0, 0);
            }
            ENDHLSL
        }

        // =============================================
        // Pass 1: 笔刷合成
        // =============================================
        Pass
        {
            Name "RippleBrush"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv  : TEXCOORD0;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                o.pos = float4(v.vertex.xy * 2.0 - 1.0, 0.0, 1.0);
                o.uv  = v.texcoord;
                return o;
            }

            sampler2D _MainTex;
            float _BrushX, _BrushY, _BrushRadius, _BrushStrength;

            half4 frag(v2f i) : SV_Target
            {
                float curHeight = tex2D(_MainTex, i.uv).r;

                float2 bc = float2(_BrushX, _BrushY);
                float dist = length(i.uv - bc);
                float brush = 0;
                if (dist < _BrushRadius * 3.0)
                {
                    // 平滑高斯笔刷
                    float falloff = exp(-(dist * dist) / (2.0 * _BrushRadius * _BrushRadius));
                    brush = falloff * _BrushStrength;
                }

                float result = curHeight + brush;
                return half4(result, 0, 0, 0);
            }
            ENDHLSL
        }
    }
}
