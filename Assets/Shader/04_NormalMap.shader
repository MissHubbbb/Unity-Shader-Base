Shader "URP/04_NormalMap"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        [Normal]_NormalTex("Normal",2D) = "bump"{}  //注意这里是小写
        _NormalScale("NormalScale", Range(0,1)) = 0.5
        _SpecularRange("SpecularRange", Range(1,200)) = 50
        [HDR]_SpecularColor("SpecularColor", Color) = (1,1,1,1)
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
        
        float4 _MainTex_ST;
        half4 _BaseColor;
        float4 _NormalTex_ST;
        real _NormalScale;
        real _SpecularRange;
        real4 _SpecularColor;

        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
        TEXTURE2D(_MainTex);             //纹理对象
        SAMPLER(sampler_MainTex);    //采样器

        TEXTURE2D(_NormalTex);
        SAMPLER(sampler_NormalTex);

        struct a2v{
            float4 positionOS:POSITION;
            float4 normalOS:NORMAL;
            float4 tangentOS:TANGENT;
            float2 texcoord:TEXCOORD;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            float4 texcoord:TEXCOORD0;       // 前两个分量用作漫反射纹理的偏移缩放，后两个分量用作法线纹理的偏移缩放
            float4 tangentWS:TANGENT;
            float4 normalWS:NORMAL;
            float4 Btangent:TEXCOORD1;
        };
        ENDHLSL

        Pass
        {
            //Tags {"LightMode" = "Always"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
         
            v2f vert (a2v v)
            {
                v2f o;
                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);    // 类似于上面那句
                o.normalWS.xyz = normalize(TransformObjectToWorldNormal(v.normalOS));
                o.tangentWS.xyz = normalize(TransformObjectToWorldDir(v.tangentOS));
                // 计算副切线时，叉乘法线，切线，并再乘切线的w值判断正负，再乘负奇数缩放影响因子。
                o.Btangent.xyz = normalize(cross(o.normalWS, o.tangentWS) * v.tangentOS.w * unity_WorldTransformParams.w);
                //再计算世界空间顶点坐标，并存储到法线、切线和副切线的w通道里
                float3 positionWS = TransformObjectToWorld(v.positionOS);
                o.tangentWS.w = positionWS.x;
                o.Btangent.w = positionWS.y;
                o.normalWS.w = positionWS.z;
                o.texcoord.xy = TRANSFORM_TEX(v.texcoord, _MainTex);        //主纹理的缩放偏移
                //o.texcoord.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;      //上面那句等价于这句
                o.texcoord.zw = TRANSFORM_TEX(v.texcoord, _NormalTex);   //法线贴图的缩放偏移
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);                

                float3 positionWS = float3(i.tangentWS.w, i.Btangent.w, i.normalWS.w);
                float3x3 TBN = {i.tangentWS.xyz, i.Btangent.xyz, i.normalWS.xyz};       //其实是TBN转置矩阵
                real4 nortex = SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.texcoord.zw);      // 三个参数：采样对象，采样器，采样坐标
                float3 normalTS = UnpackNormalScale(nortex, _NormalScale);      //会自动对法线贴图使用正确的解码，并缩放法线。
                //unpack操作是因为如果法线被mark为Normal标签后，会用两个通道表示，第三个分量需要根据normalize原理进行反算，这里事实上算的z就是反算z值。（也就是使向量的模恒为1）
                normalTS.z = pow((1-pow(normalTS.x, 2) - pow(normalTS.y, 2)), 0.5);     //规范化法线 z=sqrt(1-x*x-y*y)
                float3 norWS = normalize(mul(normalTS, TBN));      //TBN矩阵，向量右乘一个矩阵的转置，等于这个向量左乘这个矩阵

                Light myLight = GetMainLight();
                float halfLambertian = dot(normalize(myLight.direction), norWS) * 0.5 + 0.5;    //全兰伯特范围为(0,1),黑色的部分占很多，但是乘加0.5后范围就变成(0.5,1), 就会变亮很多
                // 漫反射颜色
                real4 diff = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord.xy) * halfLambertian * _BaseColor * real4(myLight.color, 1.0);
                // 高光
                float spe = pow(dot(  normalize( (normalize(_WorldSpaceCameraPos.xyz - positionWS) + normalize(myLight.direction))), norWS), _SpecularRange) * _SpecularColor;
                half4 tex = diff + spe;
                return tex;                
            }
            ENDHLSL
        }
    }
    //Fallback "Diffuse"
}
