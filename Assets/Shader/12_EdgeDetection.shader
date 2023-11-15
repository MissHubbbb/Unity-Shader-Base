Shader "URP/12_EdgeDetection"       //边缘检测，使用的是sobel算子（卷积核）
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _EdgeOnly("Edge Only", Float) = 1.0
        _EdgeColor("Edge Color", Color) = (0,0,0,1)
        _BackgroundColor("BaseColor",Color)=(1,1,1,1)
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

        Pass
        {
            Tags{
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            //_MainTex_TexelSize是贴图 _MainTex 的像素尺寸大小，值： Vector4(1 / width, 1 / height, width, height)
            //_MainTex_ST是贴图_MainTex的tiling和offset的四元数。_MainTex_ST.xy 是tiling的值。_MainTex_ST.zw 是offset的值。
            uniform half4 _MainTex_TexelSize;    //_TexelSize对应每个纹素的大小（纹素是纹理的组成单位），卷积采样需要依据纹素的大小
            half _EdgeOnly;
            half4 _EdgeColor;
            half4 _BackgroundColor;
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
                float2 texcoord[9]:TEXCOORD0;   //存储边缘监测时需要的纹理坐标,9维纹理数组
            };

            half luminance(half4 color){
                return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;  //返回色彩饱和度为0的亮度值
            }

            half Sobel(v2f i){
                //x轴方向的卷积核
                const half Gx[9] = {
                    -1,0,1,
                    -2,0,2,
                    -1,0,1
                };

                //y轴方向的卷积核
                const half Gy[9] = {
                    -1,-2,-1,
                    0, 0, 0,
                    1, 2, 1
                };

                half texColor;
                half edgeX = 0;
                half edgeY = 0;
                for(int it = 0; it < 9; it++){  
                    texColor = luminance(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord[it]));  //对9个像素值进行采样，计算它们的亮度值
                    edgeX += texColor * Gx[it];     //再与卷积核Gx中对应的权重相乘后，叠加到各自的梯度值上
                    edgeY += texColor * Gy[it];     //同上
                }

                half edge = 1 - abs(edgeX) - abs(edgeY);    //我们从1中减去水平方向和竖直方向的梯度值的绝对值，得到edge
                return edge;    //edge越小，表明该位置越可能是一个边缘点
            }

            #pragma vertex vert
            #pragma fragment frag
         
            v2f vert (a2v v)
            {
                v2f o;                
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);    
                half2 uv = v.texcoord;

                //九个数组元素对应了3*3卷积核相对于被作用的纹理坐标的相对位置，在顶点着色器中完成该步骤可以减少运算量。
                o.texcoord[0] = uv + _MainTex_TexelSize.xy * half2(-1, -1);       //本身的uv左边，再加上偏移，最后变成新的uv坐标。_MainTex_TexelSize.xy就是每个纹素的大小
                o.texcoord[1] = uv + _MainTex_TexelSize.xy * half2(0, -1);
                o.texcoord[2] = uv + _MainTex_TexelSize.xy * half2(1, -1);
                o.texcoord[3] = uv + _MainTex_TexelSize.xy * half2(-1, 0);
                o.texcoord[4] = uv + _MainTex_TexelSize.xy * half2(0, 0);
                o.texcoord[5] = uv + _MainTex_TexelSize.xy * half2(1, 0);
                o.texcoord[6] = uv + _MainTex_TexelSize.xy * half2(-1, 1);
                o.texcoord[7] = uv + _MainTex_TexelSize.xy * half2(0, 1);
                o.texcoord[8] = uv + _MainTex_TexelSize.xy * half2(1, 1);

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {       
                half edge = Sobel(i);   //通过Sobel函数计算当前像素的梯度值edge

                half4 withEdgeColor = lerp(_EdgeColor, SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord[4]), edge);   //背景为原图
                half4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge); //纯色为原图
                return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);                
            }
            ENDHLSL
        }
    }
}
