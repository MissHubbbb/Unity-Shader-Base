using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("My Post-Processing/GaussinBlur")]
public class GaussinBlur : CustomPostProcessing
{
    //高斯模糊的范围
    public ClampedFloatParameter blurSpread = new ClampedFloatParameter(0.5f, 0.1f, 3.0f);
    //高斯模糊的迭代次数
    public ClampedIntParameter iterations = new ClampedIntParameter(0,0,15);
    //高斯模糊的缩放系数的参数，downSample越大，需要处理的像素数越少，同时也能进一步提高模糊程度，但过大的downSample会使图片像素化
    public ClampedFloatParameter downSaling = new ClampedFloatParameter(2.0f,1.0f,8.0f);

    private int mBlurSizeKeyword = Shader.PropertyToID("_BlurSize");
    
    public const string mShaderName = "URP/12_GaussianBlur";
    //public FilterMode filterMode {get; set;}

    public override CustomPostProcessingInjectionPoint InjectionPoint => CustomPostProcessingInjectionPoint.BeforePostProcess;
    public override int OrderInInjectionPoint => 3;

    //辅助RT名字及其RT
    private string mTempRT0Name => "_TemporaryRenderTexture0";
    private string mTempRT1Name => "_TemporaryRenderTexture1";

    private RTHandle mTempRT0;
    private RTHandle mTempRT1;

    public override bool IsActive()
    {
        return mMaterial != null && iterations.value != 0;
    }

    public override void Setup()
    {
        if(mMaterial == null){
            mMaterial = CoreUtils.CreateEngineMaterial(mShaderName);                        
        }
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var descriptor = GetCameraRenderTextureDescriptor(renderingData);
        descriptor.width = (int)(descriptor.width / downSaling.value);
        descriptor.height = (int)(descriptor.height / downSaling.value);

        //为两张临时RT初始化
        RenderingUtils.ReAllocateIfNeeded(ref mTempRT0, descriptor, name:mTempRT0Name, wrapMode:TextureWrapMode.Clamp, filterMode:FilterMode.Bilinear);
        RenderingUtils.ReAllocateIfNeeded(ref mTempRT1, descriptor, name:mTempRT1Name, wrapMode:TextureWrapMode.Clamp, filterMode:FilterMode.Bilinear);
    }

    public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source, RTHandle destination)
    {
        if(mMaterial == null){
            Debug.LogWarning("材质不存在");
            return;
        }                
        
        cmd.Blit(source, mTempRT0);
        
        for(int i = 0; i < iterations.value; i++){            
            cmd.SetGlobalFloat(mBlurSizeKeyword, 1.0f + i * blurSpread.value);
            
            //Horizontal           
            cmd.Blit(mTempRT0, mTempRT1, mMaterial, 0);

            //Vertical     
            cmd.Blit(mTempRT1, mTempRT0, mMaterial, 1);
        }

        cmd.Blit(mTempRT0, destination);
    }    

    public override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        CoreUtils.Destroy(mMaterial);    

        mTempRT0?.Release();
        mTempRT1?.Release();    
    }
}
