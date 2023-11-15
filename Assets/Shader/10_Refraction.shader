Shader "URP/10_Refraction"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _RefractColor("RefractColor", Color) = (1,1,1,1)
        _RefractRatio("RefractionRatio", Range(0.1,1)) = 0.5
        _RefractAmount("RefractAmount", Range(0,1)) = 1
        _Cubemap("Refraction Cubemap", Cube) = "_Skybox"{}
    }
    SubShader
    {
        Tags {
        "RenderPipeline" = "UniversalRenderPipeline"
        "RenderType"="Opaque" 
        "Queue" = "Geometry"
        }        

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        float _RefractAmount;
        float _RefractRatio;
        half4 _RefractColor;
        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURECUBE(_Cubemap);
        SAMPLER(sampler_Cubemap);

        struct a2v{
            float4 positionOS:POSITION;
            float4 normalOS:NORMAL;
            float2 texcoord:TEXCOORD;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            float3 worldPos:TEXCOORD0;
            float3 worldNormal:NORMAL;
            float2 texcoord:TEXCOORD1;
            half3 worldViewDir:TEXCOORD2;
            half3 worldRefr:TEXCOORD3;
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
         
            v2f vert (a2v v)
            {
                v2f o;
                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);    // 类似于上面那句
                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.worldPos = TransformObjectToWorld(v.positionOS.xyz);
                o.worldNormal = normalize(v.normalOS.xyz);
                o.worldViewDir = normalize(GetCameraPositionWS() - o.worldPos); 
                o.worldRefr = normalize(refract(-o.worldViewDir, o.worldNormal, _RefractRatio));
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord) * _BaseColor;   //SAMPLE_TEXTURE2D类似上面那句采样的tex2D
                float4 shadowCoord = TransformWorldToShadowCoord(i.worldPos);
                Light myLight = GetMainLight(shadowCoord);
                half3 ambient = SampleSH(i.worldNormal);
                half3 refraction = SAMPLE_TEXTURECUBE(_Cubemap,sampler_Cubemap, i.worldRefr) * _RefractColor * myLight.color.xyz;
                half3 diffuse = (dot(i.worldNormal, myLight.direction)) * myLight.color.rgb  * tex.xyz;
                half atten = myLight.distanceAttenuation;
                half3 finalColor = ambient + lerp(diffuse, refraction, _RefractAmount) * atten;
                return half4(finalColor, 1.0);                
                //return half4(diffuse, 1.0) + half4(refraction, 1.0);
                //return tex;
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
