using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CustomPostProcessingPass : ScriptableRenderPass
{        
    //所有自定义后处理基类 列表
    private List<CustomPostProcessing> mCustomPostProcessings;

    //当前active组件下标
    private List<int> mActiveCustomPostProcessingIndex;

    //每个组件对应的ProfilingSampler，就是frameDebug上显示的
    private string mProfilerTag;
    private List<ProfilingSampler> mProfilingSamplers;

    //声明
    private RTHandle mSourceRT;
    private RTHandle mDesRT;
    private RTHandle mTempRT0;
    private RTHandle mTempRT1;

    private string mTempRT0Name => "_TemporaryRenderTexture0";
    private string mTempRT1Name => "_TemporaryRenderTexture1";

    //Pass的构造方法，参数都由Feature传入
    public CustomPostProcessingPass(string profilerTag, List<CustomPostProcessing> customPostProcessings){
        mProfilerTag = profilerTag;     //这个profilerTag就是在frame dbugger中我们自己额外创建的渲染通道的名字        
        mCustomPostProcessings = customPostProcessings;
        mActiveCustomPostProcessingIndex = new List<int>(customPostProcessings.Count);
        //将自定义后处理对象列表转换成一个性能采样器对象列表
        mProfilingSamplers = customPostProcessings.Select(c => new ProfilingSampler(c.ToString())).ToList();

        //在URP14.0(或者在这之前)中，抛弃了原有RenderTargetHandle，而通通使用RTHandle。原来的Init也变成了RTHandles.Alloc
        mTempRT0 = RTHandles.Alloc(mTempRT0Name, name:mTempRT0Name);
        mTempRT1 = RTHandles.Alloc(mTempRT1Name, name:mTempRT1Name);
    }

    // 相机初始化时执行
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData){
        var descriptor = renderingData.cameraData.cameraTargetDescriptor;
        descriptor.msaaSamples = 1;
        descriptor.depthBufferBits = 0;

        //分配临时纹理  TODO:还有疑问，关于_CameraColorAttachmentA和_CameraColorAttachmentB
        RenderingUtils.ReAllocateIfNeeded(ref mTempRT0, descriptor, name:mTempRT0Name);
        RenderingUtils.ReAllocateIfNeeded(ref mTempRT1, descriptor, name:mTempRT1Name);

        foreach(var i in mActiveCustomPostProcessingIndex){
            mCustomPostProcessings[i].OnCameraSetup(cmd, ref renderingData);
        }
    }          

    //获取active的CPPs下标，并返回是否存在有效组件
    public bool SetupCustomPostProcessing(){
        mActiveCustomPostProcessingIndex.Clear();  //mActiveCustomPostProcessingIndex的数量和mCustomPostProcessings.Count是相等的
        for(int i = 0; i < mCustomPostProcessings.Count; i++){
            mCustomPostProcessings[i].Setup();
            if(mCustomPostProcessings[i].IsActive()){
                mActiveCustomPostProcessingIndex.Add(i);
            }
        }
        return (mActiveCustomPostProcessingIndex.Count != 0);
    }      
        
    //实现渲染逻辑
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        //初始化CommandBuffer
        CommandBuffer cmd = CommandBufferPool.Get(mProfilerTag);
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();

        //获取相机Descriptor
        var descriptor = renderingData.cameraData.cameraTargetDescriptor;
        descriptor.msaaSamples = 1;
        descriptor.depthBufferBits = 0;

        //初始化临时RT
        bool rt1Used = false;        

        //1.声明temp0临时纹理
        //cmd.GetTemporaryRT(Shader.PropertyToID(mTempRT0.name), descriptor);
        // mTempRT0 = RTHandles.Alloc(mTempRT0.name);
        RenderingUtils.ReAllocateIfNeeded(ref mTempRT0, descriptor, name:mTempRT0Name);

        //2.设置源和目标RT为本次渲染的RT，在Execute里进行，特殊处理 后处理 后注入点
        mDesRT = renderingData.cameraData.renderer.cameraColorTargetHandle;
        mSourceRT = renderingData.cameraData.renderer.cameraColorTargetHandle;

        //执行每个组件的Render方法
        //3.如果只有一个后处理效果，则直接将这个后处理效果从mSourceRT渲染到mTempRT0(临时纹理)
        if(mActiveCustomPostProcessingIndex.Count == 1){   
            int index = mActiveCustomPostProcessingIndex[0];
            using(new ProfilingScope(cmd, mProfilingSamplers[index])){
                mCustomPostProcessings[index].Render(cmd, ref renderingData, mSourceRT, mTempRT0);
            }
        }
        else{
            //如果有多个组件，则在两个RT上来回blit。由于每次循环结束交换它们，所以最终纹理依然存在mTempRT0
            RenderingUtils.ReAllocateIfNeeded(ref mTempRT1, descriptor, name:mTempRT1Name);
            //Blitter.BlitCameraTexture(cmd, mSourceRT, mTempRT0);
            rt1Used = true;
            Blit(cmd, mSourceRT, mTempRT0);
            for(int i = 0; i < mActiveCustomPostProcessingIndex.Count; i++){
                int index = mActiveCustomPostProcessingIndex[i];
                var customProcessing = mCustomPostProcessings[index];
                using(new ProfilingScope(cmd, mProfilingSamplers[index])){
                    customProcessing.Render(cmd, ref renderingData, mTempRT0, mTempRT1);
                }

                CoreUtils.Swap(ref mTempRT0, ref mTempRT1);
            }
        }
        Blitter.BlitCameraTexture(cmd,mTempRT0, mDesRT);

        //释放
        cmd.ReleaseTemporaryRT(Shader.PropertyToID(mTempRT0.name));
        if(rt1Used){
            cmd.ReleaseTemporaryRT(Shader.PropertyToID(mTempRT1.name));
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
    
    //相机清除时执行
    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        mDesRT = null;
        mSourceRT = null;
    }    

    public void Dispose(){
        mTempRT0?.Release();
        mTempRT1?.Release();
    }
}
