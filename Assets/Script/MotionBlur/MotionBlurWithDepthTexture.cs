using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("My Post-Processing/Motion Blur with Depth Texture")]
public class MotionBlurWithDepthTexture : CustomPostProcessing
{
    public BoolParameter isEnable = new BoolParameter(false);
    public ClampedFloatParameter blurSize = new ClampedFloatParameter(0.5f, 0.0f, 1.0f);
    public ClampedIntParameter drawCount = new ClampedIntParameter(2, 1, 4);
    public ClampedFloatParameter speedTime = new ClampedFloatParameter(2.0f, 0.1f, 3.0f);
    private Matrix4x4 previousViewProjectionMatrix = Matrix4x4.identity;
    //private Matrix4x4 currentViewProjectionMatrix = Matrix4x4.identity;
    //private Matrix4x4 currentViewProjectionInverseMatrix = Matrix4x4.identity;

    //private Camera camera;

    private int mBlurSizeKy = Shader.PropertyToID("_BlurSize");
    private int mDrawCountKy = Shader.PropertyToID("_DrawCount");
    private int mSpeedTimeKy = Shader.PropertyToID("_SpeedTime");
    private int mPreviousMatrixKy = Shader.PropertyToID("_PreviousViewProjectionMatrix");
    private int mCurrentVPMatrixKy = Shader.PropertyToID("_CurrentViewProjectionInverseMatrix");

    private const string mShaderName = "URP/13_MotionBlurWithDepthTexture";

    public override CustomPostProcessingInjectionPoint InjectionPoint => CustomPostProcessingInjectionPoint.BeforePostProcess;
    public override int OrderInInjectionPoint => 6;

    //临时RT
    private string mTempRT0Name => "_TemporaryRenderTexture0";
    
    private RTHandle mTempRT0;

    public override bool IsActive()
    {
        return mMaterial != null && isEnable.value;
    }

    public override void Setup()
    {
        if(mMaterial == null)
            mMaterial = CoreUtils.CreateEngineMaterial(mShaderName);
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var descriptor = GetCameraRenderTextureDescriptor(renderingData);        

        RenderingUtils.ReAllocateIfNeeded(ref mTempRT0, descriptor, name:mTempRT0Name, wrapMode:TextureWrapMode.Clamp, filterMode:FilterMode.Bilinear);
    }

    public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source, RTHandle destination)
    {
        if(mMaterial == null){
            Debug.LogWarning("材质不存在");
            return;
        }

        Camera camera = renderingData.cameraData.camera;        

        mMaterial.SetFloat(mBlurSizeKy, blurSize.value);
        mMaterial.SetInt(mDrawCountKy, drawCount.value);
        mMaterial.SetFloat(mSpeedTimeKy, speedTime.value);

        //此时第一次传给shasder的投影*视角变换矩阵可能为空或者单位矩阵. 因为一开始并没有对这个矩阵变量赋值
        mMaterial.SetMatrix(mPreviousMatrixKy, previousViewProjectionMatrix);

        Matrix4x4 currentViewProjectionMatrix = camera.projectionMatrix * camera.worldToCameraMatrix;
        Matrix4x4 currentViewProjectionInverseMatrix = currentViewProjectionMatrix.inverse;

        //mMaterial.SetMatrix(mCurrentVPMatrixKy, currentViewProjectionInverseMatrix);
        cmd.SetGlobalMatrix(mCurrentVPMatrixKy, currentViewProjectionInverseMatrix);
                
        previousViewProjectionMatrix = currentViewProjectionMatrix;
        
        cmd.Blit(source, destination, mMaterial, 0);
        //cmd.Blit(source, mTempRT0, mMaterial, 0);
        //cmd.Blit(mTempRT0, destination);
    }

    public override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        CoreUtils.Destroy(mMaterial);

        mTempRT0?.Release();
    }
}
