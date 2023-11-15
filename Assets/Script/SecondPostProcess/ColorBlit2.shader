Shader "URP/ColorBlit2"
{
    Properties {
        // 显式声明出来_MainTex
        [HideInInspector]_MainTex ("Base (RGB)", 2D) = "white" {}
    }
    SubShader {

        Tags {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 200
        Pass {
            Name "ColorBlitPass"

            HLSLPROGRAM
            #include "PostProcessing.hlsl"
 
            #pragma vertex Vert
            #pragma fragment frag

            float _Intensity;

            half4 frag(Varyings input) : SV_Target {
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                return color * float4(0, _Intensity, 0, 1);
            }
            ENDHLSL
        }
    }
}
