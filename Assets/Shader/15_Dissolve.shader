Shader "URP/15_Dissolve"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}  //主纹理
        _BumpMap("Normal Map", 2D) = "bump" {}      //法线纹理
        _BurnMap("Burn Map", 2D) = "white" {}       //消融噪声贴图
        _BurnAmount("Burn Amount", Range(0.0, 1.0)) = 0.0   //烧熔程度(也就是一个阈值)
        _LineWidth("Burn Line Width", Range(0.0, 0.2)) = 0.1    //烧熔的边界会向外延展一段距离，这段距离的宽度
        _BurnFirstColor("Burn First Color",Color)=(1,1,1,1) //烧熔边界内渐变颜色的第一种颜色
        _BurnSecondColor("Burn Second Color",Color)=(1,1,1,1) //烧熔边界内渐变颜色的第一种颜色        
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
        half _BurnAmount;
        half _LineWidth;

        half4 _BurnFirstColor;
        half4 _BurnSecondColor;

        float4 _MainTex_ST;
        float4 _BumpMap_ST;
        float4 _BurnMap_ST;
        CBUFFER_END

        // 下面两句类似于 sampler2D _MainTex;
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_BumpMap);
        SAMPLER(sampler_BumpMap);

        TEXTURE2D(_BurnMap);
        SAMPLER(sampler_BurnMap);

        struct a2v{
            float4 positionOS:POSITION;
            float3 normalOS:NORMAL;
            float4 tangentOS:TANGENT;
            float4 texcoord:TEXCOORD0;
        };

        struct v2f{
            float4 positionCS:SV_POSITION;
            float2 uv_MainTex : TEXCOORD0;
            float2 uv_BumpMap : TEXCOORD1;
            float2 uv_BurnMap : TEXCOORD2;
            float3 worldPos : TEXCOORD3;
            
            half3 normalWS : TEXCOORD4;
            half3 tangentWS : TEXCOORD5;
            half3 bitangentWS : TEXCOORD6;
        };
        ENDHLSL

        Pass
        {
            Name "BURN_DISSOLVE"
            Tags{
                "LightMode" = "UniversalForward"
            }

            Cull Off    //烧熔效果需要关闭提出效果，因为烧熔后需要看到背面的东西

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
         
            v2f vert (a2v v)
            {
                v2f o;
                VertexPositionInputs positionInputs  = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positionInputs.positionCS;
                o.worldPos = positionInputs.positionWS;

                o.uv_MainTex = TRANSFORM_TEX(v.texcoord.xy, _MainTex);
                o.uv_BumpMap = TRANSFORM_TEX(v.texcoord.xy, _BumpMap);
                o.uv_BurnMap = TRANSFORM_TEX(v.texcoord.xy, _BurnMap);

                //TANGENT_SPACE_ROTATION;
                //URP中已经去除，我们选择把法线通过TBN矩阵转换到世界空间，和书中把光线转换到TBN空间的结果是相同的

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.normalWS = normalInputs.normalWS;
                o.tangentWS = normalInputs.tangentWS;
                o.bitangentWS = normalInputs.bitangentWS;

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half3 burn = SAMPLE_TEXTURE2D(_BurnMap, sampler_BurnMap, i.uv_BurnMap);

                //比阈值小的片元就全部剔除
                clip(burn.x - _BurnAmount);

                //获取切线空间下的法线
                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.uv_BumpMap));
                //将法线从切线空间转换到世界空间
                half3 normalWS = TransformTangentToWorld(normalTS, half3x3(i.tangentWS, i.bitangentWS, i.normalWS));

                half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv_MainTex).rgb;
                half3 ambient = albedo * half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);

                Light mainLight = GetMainLight();
                half3 lightDirWS = normalize(TransformObjectToWorldDir(mainLight.direction));

                half3 diffuse = mainLight.color.rgb * albedo * max(0, dot(lightDirWS, normalWS));

                //t为1说明该像素在烧熔的边界上，为0则说明像素为正常的模型颜色
                half t = 1 - smoothstep(0.0, _LineWidth, burn.x - _BurnAmount);
                half3 burnColor = lerp(_BurnFirstColor, _BurnSecondColor, t);
                //为了让效果更接近烧焦的痕迹，使用pow函数对结果进行处理
                burnColor = pow(burnColor, 5);

                half3 finalColor = lerp(ambient + diffuse * mainLight.distanceAttenuation, burnColor, t * step(0.0001, _BurnAmount));

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }

        Pass{
            Name "SHADOW_CASTER_DISSOLVE"
            Tags{
                "LightMode" = "ShadowCaster"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            half3 _LightDirection;

            v2f vert(a2v v){
                v2f o;
                float3 worldPos = TransformObjectToWorld(v.positionOS.xyz);
                float3 worldNormal = TransformObjectToWorldNormal(v.normalOS);
                //阴影专用裁剪空间坐标
                o.positionCS = TransformObjectToHClip(ApplyShadowBias(worldPos, worldNormal, _LightDirection));

                //判断是否在DX平台，决定是否反转
                #if UNITY_REVERSED_Z
                    o.positionCS.z = min(o.positionCS.z, o.positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    o.positionCS.z = max(o.positionCS.z, o.positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                o.uv_BurnMap = TRANSFORM_TEX(v.texcoord ,_BurnMap);
                return o;
            }

            half4 frag(v2f i) : SV_Target {
                half3 burn = SAMPLE_TEXTURE2D(_BurnMap, sampler_BurnMap, i.uv_BurnMap).rgb;

                clip(burn.r - _BurnAmount);
                return 0;
            }
            ENDHLSL
        }
    }
}
