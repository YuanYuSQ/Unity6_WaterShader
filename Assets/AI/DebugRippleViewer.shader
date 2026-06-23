Shader "Hidden/DebugRippleViewer"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Overlay" }
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct Varyings { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.pos = TransformObjectToHClip(i.vertex.xyz);
                o.uv = i.uv;
                return o;
            }

            TEXTURE2D(_RippleTex); SAMPLER(sampler_RippleTex);

            half4 frag(Varyings i) : SV_Target
            {
                float h = SAMPLE_TEXTURE2D(_RippleTex, sampler_RippleTex, i.uv).r;
                // 正值=白色, 负值=红色, 零=黑色 → 一目了然
                half3 col = h > 0.001 ? half3(h, h, h) : (h < -0.001 ? half3(-h, 0, 0) : half3(0, 0, 0));
                return half4(col, 1);
            }
            ENDHLSL
        }
    }
}
