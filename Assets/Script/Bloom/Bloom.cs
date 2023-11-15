using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("My Post-Processing/Bloom")]
public class Bloom : CustomPostProcessing
{
    public BoolParameter isEnable = new BoolParameter(false);
    public ClampedIntParameter iterations = new ClampedIntParameter(1, 0, 4);
    public ClampedFloatParameter blurSpread = new ClampedFloatParameter(0.6f, 0.2f, 3.0f);
    public ClampedIntParameter downSample = new ClampedIntParameter(2, 1, 8);
    public ClampedFloatParameter luminanceThreshold = new ClampedFloatParameter(0.6f, 0.0f, 4.0f);

    //pass插入位置以及在该位置中的渲染顺序
    public override CustomPostProcessingInjectionPoint InjectionPoint => CustomPostProcessingInjectionPoint.BeforePostProcess;
    public override int OrderInInjectionPoint => 5;

    //材质用的shader
    public const string mShaderName = "URP/12_Bloom";

    //shader中的属性
    private int mBlurSizeKeyword = Shader.PropertyToID("_BlurSize");
    private int mLuminThresholdKeyword = Shader.PropertyToID("_LuminanceThreshold");

    //辅助RT及其相关信息
    private string mTempRT0Name = "_TemporaryRenderTexture0";
    private string mTempRT1Name = "_TemporaryRenderTexture1";
    private RTHandle mTempRT0;
    private RTHandle mTempRT1;

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
        descriptor.width = (int)(descriptor.width / downSample.value);
        descriptor.height = (int)(descriptor.height / downSample.value);

        RenderingUtils.ReAllocateIfNeeded(ref mTempRT0, descriptor, name:mTempRT0Name, wrapMode:TextureWrapMode.Clamp, filterMode:FilterMode.Bilinear);
        RenderingUtils.ReAllocateIfNeeded(ref mTempRT1, descriptor, name:mTempRT1Name, wrapMode:TextureWrapMode.Clamp, filterMode:FilterMode.Bilinear);
    }

    public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source, RTHandle destination)
    {
        if(mMaterial == null){
            Debug.LogWarning("材质不存在");
            return;
        }

        cmd.SetGlobalFloat(mLuminThresholdKeyword, luminanceThreshold.value);
        //一共用了四个pass，中间两个是用了高斯模糊中的两个pass
        //提取阈值以上的亮部区域纹理
        cmd.Blit(source, mTempRT0, mMaterial, 0);

        for(int i = 0; i < iterations.value; i++){
            cmd.SetGlobalFloat(mBlurSizeKeyword, 1.0f + i * blurSpread.value);

            //高斯模糊水平处理
            cmd.Blit(mTempRT0, mTempRT1, mMaterial, 1);

            //高斯模糊垂直处理
            cmd.Blit(mTempRT1, mTempRT0, mMaterial, 2);
        }
        //给Bloom贴图赋值
        cmd.SetGlobalTexture("_Bloom", mTempRT0);

        //bloom合并
        cmd.Blit(source, mTempRT1, mMaterial, 3);
        cmd.Blit(mTempRT1, destination);
    }

    public override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        CoreUtils.Destroy(mMaterial);

        mTempRT0?.Release();
        mTempRT1?.Release();
    }
}
