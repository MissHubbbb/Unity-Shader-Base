Shader "URP/06_AlphaBlend"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _AlphaTex("AlphaTex", 2D) = "white"{}
    }
    SubShader
    {
        Tags {
        "RenderPipeline" = "UniversalRenderPipeline"
        "IgnoreProjector" = "True"      //不希望任何投影类型材质或者贴图，影响我们的物体或者着色器
        "RenderType"="Transparent"
        "Queue" = "Transparent"
        }        

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        float4 _AlphaTex_ST;
        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_AlphaTex);           //采样对象
        SAMPLER(sampler_AlphaTex);  //采样器

        struct a2v{
            float4 positionOS:POSITION;
            float4 normalOS:NORMAL;
            float2 texcoord:TEXCOORD;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            float4 texcoord:TEXCOORD;
        };
        ENDHLSL

        Pass
        {
            Tags{
                "LightMode" = "UniversalForward"
            }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
         
            v2f vert (a2v v)
            {
                v2f o;
                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.texcoord.xy = TRANSFORM_TEX(v.texcoord, _MainTex);                
                o.texcoord.zw = TRANSFORM_TEX(v.texcoord, _AlphaTex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord.xy) * _BaseColor;   //SAMPLE_TEXTURE2D类似上面那句采样的tex2D
                float alpha = SAMPLE_TEXTURE2D(_AlphaTex, sampler_AlphaTex, i.texcoord.zw).x;       // 取_AlphaTex贴图的x通道作为最终输出图像的透明度
                //因为Blend SrcAlpha OneMinusSrcAlpha，所以输出颜色为 DstColor_new = SrcAlpha * SrcColor + (1-SrcAlpha) * DstColor_old
                return half4(tex.xyz, alpha);                
            }
            ENDHLSL
        }
    }
}

