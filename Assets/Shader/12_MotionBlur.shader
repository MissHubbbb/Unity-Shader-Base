Shader "URP/12_MotionBlur"{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        //_BlurAmount("Blur Amount",Float) = 1
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
        half _BlurAmount;
        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct a2v{
            float4 positionOS:POSITION;            
            float2 texcoord:TEXCOORD;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            float2 texcoord:TEXCOORD;
        };

        v2f vert (a2v v)
        {
            v2f o;            
            o.positionCS = TransformObjectToHClip(v.positionOS.xyz);    // 类似于上面那句
            o.texcoord = v.texcoord;          
            return o;
        }

        ///之所以要把A通道和RGB通道分开是因为在更新RGB值时我们需要设置他的A通道来混和图像，但又不希望A通道的值写入渲染纹理
        //用于更新渲染纹理的RGB通道部分
        half4 fragRGB (v2f i) : SV_Target
        {            
            half3 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord).rgb;
            half4 finalColor = half4(tex, _BlurAmount); //为了在后面使用_BlurAmount进行混合
            return finalColor;                
        }

        //用于更新渲染纹理的A通道部分（其实只是为了维护渲染纹理的透明值通道，不让其受到混合时使用的透明度值得影响）
        half4 fragA (v2f i) : SV_Target
        {
            return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
        }
        ENDHLSL        

        Pass    //只混合透明度通道(alpha通道),遮掉RGB通道
        {
            Name "ColorMask_RGB_Pass"
            Blend SrcAlpha OneMinusSrcAlpha     //source指的是由片元着色器产生的颜色值，而destination指的是从颜色缓冲中读取到的颜色值

            //颜色遮罩，即保留RGB通道,屏蔽alpha，即src的alpha = 0，这样可以得到上一帧单纯的虚化图，而不是颜色混合图。ColorMask 0 即只保留深度信息
            //DstColornew=SrcAlpha(=0) ×SrcColor+(1-SrcAlpha (= _BlurAmount))×DstColorold
            ColorMask RGB

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragRGB
                     
            ENDHLSL
        }

        Pass    //只混合RGB通道，遮掉A通道
        {   
            Name "ColorMask_A_Pass"
            
            Blend One Zero
            // Csrc * 1+Cdst * 0，也就是说完全使用当前新绘制的Color,即src的A等于原始值，rgb都为0，而dst则相反。所以无论有没有上面一行代码效果呈现是一样的。
            ColorMask A

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragA
            ENDHLSL
        }
    }
}