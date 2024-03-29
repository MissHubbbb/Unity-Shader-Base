Shader "URP/PostProcessCopy"
{
SubShader {
        Tags {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 200
        ZWrite Off
        Cull Off

        HLSLINCLUDE
        #include "PostProcessing.hlsl"
        ENDHLSL

        Pass {
            Name "CopyPass"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag;

            half4 frag(Varyings input) : SV_Target {
                half4 color = GetSource(input);
                return half4(color.rgb, 1.0);
            }
            ENDHLSL
        }
    }
}