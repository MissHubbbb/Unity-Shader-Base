Shader "URP/12_GaussianBlur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        //_BlurSize("BaseColor",Float)= 1.0   //控制采样距离，该值越大，模糊程度越高，但采样数不会改变
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
        half4 _MainTex_TexelSize;
        float _BlurSize;
        sampler2D _MainTex;
        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
        //TEXTURE2D(_MainTex);
        //SAMPLER(sampler_MainTex);


        struct appdata{
            float4 positionOS:POSITION;            
            float2 texcoord:TEXCOORD0;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            half2 texcoord[5]:TEXCOORD0;
        };

        //下面分别定义两个Pass使用的顶点着色器
        //首先是水平方向的顶点着色器
        v2f vertBlurHorizontal(appdata v){
            v2f o;
            o.positionCS = TransformObjectToHClip(v.positionOS);

            half2 uv = v.texcoord;

            o.texcoord[0] = uv;
            o.texcoord[1] = uv + float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            o.texcoord[2] = uv - float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            o.texcoord[3] = uv + float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
            o.texcoord[4] = uv - float2(_MainTex_TexelSize.x * 2.0, 1.0) * _BlurSize;

            return o;
        }

        //然后是垂直方向的顶点着色器
        v2f vertBlurVertical(appdata v){
            v2f o;
            o.positionCS = TransformObjectToHClip(v.positionOS);

            half2 uv = v.texcoord;

            o.texcoord[0] = uv;
            o.texcoord[1] = uv + float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
            o.texcoord[2] = uv - float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
            o.texcoord[3] = uv + float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;
            o.texcoord[4] = uv - float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;

            return o;
        }

        //最后定义两个Pass公用的片元着色器
        half4 fragBlur(v2f i) : SV_Target{
            float weight[3] = {0.4026, 0.2442, 0.0545};       //高斯权重

            //half3 sum = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord[0]).rgb * weight[0];
            half3 sum = tex2D(_MainTex, i.texcoord[0]).rgb * weight[0];

            for(int it = 1; it < 3; it++){
                //sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, it.texcoord[it]).rgb * weight[it];
                //sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, it.texcoord[it*2]).rgb * weight[it]; 
                sum += tex2D(_MainTex, i.texcoord[it]).rgb * weight[it];
                sum += tex2D(_MainTex, i.texcoord[it*2]).rgb * weight[it];
            }

            return half4(sum, 1.0);
        }
        ENDHLSL

        ZTest Always
        Cull Off
        ZWrite Off

        Pass
        {
            Name "GAUSSIAN_BLUR_HORIZONTAL"
            
            Tags{
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vertBlurHorizontal
            #pragma fragment fragBlur
                     
            ENDHLSL
        }

        Pass{
            Name "GUASSIAN_BLUR_VERTICAL"

            Tags{
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vertBlurVertical
            #pragma fragment fragBlur
                     
            ENDHLSL
        }
    }
}
