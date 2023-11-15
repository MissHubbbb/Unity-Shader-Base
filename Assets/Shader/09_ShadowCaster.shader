Shader "URP/09_ShadowCaster"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _Gloss("Gloss", Range(10, 300)) = 20
        _SpecularColor("SpecularColor", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags {
        "RenderPipeline" = "UniversalRenderPipeline"
        "RenderType"="Opaque" 
        }        

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        half _Gloss;
        real4 _SpecularColor;
        CBUFFER_END
        
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct a2v{
            float4 positionOS:POSITION;
            float4 normalOS:NORMAL;
            float2 texcoord:TEXCOORD;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            float2 texcoord:TEXCOORD;
            float3 positionWS:TEXCOORD1;
            float3 normalWS:NORMAL;
        };
        ENDHLSL

        Pass
        {
            Tags{
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT                                 //设置软阴影的（但是也会造成性能的降低）
         
            v2f vert (a2v v)
            {
                v2f o;
                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);    
                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);                
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS.xyz);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord) * _BaseColor;
                //当前模型接收阴影
                float4 SHADOW_COORDS = TransformWorldToShadowCoord(i.positionWS);
                //放入光照数据
                Light myLight = GetMainLight(SHADOW_COORDS);
                //多光照阴影数据
                half shadow = myLight.shadowAttenuation;
                float3 WS_Light = normalize(myLight.direction);
                float3 WS_Normal = normalize(i.normalWS);
                float3 WS_View = normalize(_WorldSpaceCameraPos - i.positionWS);
                float3 WS_HalfDir = normalize(WS_View + WS_Light);
                tex *= (dot(WS_Light, WS_Normal) * 0.5 + 0.5) * myLight.shadowAttenuation * real4(myLight.color, 1.0);
                float4 Spe = pow(max(0, dot(WS_Normal, WS_HalfDir)), _Gloss) * _SpecularColor * shadow;
                return tex+Spe;

                return tex;                
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
