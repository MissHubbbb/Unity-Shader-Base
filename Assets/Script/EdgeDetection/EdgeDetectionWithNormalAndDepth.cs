using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("My Post-Processing/Edge Detection With Normal and Depth")]
public class EdgeDetectionWithNormalAndDepth : CustomPostProcessing
{
    public BoolParameter isEnable = new BoolParameter(false);
    public ColorParameter edgeColor = new ColorParameter(Color.white, false, false, true);
    public ColorParameter backgroundColor = new ColorParameter(Color.white, false, false, true);
    public ClampedFloatParameter edgeOnly = new ClampedFloatParameter(0.0f, 0.0f, 1.0f);
    public ClampedFloatParameter sampleDistance = new ClampedFloatParameter(1.0f, 0.0f, 2.0f);
    public MinFloatParameter sensitivityDepth = new MinFloatParameter(1.0f, 0.0f);
    public MinFloatParameter sensitivityNormal = new MinFloatParameter(1.0f, 0.0f);

    private const string mShaderName = "URP/13_EdgeDetectionWithNormalAndDepth";

    public override CustomPostProcessingInjectionPoint InjectionPoint => CustomPostProcessingInjectionPoint.BeforePostProcess;
    public override int OrderInInjectionPoint => 7;    

    //临时RT
    //private string mTempRT0Name = "_TemporaryRenderTexture0";
    //private RTHandle mTempRT0;

    public override bool IsActive()
    {
        return mMaterial != null && isEnable.value != false;
    }

    public override void Setup()
    {
        if(mMaterial == null)
            mMaterial = CoreUtils.CreateEngineMaterial(mShaderName);
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var descriptor = GetCameraRenderTextureDescriptor(renderingData);

        //RenderingUtils.ReAllocateIfNeeded(ref mTempRT0, descriptor, name:mTempRT0Name, wrapMode:TextureWrapMode.Clamp, filterMode:FilterMode.Bilinear);
    }

    public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source, RTHandle destination)
    {
        if(mMaterial == null){
            Debug.LogWarning("材质不存在");
            return;
        }
        
        mMaterial.SetColor("_EdgeColor", edgeColor.value);
        mMaterial.SetColor("_BackgroundColor", backgroundColor.value);
        mMaterial.SetFloat("_EdgeOnly", edgeOnly.value);
        mMaterial.SetFloat("_SampleDistance", sampleDistance.value);
        Vector4 sensitivity = new Vector4(sensitivityNormal.value,sensitivityDepth.value, 0, 0);
        mMaterial.SetVector("_Sensitivity", sensitivity);
        
        //cmd.Blit(source, mTempRT0, mMaterial, 0);
        //cmd.Blit(mTempRT0, destination, mMaterial, 1);
        cmd.Blit(source, destination, mMaterial, 0);
    }

    public override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
    }
}
