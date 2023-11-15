Shader "URP/14_ToonShading"
{
    Properties {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {}
		_Ramp ("Ramp Texture", 2D) = "white" {} //渐变纹理
		_Outline ("Outline", Range(0, 1)) = 0.1 //控制轮廓线大小
		_OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_SpecularScale ("Specular Scale", Range(0, 0.1)) = 0.01 //控制高光区域的阈值
	}
    SubShader
    {
        Tags {"RenderPipeline" = "UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float _Outline;
			half4 _OutlineColor;
            half4 _Color;
			float4 _MainTex_ST;
			half4 _Specular;
			half _SpecularScale;
        CBUFFER_END

        ENDHLSL

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
		
        //【Pass1 渲染背面,得到轮廓】
		Pass {
			NAME "OUTLINE"
			
			Cull Front  //正面剔除
			
			HLSLPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			}; 
			
			struct v2f {
			    float4 pos : SV_POSITION;
			};
			
			v2f vert (a2v v) {
				v2f o;
				                
				float4 pos = mul(UNITY_MATRIX_MV, v.vertex); 
                //把顶点法线转换到view空间
				float3 normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);  
                
                //扩展的背面更加扁平化，从而降低了挡住正面面片的可能性
				normal.z = -0.5;
                //在view空间完成顶点扩张
				pos = pos + float4(normalize(normal), 0) * _Outline;
				o.pos = mul(UNITY_MATRIX_P, pos);
				
				return o;
			}
			
			float4 frag(v2f i) : SV_Target { 
				return float4(_OutlineColor.rgb, 1);               
			}
			
			ENDHLSL
		}
		
        //【Pass2 卡渲正面】
		Pass {
            NAME "BODY"
			Tags { "LightMode"="UniversalForward" }
			
			Cull Back
		
			HLSLPROGRAM
		
			#pragma vertex vert
			#pragma fragment frag

            TEXTURE2D(_MainTex);       SAMPLER(sampler_MainTex);
            TEXTURE2D(_Ramp);       SAMPLER(sampler_Ramp);
		
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
				//float4 tangent : TANGENT;
			}; 
		
			struct v2f {
				float4 pos : POSITION;
				float2 uv : TEXCOORD0;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
			};
			
			v2f vert (a2v v) {
				v2f o;
				
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
				//o.pos = TransformObjectToHClip( v.vertex);
                o.pos = positionInputs.positionCS;
				o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
				o.worldNormal  = TransformObjectToWorldNormal(v.normal);
				//o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.worldPos = positionInputs.positionWS;
				
				return o;
			}
			
			float4 frag(v2f i) : SV_Target { 
                //获取主光源信息
				Light mainLight = GetMainLight();
				
                half3 worldLightDir = normalize(TransformObjectToWorldDir(mainLight.direction));
                //half3 worldNormal = normalize(i.worldNormal);
				//half3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				half3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
				half3 worldHalfDir = normalize(worldLightDir + worldViewDir);
				
				half4 c = SAMPLE_TEXTURE2D (_MainTex, sampler_MainTex, i.uv);
				half3 albedo = c.rgb * _Color.rgb;
				
				half3 ambient = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w) * albedo;
                half atten = mainLight.distanceAttenuation;
				
				//UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				
				half diff =  dot(i.worldNormal, worldLightDir);
				diff = (diff * 0.5 + 0.5) * atten;
				
				half3 diffuse = mainLight.color * albedo * SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, float2(diff, diff)).rgb;
				
				half spec = dot(i.worldNormal, worldHalfDir);
                
                //GPU在光栅化的时候一般以2x2的像素块为单位并行执行的。
                //此函数计算以下内容： abs (ddx (x) ) + abs (ddy (x) ),即相邻像素点该数值的变化度 。
                //ddx，ddy反映了相邻像素在屏幕空间x和y方向上的距离（变化率）
                half w = fwidth(spec) * 2.0;    //相邻像素点高光的差值
                //-1是为了缩小高光点。step(0.0001, _SpecularScale)这句是为了当_SpecularScale为0的时候，完全消除高光的效果
				half3 specular = mainLight.color * _Specular.rgb * lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1)) * step(0.0001, _SpecularScale);
				
				return half4(ambient + diffuse + specular, 1.0);
			}
		
			ENDHLSL
		}
	}
	FallBack "Packages/com.unity.render-pipelines.universal/FallbackError"
}
