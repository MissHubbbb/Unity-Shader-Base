Shader "URP/07_AlphaTest"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _Cutoff("Cutoff", float) = 1        //_Cutoff，要使用alphatest的关键字，不能改不能打错(也就是片元抛弃的阈值)
        [HDR]_BurnColor("BurnColor", Color) = (2.5,1,1,1)       // 灼烧光颜色
        _BurnRange("BurnRange", Range(0,1)) = 0.01
    }
    SubShader
    {
        Tags {
        "RenderPipeline" = "UniversalRenderPipeline"
        "RenderType"="TransparentCutout"
        "Queue" = "AlphaTest"
        }        

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        float _Cutoff;
        float _BurnRange;
        real4 _BurnColor;
        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
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
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);    // 类似于上面那句
                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);                
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord) * _BaseColor;   //SAMPLE_TEXTURE2D类似上面那句采样的tex2D
                // step的逻辑是第二个参数和第一个参数进行比较，如果小于返回0，否则返回1
                // clip的逻辑是对小于0的数进行裁剪，使其变为0，因为我们不想保留0，所以减去0.01，将0裁剪掉
                clip(step(_Cutoff, tex.r) - 0.01);      

                //saturate(x)的逻辑是如果x取值小于0，则返回值为0。如果x取值大于1，则返回值为1。若x在0到1之间，则直接返回x的值
                //lerp(x,y,w)的逻辑是 return x + w*(y-x)
                //lerp一下灼烧色和原色 +0.1是控制灼烧区域范围
                tex = lerp(tex, _BurnColor,step(tex.r, saturate(_Cutoff+_BurnRange)));
                return tex;                
            }
            ENDHLSL
        }
    }
}

