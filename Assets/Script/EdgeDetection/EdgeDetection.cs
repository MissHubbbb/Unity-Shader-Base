using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("My Post-Processing/EdgeDetection")]
public class EdgeDetection : CustomPostProcessing
{
    public BoolParameter isEnable = new BoolParameter(false);
    public ClampedFloatParameter edgeOnly = new ClampedFloatParameter(0.5f, 0.0f, 1.0f);
    public ColorParameter edgeColor = new ColorParameter(new Color(0.4f, 0.5f, 0.3f), overrideState:true);
    public ColorParameter backgroundColor = new ColorParameter(new Color(0.51f, 0.05f, 0.92f), overrideState:true);

    private Material material;
    private const string mShaderName = "URP/12_EdgeDetection";

    public override CustomPostProcessingInjectionPoint InjectionPoint => CustomPostProcessingInjectionPoint.AfterPostProcess;
    public override int OrderInInjectionPoint => 0;

    public override bool IsActive() //这个脚本能激活的前提是材质不为空
    {
        //return false;   //要用的时候再把下面那行解开
        return (material != null && isEnable.value);
    }

    public override void Setup()
    {
        if(material == null)
        {
            material = CoreUtils.CreateEngineMaterial(mShaderName);
        }
    }

    public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source, RTHandle destination)
    {
        if(material == null){
            Debug.LogWarning("材质不存在");
            return;
        }

        material.SetFloat("_EdgeOnly", edgeOnly.value);
        material.SetColor("_EdgeColor", edgeColor.value);
        material.SetColor("_BackgroundColor", backgroundColor.value);
    
        cmd.Blit(source, destination, material, 0);
    }

    public override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        CoreUtils.Destroy(material);
    }
}
