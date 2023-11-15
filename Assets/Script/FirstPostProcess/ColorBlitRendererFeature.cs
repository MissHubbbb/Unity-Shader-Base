using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ColorBlitRendererFeature : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {        
        // 给profiler入一个新的事件
        private ProfilingSampler m_ProfilingSampler = new ProfilingSampler("ColorBlit");
        private Material m_Material;

        // RTHandle，封装了纹理及相关信息，可以认为是CPU端纹理
        private RTHandle m_CameraColorTarget;
        private float m_Intensity;

        public CustomRenderPass(Material material){
            m_Material = material;
            //指定执行这个pass的时机
            renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        }

        //指定进行后处理的target
        public void SetTarget(RTHandle colorHandle, float Intensity){
            m_CameraColorTarget = colorHandle;
            m_Intensity = Intensity;
        }

        // OnCameraSetup是纯虚函数，相机初始化时调用
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            //(父类函数)指定pass的render target
            ConfigureTarget(m_CameraColorTarget);
        }

        //Execute是抽象函数，把cmd命令添加到context中（然后进一步送到GPU调用）
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cameraData = renderingData.cameraData;
            if(cameraData.cameraType != CameraType.Game){
                return;
            }

            if(m_Material == null){
                Debug.LogWarning("材质不存在");
            }

            //获取CommandBuffer
            CommandBuffer cmd = CommandBufferPool.Get();

            //把cmd里执行的命令添加到m_ProfilingSampler定义的profiler块中
            //using 用来自动释放new的资源
            using(new ProfilingScope(cmd, m_ProfilingSampler)){
                m_Material.SetFloat("_Intensity", m_Intensity);

                //使用cmd里的命令(设置viewport、分辨率等)，执行m_Material的pass0，将将m_CameraColorTarget渲染到m_CameraColorTarget
                //本质上画了一个覆盖屏幕的三角形
                Blitter.BlitCameraTexture(cmd, m_CameraColorTarget, m_CameraColorTarget, m_Material, 0);                
            }

            //把cmd中的命令放入到context中
            context.ExecuteCommandBuffer(cmd);
            //清空cmd栈
            cmd.Clear();

            CommandBufferPool.Release(cmd);
        }

        
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    public Shader m_Shader;
    public float m_Intensity;

    private Material m_Material;
    private CustomRenderPass m_ScriptablePass;

    // 基类的抽象函数 OnEnable和OnValidate时调用
    public override void Create()
    {
        // 创建一个附带m_Shader的material
        m_Material = CoreUtils.CreateEngineMaterial(m_Shader);
        // 创建CustomRenderPass脚本实例
        m_ScriptablePass = new CustomRenderPass(m_Material);
    }

    //当为每个camera设置一个renderer时，AddRenderPasses函数将被调用，从而向这个camera的renderer入队自定义RenderPass。
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(renderingData.cameraData.cameraType == CameraType.Game){
            // Pass入队
            renderer.EnqueuePass(m_ScriptablePass);
        }        
    }

    //当每个camera渲染前，SetupRenderPasses函数将被调用，从而设置自定义RenderPass的渲染源RT和渲染目标RT。
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        // 只对游戏摄像机应用后处理（还有预览摄像机等）
        if(renderingData.cameraData.cameraType == CameraType.Game){
            // 设置向pass输入color (m_RenderPass父类)
            m_ScriptablePass.ConfigureInput(ScriptableRenderPassInput.Color);
            // 设置RT为相机的color
            m_ScriptablePass.SetTarget(renderer.cameraColorTargetHandle, m_Intensity);
        }
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(m_Material);
    }
}


