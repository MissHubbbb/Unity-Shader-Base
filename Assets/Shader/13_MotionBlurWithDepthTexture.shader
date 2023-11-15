Shader "URP/13_MotionBlurWithDepthTexture"
{
    //从深度纹理重建像素的世界空间
    //https://docs.unity3d.com/cn/Packages/com.unity.render-pipelines.universal@12.1/manual/writing-shaders-urp-reconstruct-world-position.html

    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        //_BlurSize("Blur Size", Float) = 0.5
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
        float4x4 _CurrentViewProjectionInverseMatrix;
        float4x4 _PreviousViewProjectionMatrix;
        half _BlurSize;
        int _DrawCount;
        float _SpeedTime;
        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        //如果在URP Asset设置下勾选 depth texture选项系统会自动生成一张以_CameraDepthTexture为名的深度图。
        TEXTURE2D(_CameraDepthTexture);        
        SAMPLER(sampler_CameraDepthTexture);

        struct a2v{
            float4 positionOS:POSITION;            
            float2 texcoord:TEXCOORD;            
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            half2 texcoord:TEXCOORD;
            half2 uv_depth : TEXCOORD1;
        };

        v2f vert (a2v v)
        {
            v2f o;            
            o.positionCS = TransformObjectToHClip(v.positionOS.xyz);    // 类似于上面那句
            o.texcoord = v.texcoord;  
            o.uv_depth = v.texcoord;  

            #if UNITY_UV_STARTS_AT_TOP
            if(_MainTex_TexelSize.y < 0)      
                o.uv_depth.y = 1 - o.uv_depth.y;
            #endif

            return o;
        }

        half4 frag(v2f i) : SV_Target
        {
            //得到该像素点的深度值（d是由NDC下的坐标映射而来的）
            float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv_depth);
            
            //H是此像素处的视口位置，范围为 -1 到 1。(深度纹理的深度值的初始范围是[0,1])
            //（这里也是在构建像素的NDC坐标H，需要把这个深度值重新映射回NDC，使用原映射函数的反函数：d*2-1 = z_ndc）
            //同样，NDC的xy分量可以由像素的纹理坐标映射而来
            float4 H = float4(i.texcoord.x * 2 - 1, i.texcoord.y * 2 - 1, d * 2 - 1, 1);

            //当得到NDC下的坐标H后，我们就可以使用当前帧的视角*投影矩阵的逆矩阵对其进行变换
            float4 D = mul(_CurrentViewProjectionInverseMatrix, H);

            //并把结果只除以它的w分量来得到世界空间下的坐标表示worldPos
            float4 worldPos = D / D.w;

            //当前视图(viewport)坐标
            float4 currentPos = H;

            //使用世界空间坐标，并使用前一阵的视角*投影矩阵对他进行变换，得到前一帧在NDC下的坐标previousPos
            float4 previousPos = mul(_PreviousViewProjectionMatrix, worldPos);

            //通过除以 w 转换为非齐次点 [-1,1]。
            previousPos /= previousPos.w;

            //计算前一帧和当前帧在屏幕空间下的位置差，得到该像素的速度velocity
            float2 velocity = (currentPos.xy - previousPos.xy) / _SpeedTime;

            float2 uv = i.texcoord;
            float4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
            uv += velocity * _BlurSize;     //使用velocity对该像素的邻域像素进行采样，还是用了_BlurSize来控制采样距离。并且不断叠加
            for(int it = 1; it < _DrawCount; it++){
                uv += velocity * _BlurSize;
                float4 currentColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                c += currentColor;                
            }

            c /= 3.0f; //然后取平均值，得到一个模糊的效果。

            return half4(c.rgb, 1.0f);
        }
        ENDHLSL        

        Pass    //只混合透明度通道(alpha通道),遮掉RGB通道
        {
            Name "Motion_Blur_With_DepthTex"
            Blend SrcAlpha OneMinusSrcAlpha     //source指的是由片元着色器产生的颜色值，而destination指的是从颜色缓冲中读取到的颜色值

            //颜色遮罩，即保留RGB通道,屏蔽alpha，即src的alpha = 0，这样可以得到上一帧单纯的虚化图，而不是颜色混合图。ColorMask 0 即只保留深度信息
            //DstColornew=SrcAlpha(=0) ×SrcColor+(1-SrcAlpha (= _BlurAmount))×DstColorold
            ColorMask RGB

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
                     
            ENDHLSL
        }
    }
}
