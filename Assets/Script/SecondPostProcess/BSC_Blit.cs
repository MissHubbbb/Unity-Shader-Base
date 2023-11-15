using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("My Post-Processing/BSC_Blit")]
public class BSC_Blit : CustomPostProcessing
{
    public BoolParameter isEnable = new BoolParameter(false);
    public ClampedFloatParameter brightness = new ClampedFloatParameter(1.5f, 0.0f, 10.0f);
    public ClampedFloatParameter saturation = new ClampedFloatParameter(1.5f, 0.0f, 10.0f);
    public ClampedFloatParameter contrast = new ClampedFloatParameter(1.5f, 0.0f, 10.0f);

    private Material material;
    private const string mShaderName = "URP/12_BrightnessSaturationAndContrast";

    public override CustomPostProcessingInjectionPoint InjectionPoint => CustomPostProcessingInjectionPoint.AfterOpaque;
    public override int OrderInInjectionPoint => 0;

    public override bool IsActive()
    {
        //return false;   //要用的时候再把下面那行解开
        return (material != null && isEnable.value);
    }

    //配置当前后处理，创建材质
    public override void Setup()
    {
        if(material == null){
            material = CoreUtils.CreateEngineMaterial(mShaderName);
        }
    }

    //渲染，设置材质的各种参数
    public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source, RTHandle destination)
    {
        if(material == null)
        {
            Debug.LogWarning("材质不存在");
            return;
        }

        material.SetFloat("_Brightness", brightness.value);
        material.SetFloat("_Saturation", saturation.value);
        material.SetFloat("_Contrast", contrast.value);

        cmd.Blit(source, destination,material, 0);
    }

    public override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        CoreUtils.Destroy(material);
    }
}
