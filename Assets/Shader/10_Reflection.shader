Shader "URP/10_Reflection"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)        
        _ReflectColor("ReflectColor", Color) = (1,1,1,1)
        _ReflectAmount("ReflectAmount", Range(0,1)) = 1
        _Cubemap("Reflection Cubemap", cube) = "_Skybox"{}
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
        half4 _ReflectColor;
        half _ReflectAmount;
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
            float2 texcoord:TEXCOORD0;
            half3 worldPos:TEXCOORD1;
            float3 worldNormal:NORMAL;
            half3 worldViewDir:TEXCOORD2;
            half3 worldRefl:TEXCOORD3;
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
                o.worldPos = TransformObjectToWorld(v.positionOS);
                o.worldNormal = normalize(TransformObjectToWorldNormal(v.normalOS.xyz));
                o.worldViewDir = normalize(GetCameraPositionWS() - o.worldPos);
                o.worldRefl = normalize(reflect(-o.worldViewDir, o.worldNormal));      
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord) * _BaseColor;   //SAMPLE_TEXTURE2D类似上面那句采样的tex2D
                float3 worldNormal = i.worldNormal;
                half3 lightDir = i.worldViewDir;
                float4 shadowCoord = TransformWorldToShadowCoord(i.worldPos);
                Light myLight = GetMainLight(shadowCoord);

                half3 ambient = SampleSH(worldNormal);
                half4 diffuse = (dot(myLight.direction, worldNormal)) * tex * half4(myLight.color,1.0) * _BaseColor;
                //half4 specular = pow( , )
                half4 reflection = SAMPLE_TEXTURECUBE(_Cubemap, sampler_Cubemap, i.worldRefl) * _ReflectColor;
                half atten = myLight.distanceAttenuation;
                half4 finalColor = half4(ambient,1.0) + lerp(diffuse,reflection, _ReflectAmount);

                return finalColor;                
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
