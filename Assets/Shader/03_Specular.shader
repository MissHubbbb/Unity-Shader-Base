Shader "URP/03_Specular"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _SpecularRange("SpecularRange", Range(10, 300)) = 10
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
        float _SpecularRange;
        half4 _SpecularColor;
        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct a2v{
            float4 positionOS:POSITION;
            float4 normalOS:NORMAL;
            float2 texcoord:TEXCOORD;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            float3 normalWS:NORMAL;
            float3 viewDirWS:TEXCOORD0;
            float2 texcoord:TEXCOORD1;
        };
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
         
            v2f vert (a2v v)
            {
                v2f o;
                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);    // 类似于上面那句
                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);         
                o.normalWS = normalize(TransformObjectToWorldNormal(v.normalOS.xyz, true));
                o.viewDirWS = normalize(_WorldSpaceCameraPos.xyz - TransformObjectToWorld(v.positionOS.xyz));       //从着色点指向相机世界空间位置
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord) * _BaseColor;   //SAMPLE_TEXTURE2D类似上面那句采样的tex2D

                Light mylight = GetMainLight();     // 光方向
                float3 lightDirWS = normalize(mylight.direction);
                float spe = pow(max(0.0, dot(normalize(lightDirWS + i.viewDirWS), i.normalWS)), _SpecularRange);
                float4 specularColor = spe * _SpecularColor;

                float diff = max(0.0, dot(i.normalWS, lightDirWS));
                float4 diffuseColor = diff * _BaseColor * tex * 0.5 + 0.5;
                float4 finalColor = diffuseColor * real4(mylight.color, 1.0) + specularColor;

                return finalColor;                
            }
            ENDHLSL
        }
    }
}

