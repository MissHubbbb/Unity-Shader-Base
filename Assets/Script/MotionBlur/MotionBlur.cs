using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("My Post-Processing/MotionBlur")]
public class MotionBlur : CustomPostProcessing
{
    public BoolParameter isEnable = new BoolParameter(false);
    private const string mShaderName = "URP/12_MotionBlur";

    public ClampedFloatParameter blurAmount = new ClampedFloatParameter(0.2f, 0.0f, 0.9f);
    private int blurAmountKw = Shader.PropertyToID("_BlurAmount");

    public override CustomPostProcessingInjectionPoint InjectionPoint => CustomPostProcessingInjectionPoint.BeforePostProcess;
    public override int OrderInInjectionPoint => 4;

    //临时RT
    private string mTempRT0Name = "_TemporaryRenderTexture0";
    //private string mTempRT1Name = "_TemporaryRenderTexture1";

    private RTHandle mTempRT0;
    //private RTHandle mTempRT1;

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
        
        //为临时RT初始化
        RenderingUtils.ReAllocateIfNeeded(ref mTempRT0, descriptor, name:mTempRT0Name, wrapMode:TextureWrapMode.Clamp, filterMode:FilterMode.Bilinear);
        //RenderingUtils.ReAllocateIfNeeded(ref mTempRT1, descriptor, name:mTempRT1Name, wrapMode:TextureWrapMode.Clamp, filterMode:FilterMode.Bilinear);
    }

    public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source, RTHandle destination)
    {
        if(mMaterial == null){
            Debug.LogWarning("材质不存在");
            return;
        }

        mMaterial.SetFloat(blurAmountKw, 1.0f - blurAmount.value);
        cmd.Blit(source, mTempRT0, mMaterial, 0);
        cmd.Blit(source, mTempRT0, mMaterial, 1);
        cmd.Blit(mTempRT0, destination);
    }

    public override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        CoreUtils.Destroy(mMaterial);
        mTempRT0?.Release();
    }
}
