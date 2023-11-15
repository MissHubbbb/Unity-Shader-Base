Shader "URP/08_MutiLight"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        [KeywordEnum(On, OFF)]_ADD_LIGHT("AddLight", float) = 1
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
        CBUFFER_END

        // �������������� sampler2D _MainTex;
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
            float3 WS_N:NORMAL;         //世界空间下的法线方向
            float3 WS_V:TEXCOORD1;      //世界空间下的观察方向
            float3 WS_P:TEXCOORD2;      //顶点的世界空间坐标
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
            #pragma shader_feature _ADD_LIGHT_ON _ADD_LIGHT_OFF
         
            v2f vert (a2v v)
            {
                v2f o;
                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);    // 类似于上面那句
                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);    
                o.WS_N = normalize(TransformObjectToWorldNormal(v.normalOS.xyz));
                o.WS_V = normalize(_WorldSpaceCameraPos - TransformObjectToWorld(v.positionOS.xyz));
                o.WS_P = TransformObjectToWorld(v.positionOS.xyz);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord) * _BaseColor;   //SAMPLE_TEXTURE2D类似上面那句采样的tex2D

                //计算主光源
                Light myLight = GetMainLight();
                float3 WS_Light = normalize(myLight.direction);
                float3 WS_Normal = i.WS_N;
                float3 WS_View = i.WS_V;
                float3 WS_H = normalize(WS_Light + WS_View);
                float3 WS_Pos = i.WS_P;
                float4 mainColor = (dot(WS_Light, WS_Normal) * 0.5 + 0.5) * tex * float4(myLight.color, 1.0);   //半兰伯特       

                //计算额外的光源
                real4 addColor = real4(0,0,0,1);
                #if _ADD_LIGHT_ON
                int addLightsCount = GetAdditionalLightsCount();        //定义在Lighting.hlsl中，返回额外灯光的数量
                for(int i = 0;i < addLightsCount; i++){
                    Light addLight = GetAdditionalLight(i, WS_Pos);      //定义在Lighting.hlsl中，返回灯光类型Light的数据
                    float3 WS_addLightDir = normalize(addLight.direction);      //该额外光源的光照方向
                    addColor += (dot(WS_Normal, WS_addLightDir) * 0.5 + 0.5) * real4(addLight.color, 1.0) * tex * addLight.distanceAttenuation * addLight.shadowAttenuation;
                }
                #else
                addColor = real4(0,0,0,1.0);
                #endif
                return mainColor + addColor;                
            }
            ENDHLSL
        }
    }
}
