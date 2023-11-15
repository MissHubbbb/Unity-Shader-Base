#ifndef POSTPROCESSING_INCLUDED
#define POSTPROCESSING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

TEXTURE2D(_SourceTexture);
SAMPLER(sampler_SourceTexture);
float4 _SourceTexture_TexelSize;

TEXTURE2D(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);

struct Attributes {
    float4 positionOS : POSITION;
    float2 uv : TEXCOORD0;
};

struct Varyings {
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
    UNITY_VERTEX_OUTPUT_STEREO
};

struct ScreenSpaceData{
    float4 positionCS;
    float4 positionNDC;
    float2 uv;
};

//以采样_SourceTexture为主
half4 GetSource(float2 uv){
    return SAMPLE_TEXTURE2D(_SourceTexture, sampler_SourceTexture, uv);
}

half4 GetSource(Varyings input){
    return GetSource(input.uv);
}

float4 GetSourceTexelSize(){
    return _SourceTexture_TexelSize;
}

float SampleDepth(float2 uv){
    #if defined(UNITY_STEREO_INSTANCEING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
    return SAMPLE_TEXTURE2D_ARRAY(_CameraDepthTexture, sampler_CameraDepthTexture, uv, unity_StereoEyeIndex).r;
    #else
    return SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
    #endif
}

float SampleDepth(Varyings input){
    return SampleDepth(input.uv);
}

//以采样_MainTex为主
half4 SampleSourceTexture(float2 uv) {
    return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
}

half4 SampleSourceTexture(Varyings input) {
    return SampleSourceTexture(input.uv);
}

//如果不用cmd.Blit方法，而是用自己写的Draw方法，就只会画一个大三角形(三角形内部包含我们的屏幕)，而不是两个三角形组成的四边形
//要注意这个三角形是顺时针渲染
ScreenSpaceData GetScreenSpaceData(uint vertexID : SV_VertexID){    //SV_VertexID表示第几个顶点，依次从第0开始
    ScreenSpaceData output;

    //根据id判断三角形顶点的坐标 （可以看到齐次坐标的第四个分量为1，表示前面三个分量是一个点的位置）
    output.positionCS = float4(vertexID <= 1 ? -1.0 : 3.0, vertexID == 1 ? 3.0 : -1.0, 0.0, 1.0);

    //因为三角形的底边和高 分别是 屏幕的宽高 的两倍，所以三角形的uv也会是屏幕uv的两倍，所以三角形的uv范围为[-2, 2]
    //以这个三角形的UV坐标（屏幕）分别为 (0,0),(0,2),(2,0)
    output.uv = float2(vertexID <= 1 ? 0.0 : 2.0, vertexID == 1 ? 2.0 : 0.0);   

    //不同API可能产生颠倒情况，需要进行判断
    if(_ProjectionParams.x < 0.0){
        output.uv.y = 1.0 - output.uv.y;
    }

    return output;
}

Varyings Vert(Attributes input) {
    Varyings output = (Varyings)0;
    // 分配instance id
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    output.vertex = vertexInput.positionCS;
    output.uv = input.uv;

    return output;
}

#endif