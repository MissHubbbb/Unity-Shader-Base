using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEditor;

//后处理效果的注入点，这里先分四个
public enum CustomPostProcessingInjectionPoint{
    AfterOpaque,
    AfterSkybox,
    BeforePostProcess,
    AfterPostProcess
}

//这个类其实是自定义后处理的基类，应该改名为 MyVolumePostProcessing 比较合适
//自定义后处理的基类 (由于渲染时会生成临时RT，所以还需要继承IDisposable)
public abstract class CustomPostProcessing : VolumeComponent, IPostProcessComponent, IDisposable
{
    //材质声明，从高斯模糊开始使用
    protected Material mMaterial = null;
    static public Material copyMaterial = null;

    private const string mCopyShaderName = "URP/PostProcessCopy";

    //注入点
    public virtual CustomPostProcessingInjectionPoint InjectionPoint => CustomPostProcessingInjectionPoint.AfterPostProcess;

    //在注入点的顺序
    public virtual int OrderInInjectionPoint => 0;

    protected override void OnEnable()
    {
        base.OnEnable();
        if(copyMaterial == null){
            copyMaterial = CoreUtils.CreateEngineMaterial(mCopyShaderName);
        }
    }

    #region IPostProcessComponent
    //用来返回当前后处理是否active
    public abstract bool IsActive();
    
    //不知道用来干嘛的，但Bloom.cs里get值false，抄下来就行了
    public virtual bool IsTileCompatible() => false;

    //配置当前后处理
    public abstract void Setup();

    // 当相机初始化时执行（自己取的函数名，跟renderfeature里的OnCameraSetup没什么关系其实）
    public virtual void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData){

    }
    #endregion    
        
    //执行渲染
    public abstract void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source, RTHandle destination); 

    #region Draw Function
    //绘制全屏三角形
    private int mSourceTextureId = Shader.PropertyToID("_SourceTexture");

    //Draw函数的目的就是放弃使用带材质参数的Blit函数(实际上绘制了一个四边形);
    //而是自定义一个函数来使用绘制程序化三角形的方式进行渲染(它会调用CoreBlit.shader，并且只绘制一个三角形，这使得顶点和索引数量减少)。
    public virtual void Draw(CommandBuffer cmd, in RTHandle source, in RTHandle destination, int pass = -1){
        //将GPU端_SourceTexture设置为source
        cmd.SetGlobalTexture(mSourceTextureId, source);
        //将RT设置为destination，不关心初始状态(直接填充)，需要存储
        cmd.SetRenderTarget(destination, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        //绘制程序化三角形
        if(pass == -1 || mMaterial == null){
            cmd.DrawProcedural(Matrix4x4.identity, copyMaterial, 0, MeshTopology.Triangles, 3);
        }
        else{  
            cmd.DrawProcedural(Matrix4x4.identity, mMaterial, pass, MeshTopology.Triangles, 3);
        }
    }

    #endregion

    //获取相机描述符
    protected RenderTextureDescriptor GetCameraRenderTextureDescriptor(RenderingData renderingData){
        var descriptor = renderingData.cameraData.cameraTargetDescriptor;
        descriptor.msaaSamples = 1;
        descriptor.depthBufferBits = 0;
        descriptor.useMipMap = false;
        return descriptor;
    }

    #region IDisposable
    public void Dispose(){
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    public virtual void Dispose(bool disposing){

    }
    #endregion    
}
