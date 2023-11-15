using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

//自定义Render Feature，实现后会自动在RenderFeature面板上可供添加
//我们的RenderFeature抓取的CusomProcessing是全部基于VolumenComponent的派生类，而不是当前场景Global Volume组件里的后处理
public class CustomPostProcessingFeature : ScriptableRendererFeature
{    
    private CustomPostProcessingPass mAfterOpaquePass;
    private CustomPostProcessingPass mAfterSkyboxPass;
    private CustomPostProcessingPass mBeforePostProcessPass;
    private CustomPostProcessingPass mAfterPostProcessPass;

    //所有后处理基类列表
    private List<CustomPostProcessing> mCustomPostProcessings;    

    //最重要的方法，用来生成RenderPass
    //获取所有CustomPostProcessing实例，并且根据插入点顺序，放入到对应Render Pass中，并且指定Pass Event
    public override void Create()
    {
        //获取VolumeStack
        var stack = VolumeManager.instance.stack;

        //获取所有的CustomPostProcessing实例
        mCustomPostProcessings = VolumeManager.instance.baseComponentTypeArray
            .Where(t => t.IsSubclassOf(typeof(CustomPostProcessing)))  //筛选出VolumeComponent派生类类型中所有的CustomPostProcessing类型元素，不论是否在Volume中，不论是否激活
            .Select(t => stack.GetComponent(t) as CustomPostProcessing) //将类型元素转化为实例
            .ToList();  //转化为List

        #region 初始化不同插入点的render pass

        #region 初始化在不透明物体渲染之后的pass
        //找到在不透明物后渲染的CustomPostProcessing
        var afterOpaqueCPPs = mCustomPostProcessings
            .Where(c => c.InjectionPoint == CustomPostProcessingInjectionPoint.AfterOpaque)   // 筛选出所有CustomPostProcessing类中注入点为透明物体和天空后的实例
            .OrderBy(c => c.OrderInInjectionPoint)  //按顺序排序
            .ToList();  //转化为List

        // 创建CustomPostProcessingPass类
        mAfterOpaquePass = new CustomPostProcessingPass("Custom Post-Process after Opaque", afterOpaqueCPPs);
        //设置pass执行时间
        mAfterOpaquePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        #endregion

        #region 初始化在透明物体和天空渲染后的pass
        var afterTransAndSkyboxCPPs = mCustomPostProcessings
            .Where(c => c.InjectionPoint == CustomPostProcessingInjectionPoint.AfterSkybox)
            .OrderBy(c => c.OrderInInjectionPoint)
            .ToList();

        mAfterSkyboxPass = new CustomPostProcessingPass("Custom Post-Process after transparent and skybox", afterTransAndSkyboxCPPs);
        mAfterSkyboxPass.renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
        #endregion

        #region 初始化在后处理效果渲染之前的pass
        var beforePostProcessCPPs = mCustomPostProcessings
            .Where(c => c.InjectionPoint == CustomPostProcessingInjectionPoint.BeforePostProcess)
            .OrderBy(c => c.OrderInInjectionPoint)
            .ToList();

        mBeforePostProcessPass = new CustomPostProcessingPass("Custom Post-Process before PostProcess", beforePostProcessCPPs);
        mBeforePostProcessPass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        #endregion

        #region 初始化在后处理效果渲染之后的pass
        var afterPostProcessCPPs = mCustomPostProcessings
            .Where(c => c.InjectionPoint == CustomPostProcessingInjectionPoint.AfterPostProcess)
            .OrderBy(c => c.OrderInInjectionPoint)
            .ToList();

        mAfterPostProcessPass = new CustomPostProcessingPass("Custom Post-Process after PostProcess", afterPostProcessCPPs);
        mAfterPostProcessPass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
        #endregion

        #endregion
    }

    // 当为每个摄像机设置一个渲染器时，调用此方法
    // 将不同注入点的RenderPass注入到renderer中(添加Pass到渲染队列)
    //网上有些资料在这个函数里配置RenderPass的源RT和目标RT，具体来说使用类似RenderPass.Setup(renderer.cameraColorTargetHandle, renderer.cameraColorTargetHandle)的方式.
    //但是这在URP14.0中会报错，提示renderer.cameraColorTargetHandle只能在ScriptableRenderPass子类里调用。具体细节可以查看最后的参考连接。
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //当前渲染的游戏相机支持后处理
        if(renderingData.cameraData.postProcessEnabled){
            //为每个render pass设置RT
            //并且将pass列表加到renderer中
            if(mAfterOpaquePass.SetupCustomPostProcessing()){
                mAfterOpaquePass.ConfigureInput(ScriptableRenderPassInput.Color);
                renderer.EnqueuePass(mAfterOpaquePass);
            }

            if(mAfterSkyboxPass.SetupCustomPostProcessing()){
                mAfterSkyboxPass.ConfigureInput(ScriptableRenderPassInput.Color);
                renderer.EnqueuePass(mAfterSkyboxPass);
            }

            if(mBeforePostProcessPass.SetupCustomPostProcessing()){
                mBeforePostProcessPass.ConfigureInput(ScriptableRenderPassInput.Color);
                renderer.EnqueuePass(mBeforePostProcessPass);
            }
            
            if(mAfterPostProcessPass.SetupCustomPostProcessing()){
                mAfterPostProcessPass.ConfigureInput(ScriptableRenderPassInput.Color);
                renderer.EnqueuePass(mAfterPostProcessPass);
            }
        }
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);

        //mAfterSkyboxPass.Dispose();
        //mBeforePostProcessPass.Dispose();
        //mAfterPostProcessPass.Dispose();

        if(disposing && mCustomPostProcessings != null){
            foreach(var item in mCustomPostProcessings){
                item.Dispose();
            }
        }
    }
}


