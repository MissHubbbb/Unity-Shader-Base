Shader "URP/12_BrightnessSaturationAndContrast"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Brightness("Brightness",Float)=1.0
        _Saturation("Saturation", Float) = 1.0
        _Contrast("Contrast", Float) = 1.0
    }
    SubShader
    {
        Tags {
        "RenderPipeline" = "UniversalRenderPipeline"
        "RenderType"="Opaque" 
        }        

        //基本是后处理shader的必备设置，放置场景中的透明物体渲染错误
        //注意进行该设置后，shader将在完成透明物体的渲染后起作用，即RenderPassEvent.AfterRenderingTransparents后
        ZTest Always
        Cull Off
        ZWrite Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half _Brightness;
        half _Saturation;
        half _Contrast;
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
        ENDHLSL

        Pass
        {
            Name "BSC_Pass"
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
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);   //SAMPLE_TEXTURE2D类似上面那句采样的tex2D
                
                //应用亮度，亮度的调整非常简单，只需要把原颜色乘以亮度系数_Brightness即可
                half3 finalColor = tex.rgb * _Brightness;

                //应用饱和度，通过对每个颜色分量乘以一个特定的系数再相加得到一个饱和度为0的颜色值
                half luminance = 0.2125 * tex.r + 0.7154 * tex.g + 0.0721 * tex.b;
                half3 luminanceColor = half3(luminance,luminance,luminance);
                //用_Saturation属性和上一步得到的颜色之间进行插值
                finalColor = lerp(luminanceColor, finalColor, _Saturation);

                //应用对比度，创建一个对比度为0的颜色值(各分量为0.5)
                half3 avgColor = half3(0.5, 0.5, 0.5);
                //使用_Contrast属性和上一步得到的颜色之间进行插值
                finalColor = lerp(avgColor, finalColor, _Contrast);
                
                return half4(finalColor, 1.0);                
            }
            ENDHLSL
        }
    }
    FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}
