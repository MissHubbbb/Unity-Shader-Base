Shader "URP/10_Fresnel"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _FresnelScale("FresnelScale", Range(0,1)) = 0.5     //控制菲涅尔反射的强度的系数
        _Cubemap("Refraction Cubemap", Cube) = "_Skybox"{}
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
        half _FresnelScale;        
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
            float3 worldNormal:NORMAL;
            float2 texcoord:TEXCOORD0;
            float3 worldPos:TEXCOORD1;
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
                o.worldPos = TransformObjectToWorld(v.positionOS.xyz);
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
                float4 shadowCoord = TransformWorldToShadowCoord(i.worldPos);
                Light myLight = GetMainLight(shadowCoord);
                half3 lightDir = normalize(myLight.direction);
                half3 ambient = SampleSH(i.worldNormal);
                half4 diffuse = tex * _BaseColor * (dot(i.worldNormal, lightDir));
                half3 reflection = SAMPLE_TEXTURECUBE(_Cubemap, sampler_Cubemap, i.worldRefl).rgb;
                // fresnel的近似方程： R = R_0 + (1 - R_0) * (1 - cos(θ_i))^5   R_0是一个反射系数，用于控制菲涅尔反射的强度,θ_i是法线和观察方向的夹角
                half fresnel = _FresnelScale + (1 - _FresnelScale) * pow(1-dot(i.worldViewDir, i.worldNormal), 5);
                half atten = myLight.distanceAttenuation;
                half4 finalColor = half4(ambient, 1.0) + lerp(diffuse, half4(reflection,1.0), saturate(fresnel)) * half4(myLight.color, 1.0) * atten;
                return finalColor;                
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
