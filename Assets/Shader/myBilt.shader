Shader "URPCustom/Post/myBlit" {
    Properties {
        [HideInInspector]_MainTex ("MainTex", 2D) = "white" { }
        _brightness ("Brightness", Range(0, 1)) = 1
        _saturate ("Saturate", Range(0, 1)) = 1
        _contranst ("Constrast", Range(-1, 2)) = 1
        _ColorTint ("Color Tint", Color) = (1, 0, 1, 1)
    }

    SubShader {
        Tags { "RenderPipeline" = "UniversalRenderPipeline" }
        Cull Off
        ZWrite Off
        ZTest Always
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        CBUFFER_START(UnityPerMaterial)
            float _brightness;
            float _saturate;
            float _contranst;
            float4 _ColorTint;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct a2v {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD;
        };

        struct v2f {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD;
        };
        ENDHLSL

        pass {
            Name "myBlit"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v i) {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.uv = i.texcoord;
                return o;
            }

            float3 HSVToRGB(float3 c) {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
            }

            half4 frag(v2f i) : SV_TARGET {
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float gray = 0.21 * tex.x + 0.72 * tex.y + 0.072 * tex.z;//灰度图，即计算明度
                tex.xyz *= _brightness;//计算亮度
                tex.xyz = lerp(float3(gray, gray, gray), tex.xyz, _saturate);//饱和度
                tex.xyz = lerp(float3(0.5, 0.5, 0.5), tex.xyz, _contranst);//对比度
                
                float3 a = float3(frac(_Time.y * 0.2), 1.0, 0.7);
                _ColorTint.rgb = HSVToRGB(a);
                return tex * _ColorTint;
            }
            ENDHLSL
        }
    }
}