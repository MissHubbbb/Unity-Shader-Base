using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class myBlit : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        public Material passMat = null;
        public FilterMode passfiltMode { get; set; }
        RenderTargetIdentifier passSource { get; set; }//源图像，目标图像
        RenderTargetHandle passTempTex;//临时计算图像
        //RenderTargetIdentifier、RenderTargetHandle都可以理解为RT
        //Identifier为camera提供的需要被应用的texture，Handle为被shader处理渲染过的RT
        string passTag;
        ProfilingSampler passProfilingSampler = new ProfilingSampler("myBlitProfiling");
        public CustomRenderPass(RenderPassEvent passEvent, Material material, string tag)
        {
            this.renderPassEvent = passEvent;
            this.passMat = material;
            this.passTag = tag;
        }

        public void setup(RenderTargetIdentifier source)
        {
            this.passSource = source;
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {   //类似于OnRenderImage
            CommandBuffer cmd = CommandBufferPool.Get(passTag);
            using (new ProfilingScope(cmd, passProfilingSampler))
            {
                RenderTextureDescriptor CameraTexDesc = renderingData.cameraData.cameraTargetDescriptor;
                //CameraTexDesc.depthBufferBits = 0;
                cmd.GetTemporaryRT(passTempTex.id, CameraTexDesc, passfiltMode);//申请一个临时图像
                cmd.Blit(passSource, passTempTex.Identifier(), passMat);
                cmd.Blit(passTempTex.Identifier(), passSource);
            }
            context.ExecuteCommandBuffer(cmd);//执行命令
            CommandBufferPool.Release(cmd);//释放回收
        }
    }

    [System.Serializable]
    public class mySetting
    {
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;
        public Material myMat;
        [Range(0, 2)]
        public float brightness = 1f;
        [Range(0, 2)]
        public float saturate = 1f;
        [Range(0, 2)]
        public float contranst = 1f;
        public Color ColorTint = new Color(1, 1, 1, 1);
    }

    public mySetting setting = new mySetting();
    CustomRenderPass myPass;
    public override void Create()
    {//进行初始化,这里最先开始
        setting.myMat.SetFloat("_brightness", setting.brightness);
        setting.myMat.SetFloat("_saturate", setting.saturate);
        setting.myMat.SetFloat("_contranst", setting.contranst);
        setting.myMat.SetColor("_ColorTint", setting.ColorTint);
        myPass = new CustomRenderPass(setting.passEvent, setting.myMat, name);//实例化一下并传参数,name就是tag
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(myPass);
    }
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        myPass.setup(renderer.cameraColorTargetHandle);
    }
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
    }
}
