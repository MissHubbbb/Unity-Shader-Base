Shader "URP/15_WaterWave"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "white" {}   //水面波纹材质纹理
        _WaveMap("Wave Map", 2D) = "bump" {}        //由噪声纹理生成的法线纹理
        _Cubemap("Cube Map", Cube) = "_Skybox" {}   //用于模拟反射的立方体纹理
        _BaseColor("Base Color",Color)=(1,1,1,1)    //控制水面颜色
        _WaveXSpeed("Wave Horizontal Speed", Range(-0.1, 0.1)) = 0.01   //法线纹理在X方向上的平移速度
        _WaveYSpeed("Wave Vertical Speed", Range(-0.1, 0.1)) = 0.01     //法线纹理在Y方向上的平移速度
        _Distortion("Distortion", Range(0, 100)) = 10   //控制折射时图像的扭曲程度
    }
    SubShader
    {
        Tags {
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue"="Transparent"
            "RenderType" = "Opaque" 
        }        

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _WaveMap_ST;

        half4 _BaseColor;

        half _WaveXSpeed;
        half _WaveYSpeed;
        float _Distortion;  

        float4 _CameraOpaqueTexture_TexelSize;      
        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_WaveMap);
        SAMPLER(sampler_WaveMap);

        TEXTURE2D(_CameraOpaqueTexture);
        SAMPLER(sampler_CameraOpaqueTexture);

        TEXTURECUBE(_Cubemap);
        SAMPLER(sampler_Cubemap);

        struct a2v{
            float4 positionOS:POSITION;
            float4 normalOS:NORMAL;
            float4 tangentOS:TANGENT;
            float2 texcoord:TEXCOORD0;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            float4 uv:TEXCOORD0;
            float4 scrPos : TEXCOORD1;
            //该顶点对应的从切线空间转换到世界空间的矩阵.
            //将矩阵的每一行存储到下面三个向量的xyz中，而他们的z分量则用来存储世界坐标下顶点的位置
            //这里面使用的数学方法是：得到切线空间下的三个坐标轴(xyz轴分别对应了副切线，切线，法线)在世界空间下的表示
            //再把他们依次按列组成一个变换矩阵。
            float4 T2W0 : TEXCOORD2;
            float4 T2W1 : TEXCOORD3;
            float4 T2W2 : TEXCOORD4;
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
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positionInputs.positionCS;
                o.scrPos = positionInputs.positionNDC;

                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _WaveMap);

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS.xyz);
                o.T2W0.xyz = float4(normalInputs.tangentWS.x, normalInputs.bitangentWS.x, normalInputs.normalWS.x, positionInputs.positionWS.x);
                o.T2W1.xyz = float4(normalInputs.tangentWS.y, normalInputs.bitangentWS.y, normalInputs.normalWS.y, positionInputs.positionWS.y);
                o.T2W2.xyz = float4(normalInputs.tangentWS.z, normalInputs.bitangentWS.z, normalInputs.normalWS.z, positionInputs.positionWS.z);

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                float3 positionWS = float3(i.T2W0.w, i.T2W1.w, i.T2W2.w);
                half3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - positionWS);
                float2 speed = _Time.y * float2(_WaveXSpeed, _WaveYSpeed);

                //得到在切线空间下的法线
                half3 bump1 = UnpackNormal(SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, i.uv.zw + speed)).rgb;
                half3 bump2 = UnpackNormal(SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, i.uv.zw - speed)).rgb;
                half3 bump = normalize(bump1 + bump2);

                //计算在切线空间下的偏移量
                float2 offset = bump.xy * _Distortion * _CameraOpaqueTexture_TexelSize.xy;
                i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;    //偏移过的屏幕坐标
                //模拟近似的折射效果 _CameraOpaqueTexture是不透明物体在屏幕空间的截图
                half3 refrCol = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, i.scrPos.xy/i.scrPos.w).rgb;

                //将法线转到世界空间中去
                bump = normalize(half3(dot(i.T2W0.xyz, bump), dot(i.T2W1.xyz, bump), dot(i.T2W2.xyz, bump)));
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xw);

                //反射光
                half3 reflDir = normalize(reflect(-viewDirWS, bump));
                half3 reflColor = SAMPLE_TEXTURE2D(_Cubemap, sampler_Cubemap, reflDir).rgb;

                //菲涅尔 (fresnel越小，反射越弱，折射越强)
                half fresnel = pow(1 - saturate(dot(viewDirWS, bump)), 4);
                half3 finalColor = reflColor * fresnel + refrCol * (1 - fresnel);

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}
