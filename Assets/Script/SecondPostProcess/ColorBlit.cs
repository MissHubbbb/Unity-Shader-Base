using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("My Post-Processing/Color Blit2")]
public class ColorBlit : CustomPostProcessing
{
    public ClampedFloatParameter intensity = new ClampedFloatParameter(0.0f, 0.0f, 2.0f);

    private Material material;
    private const string mShaderName = "URP/ColorBlit2";    

    public override bool IsActive()
    {
        //return false;   //要用的时候再把下面那行解开
        return (material != null && intensity.value > 0);
    }

    public override CustomPostProcessingInjectionPoint InjectionPoint => CustomPostProcessingInjectionPoint.BeforePostProcess;
    public override int OrderInInjectionPoint => 0;

    public override void Setup()
    {
        if(material == null){
            material = CoreUtils.CreateEngineMaterial(mShaderName);
        }
    }

    public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source, RTHandle destination)
    {
        if(material == null){
            Debug.LogWarning("材质不存在，请检查");
            return;
        }

        material.SetFloat("_Intensity", intensity.value);
        cmd.Blit(source, destination, material, 0);
    }

    public override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        CoreUtils.Destroy(material);
    }
}
