Shader "URP/LambertianShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
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
            float3 normalWS:TEXCOORD1;
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
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);    
                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);                
                o.normalWS = TransformObjectToWorldNormal(v.normalOS.xyz, true);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord) * _BaseColor;   
                Light myLight = GetMainLight();
                real4 LightColor = real4(myLight.color, 1);
                float3 lightDir = normalize(myLight.direction);
                float lightAtten = max(0.0,dot(lightDir, i.normalWS));
                //return tex * lightAtten * LightColor;                
                return tex * lightAtten * LightColor * 0.5 + 0.5;
            }
            ENDHLSL
        }
    }
}