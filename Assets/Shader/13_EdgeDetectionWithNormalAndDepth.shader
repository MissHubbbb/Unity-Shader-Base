Shader "URP/13_EdgeDetectionWithNormalAndDepth"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        //_EdgeColor("Edge Color",Color)=(1,1,1,1)
        //_EdgeOnly("Edge Only", Float) = 1.0
        //_BackgroundColor("Background Color", Color) = (1,1,1,1)
        //_SampleDistance("Sample Distance", Float) = 1.0
        //_Sensitivity("Sensitivity", Vector) = (1,1,1,1)
    }
    SubShader
    {
        Tags {
        "RenderPipeline" = "UniversalRenderPipeline"
        "RenderType"="Opaque" 
        }        

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_TexelSize;
        half4 _EdgeColor;
        float _EdgeOnly;
        half4 _BackgroundColor;
        float _SampleDistance;
        half4 _Sensitivity;
        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        //如果在URP Asset设置下勾选 depth texture选项系统会自动生成一张以_CameraDepthTexture为名的深度图
        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);
        
        TEXTURE2D(_CameraNormalsTexture);
        SAMPLER(sampler_CameraNormalsTexture);

        struct a2v{
            float4 positionOS:POSITION;            
            float2 texcoord:TEXCOORD;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            half2 uv[5]:TEXCOORD0;
        };

        v2f vert (a2v v)
        {
            v2f o;            
            o.positionCS = TransformObjectToHClip(v.positionOS.xyz); 
            half2 uv = v.texcoord;
            o.uv[0] = uv;

            #if UNITY_UV_STARTS_AT_TOP
                if(_MainTex_TexelSize.y < 0)            
                    uv.y = 1 - uv.y;
            #endif

            o.uv[1] = uv + _MainTex_TexelSize.xy * half2(1,1) * _SampleDistance;    //右上
            o.uv[2] = uv + _MainTex_TexelSize.xy * half2(-1, -1) * _SampleDistance; //左下
            o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 1) * _SampleDistance;  //左上
            o.uv[4] = uv + _MainTex_TexelSize.xy * half2(1, -1) * _SampleDistance;  //右下

            return o;
        }

        //分别计算两个对角线上纹理值的差值(要么返回0，要么返回1.返回0表示这两点之间存在一条边界)
        half CheckSame(half2 centerN, half2 sampleN, half centerD, half sampleD){
            half2 centerNormal = centerN;
            float centerDepth = centerD;
            half2 sampleNormal = sampleN;
            float sampleDepth = sampleD;

            //法线之间的差值，不需要解码法线
            half2 diffNormal = abs(centerNormal - sampleNormal) * _Sensitivity.x; 
            int isSameNormal = (diffNormal.x + diffNormal.y) < 0.1;

            //深度之间的差值
            float diffDepth = abs(centerDepth - sampleDepth) * _Sensitivity.y;
            //按距离缩放所需的阈值
            int isSameDepth = diffDepth < 0.1 * centerDepth;

            return isSameNormal * isSameDepth ? 1.0 : 0.0;
        }

        half4 frag (v2f i) : SV_Target
        {            
            //法线贴图只存储x与y两个值，z值默认是1，在解码之后会补上z值，并把x,y由（0,1）转换到（-1,1）
            half2 sample1Normal = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, i.uv[1]);
            half2 sample2Normal = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, i.uv[2]);
            half2 sample3Normal = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, i.uv[3]);
            half2 sample4Normal = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, i.uv[4]);
        
            //得到view空间的线性深度值
            half sample1Depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv[1]), _ZBufferParams);
            half sample2Depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv[2]), _ZBufferParams);
            half sample3Depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv[3]), _ZBufferParams);
            half sample4Depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv[4]), _ZBufferParams);

            half edge = 1.0;

            edge *= CheckSame(sample1Normal, sample2Normal, sample1Depth, sample2Depth);
            edge *= CheckSame(sample3Normal, sample4Normal, sample3Depth, sample4Depth);

            half4 withEdgeColor = lerp(_EdgeColor, SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[0]), edge);
            half4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);
            half4 finalColor = lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);

            return finalColor;
        }
        ENDHLSL

        /*
        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags
            {
                "LightMode" = "DepthNormals"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            // -------------------------------------
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            ENDHLSL
        }*/

        Pass
        {
            Name "Edge_Detection_with_Normal_And_Depth"
            Tags{
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag                     
            ENDHLSL
        }
    }
}
