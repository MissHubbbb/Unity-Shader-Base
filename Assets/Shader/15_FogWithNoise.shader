Shader "URP/15_FogWithNoise"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "white" {}
        _NoiseTex("Noise Texture", 2D) = "white" {}
        //_FogColor("Fog Color",Color)=(1,1,1,1)
        //_FogDensity("Fog Density", Float) = 1.0
        //_FogStart("Fog Start", Float) = 0.0
        //_FogEnd("Fog End", Float) = 1.0
        //_FogXSpeed("Fog Horizontal Speed", Float) = 0.1
        //_FogYSpeed("Fog Vertical Speed", Float) = 0.1
        //_NoiseAmount("Noise Amount", Float) = 1   //控制噪声的程度
    }
    SubShader
    {
        Tags {
        "RenderPipeline" = "UniversalRenderPipeline"
        "RenderType"="Opaque" 
        }        

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityPerMaterial)   
        float4x4 _FrustumCornersRay;         
        half4 _MainTex_TexelSize;    
        half4 _FogColor;
        float _FogDensity;
        float _FogStart;
        float _FogEnd;
        float _FogXSpeed;
        float _FogYSpeed;
        float _NoiseAmount;
        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);

        TEXTURE2D(_NoiseTex);
        SAMPLER(sampler_NoiseTex);

        struct a2v{
            float4 positionOS:POSITION;            
            float2 texcoord:TEXCOORD;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            float2 uv:TEXCOORD0;
            float2 uv_depth:TEXCOORD1;
            float4 interpolatedRay:TEXCOORD2;
        };
        ENDHLSL

        Pass
        {
            Name "NOISE_FOG"
            Tags{
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
         
            v2f vert (a2v v)
            {
                v2f o;                
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.texcoord;
                o.uv_depth = v.texcoord;

                #if UNITY_UV_STARTS_AT_TOP
                    if(_MainTex_TexelSize.y < 0)
                        o.uv_depth = 1 - o.uv_depth;
                #endif
                
                int index = 0;
                //在unity中，纹理坐标的(0,0)在左下角
                //尽管我们这里使用了很多判断语句，但由于屏幕后处理所用的模型是一个四边形网格，只包含4个顶点，因此这些操作不会对性能造成很大影响。
                if (v.texcoord.x < 0.5 && v.texcoord.y < 0.5) {
				    index = 0;
			    } else if (v.texcoord.x > 0.5 && v.texcoord.y < 0.5) {
				    index = 1;
			    } else if (v.texcoord.x > 0.5 && v.texcoord.y > 0.5) {
				    index = 2;
			    } else {
				    index = 3;
			    }

                #if UNITY_UV_STARTS_AT_TOP
                    if(_MainTex_TexelSize.y < 0)
                        index = 3 - index;
                #endif

                o.interpolatedRay = _FrustumCornersRay[index];

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {   
                //使用LinearEyeDepth得到视角空间下的线性深度值
                //_ZBufferParams:内置着色器变量，用于线性化 Z 缓冲区值。x 是 (1-远/近)，y 是 (远/近)，z 是 (x/远)，w 是 (y/远)。
                float linearDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv_depth), _ZBufferParams);
                //使用深度纹理重建世界空间坐标
                float3 worldPos = _WorldSpaceCameraPos + linearDepth * i.interpolatedRay.xyz;

                float2 speed = _Time.y * float2(_FogXSpeed, _FogYSpeed);
                //最终噪声值
                float noise = (SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.uv + speed).r - 0.5) * _NoiseAmount;

                //高度雾的高度密度(越高,雾浓度就越低)
                float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart);
                fogDensity = saturate(fogDensity * _FogDensity * (1 + noise));

                half4 finalColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                finalColor.rgb = lerp(finalColor.rgb, _FogColor.rgb, fogDensity);

                return finalColor;                
            }
            ENDHLSL
        }
    }
}
