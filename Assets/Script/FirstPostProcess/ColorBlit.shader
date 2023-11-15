Shader "URP/ColorBlit"
{
    // Properties
    // {
    //     _MainTex ("Texture", 2D) = "white" {}
    //     _BaseColor("BaseColor",Color)=(1,1,1,1)
    // }
    SubShader
    {
        Tags {
        "RenderPipeline" = "UniversalRenderPipeline"
        "RenderType"="Opaque" 
        }        
        ZWrite Off
        Cull Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        // The Blit.hlsl file provides the vertex shader (Vert),
        // input structure (Attributes) and output strucutre (Varyings)
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        // CBUFFER_START(UnityPerMaterial)
        // float4 _MainTex_ST;
        // half4 _BaseColor;
        // CBUFFER_END        

        // struct a2v{
        //     float4 positionOS:POSITION;
        //     float4 normalOS:NORMAL;
        //     float2 texcoord:TEXCOORD;
        // };

        // struct v2f{
        //     float4 positionCS:SV_POSITION;
        //     float2 texcoord:TEXCOORD;
        // };
        ENDHLSL

        Pass
        {
            Name "ColorBlitPass"

            Tags{
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag

            //TEXTURE2D_X在最终跳转的结果是一个Texture2DArray的类型
            TEXTURE2D_X(_CameraOpaqueTexture);    //_CameraOpaqueTexture就是URP自带的OpaqueTexture，也就是渲染完不透明物体后截屏的图  
            SAMPLER(sampler_CameraOpaqueTexture);

            float _Intensity;
         
            // v2f vert (a2v v)
            // {
            //     v2f o;
            //     //o.vertex = UnityObjectToClipPos(v.vertex);
            //     o.positionCS = TransformObjectToHClip(v.positionOS.xyz);    // 类似于上面那句
            //     o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);                
            //     return o;
            // }

            half4 frag (Varyings input) : SV_Target
            {
                DEFAULT_UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float4 color = SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture,sampler_CameraOpaqueTexture, input.texcoord);
                return color * float4(0, _Intensity, 0, 1);
            }
            ENDHLSL
        }
    }
}
