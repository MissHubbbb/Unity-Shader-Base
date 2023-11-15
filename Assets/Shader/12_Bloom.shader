Shader "URP/12_Bloom"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        //_Bloom("BloomTex",2D)= "black" {}
        //_LuminanceThreshold("Luminance Threshold", Float) = 0.5
        //_BlurSize("Blur Size", Float) = 1.0
    }
    SubShader
    {
        Tags {
        "RenderPipeline" = "UniversalRenderPipeline"
        "RenderType"="Opaque" 
        }       

        ZTest Always
        Cull Off
        ZWrite Off 

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityPerMaterial)
        half4 _MainTex_TexelSize;
        float _LuminanceThreshold;
        float _BlurSize;        
        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_Bloom);
        SAMPLER(sampler_Bloom);

        struct a2v{
            float4 positionOS:POSITION;            
            float2 texcoord:TEXCOORD;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            float2 texcoord:TEXCOORD;
        };

        //提取亮部的顶点着色器
        v2f vertExtractBrighter (a2v v)
        {
            v2f o;                
            o.positionCS = TransformObjectToHClip(v.positionOS);
            o.texcoord = v.texcoord;         
            return o;
        }

        half luminance(half4 color){
            return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
        }

        //提取亮部的片元着色器
        half4 fragExtractBrighter (v2f i) : SV_Target
        {            
            half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord); 

            //亮度值减去阈值_LuminanceThreshold，并把结果截取到0～1范围内。(小于阈值的片元会被排除掉，只留下大于阈值的区域)
            half val = clamp(luminance(tex) - _LuminanceThreshold, 0.0, 1.0);

            //只保留特定亮度区域的片元,以此得到提取后的亮部区域
            return tex * val;
        }

        struct v2fBloom{
            float4 pos : SV_POSITION;
            half4 uv : TEXCOORD0;
        };

        //Bloom的顶点着色器
        v2fBloom vertBloom(a2v v){
            v2fBloom o;
            o.pos = TransformObjectToHClip(v.positionOS);
            o.uv.xy = v.texcoord;   //xy对应_MainTex的xy
            o.uv.zw = v.texcoord;   //zw对应_Bloom的xy

            #if UNITY_UV_STARTS_AT_TOP  //opengl和dx的区别，dx中(0,0)在屏幕左上角
            if(_MainTex_TexelSize.y < 0.0)
                o.uv.w = 1.0 - o.uv.w;
            #endif

            return o;
        }

        //Bloom的片元着色器
        half4 fragBloom(v2fBloom i) : SV_Target{
            half4 mainTex_Color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
            half4 bloomTex_Color = SAMPLE_TEXTURE2D(_Bloom, sampler_Bloom, i.uv.zw);

            return mainTex_Color + bloomTex_Color;
        }
        ENDHLSL

        Pass
        {
            Name "Extract_Brighter_Pass"
            Tags{
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vertExtractBrighter
            #pragma fragment fragExtractBrighter         
            
            ENDHLSL
        }

        UsePass "URP/12_GaussianBlur/GAUSSIAN_BLUR_HORIZONTAL"

        UsePass "URP/12_GaussianBlur/GUASSIAN_BLUR_VERTICAL"

        Pass
        {
            Name "Bloom_Pass"
            Tags{
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vertBloom
            #pragma fragment fragBloom         
            
            ENDHLSL
        }
    }
}
