Shader "URP/05_RampTex"
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
            float3 normalOS:NORMAL;
            //float2 texcoord:TEXCOORD;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            //float2 texcoord:TEXCOORD;
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
         
            v2f vert (a2v v)
            {
                v2f o;
                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);    
                o.normalWS = normalize(TransformObjectToWorldNormal(v.normalOS));
                //o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);                
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                real3 lightDir = normalize(GetMainLight().direction);
                float u = dot(i.normalWS, lightDir);
                float v = 0.5;
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, float2(u,v)) * _BaseColor;   //SAMPLE_TEXTURE2D类似上面那句采样的tex2D
                return tex;                
            }
            ENDHLSL
        }
    }
}
