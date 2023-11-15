Shader "URP/14_Hatching"
{
    Properties
    {        
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _OutlineColor("Outline Color", Color) = (0,0,0,1)
        _TileFactor("Tile Factor", Float) = 1   //纹理的平铺系数
        _Outline("Outline", Range(0,1)) = 0.1        //轮廓线的大小
        //下面是五张素描笔触的纹理，随着序号的增加，密度也跟着变大
        _Hatch0("Hatch 0", 2D) = "white" {}
        _Hatch1("Hatch 1", 2D) = "white" {}
        _Hatch2("Hatch 2", 2D) = "white" {}
        _Hatch3("Hatch 3", 2D) = "white" {}
        _Hatch4("Hatch 4", 2D) = "white" {}
        _Hatch5("Hatch 5", 2D) = "white" {}
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
        half4 _BaseColor;            
        half4 _OutlineColor;
        float _Outline;
        float _TileFactor;
        CBUFFER_END         
        ENDHLSL        

        //Pass1 渲染背面，得到轮廓
        Pass{
            Name "OUTLINE"

            Cull Front

            HLSLPROGRAM    
            #pragma vertex vert
            #pragma fragment frag

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f{
                float4 pos : SV_POSITION;
            };

            v2f vert(a2v v){
                v2f o;
                float4 pos = mul(UNITY_MATRIX_MV, v.vertex);
                //把顶点法线转换到view空间下
                float3 normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);

                //扩展的背面更加扁平化，从而降低了遮挡正面面片的可能性
                normal.z = -0.5;

                //在view空间下完成顶点扩张
                pos = pos + float4(normalize(normal), 0) * _Outline;
                o.pos = mul(UNITY_MATRIX_P, pos);

                return o;
            }

            half4 frag(v2f i) : SV_Target {
                return float4(_OutlineColor.rgb, 1.0);
            }
            ENDHLSL
        }
        
        Pass
        {
            Tags{
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM            
            TEXTURE2D(_Hatch0);
            SAMPLER(sampler_Hatch0);

            TEXTURE2D(_Hatch1);
            SAMPLER(sampler_Hatch1);

            TEXTURE2D(_Hatch2);
            SAMPLER(sampler_Hatch2);

            TEXTURE2D(_Hatch3);
            SAMPLER(sampler_Hatch3);

            TEXTURE2D(_Hatch4);
            SAMPLER(sampler_Hatch4);

            TEXTURE2D(_Hatch5);
            SAMPLER(sampler_Hatch5);

            #pragma vertex vert
            #pragma fragment frag

            struct a2v{
                float4 positionOS:POSITION;
                float3 normalOS:NORMAL;
                float4 tangent:TANGENT;                
                float2 texcoord:TEXCOORD0;
            };

            struct v2f{
                float4 positionCS : SV_POSITION;
                float3 uv : TEXCOORD0;
                half3 hatchWeight0 : TEXCOORD1;
                half3 hatchWeight1 : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
            };            
         
            v2f vert (a2v v)
            {
                v2f o;                
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positionInputs.positionCS;
                o.uv.xy = v.texcoord * _TileFactor;

                Light mainLight = GetMainLight();
                o.uv.z = mainLight.distanceAttenuation;

                half3 worldLightDir = normalize(TransformObjectToWorldDir(mainLight.direction));
                half3 worldNormal = normalize(TransformObjectToWorldNormal(v.normalOS));

                half diff = max(0, dot(worldLightDir, worldNormal));
            
                //初始默认为纯白色，其他笔触纹理的权重都为0
                o.hatchWeight0 = half3(0,0,0);
                o.hatchWeight1 = half3(0,0,0);

                float hatchFactor = diff * 7.0;   //将diff扩大区间范围[0,7]，并将该范围分为7个区间，每个区间是不同的笔触密度

                if(hatchFactor > 6.0){
                    //纯白色，啥也不做
                }else if(hatchFactor > 5.0){
                    o.hatchWeight0.x = hatchFactor - 5.0;
                }else if(hatchFactor > 4.0){
                    o.hatchWeight0.x = hatchFactor - 4.0;
                    o.hatchWeight0.y = 1.0 - o.hatchWeight0.x;
                }else if(hatchFactor > 3.0){
                    o.hatchWeight0.y = hatchFactor - 3.0;
                    o.hatchWeight0.z = 1.0 - o.hatchWeight0.y;
                }else if(hatchFactor > 2.0){
                    o.hatchWeight0.z = hatchFactor - 2.0;
                    o.hatchWeight1.x = 1.0 - o.hatchWeight0.z;
                }else if(hatchFactor > 1.0){
                    o.hatchWeight1.x = hatchFactor - 1.0;
                    o.hatchWeight1.y = 1.0 - o.hatchWeight1.x;
                }else{
                    o.hatchWeight1.y = hatchFactor;
                    o.hatchWeight1.z = 1.0 - o.hatchWeight1.y;
                }

                o.worldPos = positionInputs.positionWS;
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half4 hatchTex0 = SAMPLE_TEXTURE2D(_Hatch0, sampler_Hatch0, i.uv.xy) * i.hatchWeight0.x;
                half4 hatchTex1 = SAMPLE_TEXTURE2D(_Hatch1, sampler_Hatch1, i.uv.xy) * i.hatchWeight0.y;
                half4 hatchTex2 = SAMPLE_TEXTURE2D(_Hatch2, sampler_Hatch2, i.uv.xy) * i.hatchWeight0.z;
                half4 hatchTex3 = SAMPLE_TEXTURE2D(_Hatch3, sampler_Hatch3, i.uv.xy) * i.hatchWeight1.x;
                half4 hatchTex4 = SAMPLE_TEXTURE2D(_Hatch4, sampler_Hatch4, i.uv.xy) * i.hatchWeight1.y;
                half4 hatchTex5 = SAMPLE_TEXTURE2D(_Hatch5, sampler_Hatch5, i.uv.xy) * i.hatchWeight1.z;
                half4 whiteColor = half4(1,1,1,1) * (1 - i.hatchWeight0.x - i.hatchWeight0.y - i.hatchWeight0.z - 
                                                    i.hatchWeight1.x - i.hatchWeight1.y - i.hatchWeight1.z);
                
                half4 hatchColor = whiteColor + hatchTex0 + hatchTex1 + hatchTex2 + hatchTex3 + hatchTex4 + hatchTex5;
                return half4(hatchColor.rgb * _BaseColor.rgb * i.uv.z, 1.0);
            }
            ENDHLSL
        }
    }
}
