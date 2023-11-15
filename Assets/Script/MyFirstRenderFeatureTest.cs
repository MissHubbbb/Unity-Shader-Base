using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class MyFirstRenderFeatureTest : ScriptableRendererFeature
{   
    // static Material blitMaterial = new Material(blitShader);
    /// <summary>
    /// 这个类是Render Feature中的主要组成部分，也就是一个render pass
    /// </summary> <summary>
    /// 
    /// </summary>
    class CustomRenderPass : ScriptableRenderPass
    {
        //找到场景中的shader中的texture，并获取该贴图的id
        static string rt_name = "_ExampleRT";
        static int rt_ID = Shader.PropertyToID(rt_name);

        static string blitShader_Name = "URP/BlitShader";
        static Shader blitShader = Shader.Find(blitShader_Name);
        static Material blitMat = new Material(blitShader);
        /// <summary>
        /// 帮助Excete() 提前准备它需要的RenderTexture或者其他变量
        /// </summary>
        /// <param name="cmd"></param>
        /// <param name="renderingData"></param>
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // 存储render texture一些格式标准的数据结构
             RenderTextureDescriptor descriptor = new RenderTextureDescriptor(1920, 1080,RenderTextureFormat.Default, 0);
             // 然后创建一个临时的render texture的缓存/空间
             cmd.GetTemporaryRT(rt_ID, descriptor);

            // 想画其他东西到rt上的话就需要下面这句
             ConfigureTarget(rt_ID);
             ConfigureClear(ClearFlag.Color, Color.black);
        }

        /// <summary>
        /// 实现这个render pass做什么事情
        /// </summary>
        /// <param name="context"></param>
        /// <param name="renderingData"></param>
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // 到命令缓存池中get一个
            CommandBuffer cmd = CommandBufferPool.Get("tmpCmd");
            cmd.Blit(renderingData.cameraData.renderer.cameraColorTarget, rt_ID, blitMat);       //添加一个命令：将像素数据从A复制到B
            context.ExecuteCommandBuffer(cmd);      //因为是自己创建的cmd，所以需要手动地将renderingData提交到context里去
            cmd.Clear();
            cmd.Release();
        }

        /// <summary>
        /// 释放在OnCameraSetup() 里声明的变量，尤其是Temporary Render Texture
        /// </summary>
        /// <param name="cmd"></param>
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(rt_ID);
        }
    }

    /// <summary>
    /// 声明一个render pass的变量
    /// </summary>
    CustomRenderPass m_ScriptablePass;

    /// <summary>
    /// 这个方法是render feature中用来给上面声明的render pass赋值，并决定这个render pass什么使用会被调用(不一定每帧都被执行)
    /// </summary>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();

        // renderPassEvent定义什么时候去执行m_ScriptablePass 这个render pass
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
    }

    /// <summary>
    /// 将create函数里实例化的render pass加入到渲染管线中(每帧都执行)
    /// </summary>
    /// <param name="renderer"></param>
    /// <param name="renderingData"></param>
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


