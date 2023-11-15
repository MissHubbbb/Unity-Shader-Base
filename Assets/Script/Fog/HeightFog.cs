using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("My Post-Processing/Height Fog")]
public class HeightFog : CustomPostProcessing
{
    public BoolParameter isEnable = new BoolParameter(false);
    public ClampedFloatParameter fogDensity = new ClampedFloatParameter(1.0f, 0, 3);
    public MinFloatParameter fogStart = new MinFloatParameter(0f, 0f);
    public MinFloatParameter fogEnd = new MinFloatParameter(2.0f, 0f);
    public ColorParameter fogColor = new ColorParameter(Color.white, false, false, true);

    private Matrix4x4 frustumCorners;   //视锥体近平面的四个角，相对于相机的向量(大小和方向)

    private const string mShaderName = "URP/13_Fog";

    public override bool IsActive()
    {
        return (mMaterial != null) && (isEnable.value != false);
    }

    public override void Setup()
    {
        if(mMaterial == null)
            mMaterial = CoreUtils.CreateEngineMaterial(mShaderName);
    }

    public override void Render(CommandBuffer cmd, ref RenderingData renderingData, RTHandle source, RTHandle destination)
    {
        if(mMaterial == null){
            Debug.LogWarning("材质不存在");
            return;
        }

        //获取摄像机及其相关数据
        Camera camera = renderingData.cameraData.camera;
        Transform cameraTransform = camera.transform;
        float fov = camera.fieldOfView;
        float near = camera.nearClipPlane;
        float far = camera.farClipPlane;
        float aspect = camera.aspect;

        float halfHeight = near * Mathf.Tan(fov * 0.5f * Mathf.Deg2Rad);
        Vector3 toRight = cameraTransform.right * halfHeight * aspect;
        Vector3 toTop = cameraTransform.up * halfHeight;

        Vector3 topLeft = cameraTransform.forward * near + toTop - toRight;
        float scale = topLeft.magnitude / near;
        topLeft.Normalize();
        topLeft *= scale;

        Vector3 topRight = cameraTransform.forward * near + toTop + toRight;
        topRight.Normalize();
        topRight *= scale;

        Vector3 bottomLeft = cameraTransform.forward * near - toTop - toRight;
        bottomLeft.Normalize();
        bottomLeft *= scale;

        Vector3 bottomRight = cameraTransform.forward * near + toRight - toTop;
        bottomRight.Normalize();
        bottomRight *= scale;

        //设置矩阵的行,顺序是左下，右下，右上，左上
        frustumCorners.SetRow(0, bottomLeft);
        frustumCorners.SetRow(1, bottomRight);
        frustumCorners.SetRow(2, topRight);
        frustumCorners.SetRow(3, topLeft);

        mMaterial.SetMatrix("_FrustumCornersRay", frustumCorners);
        //mMaterial.SetMatrix("_ViewProjectionInverseMatrix", (camera.projectionMatrix * camera.worldToCameraMatrix).inverse);

        mMaterial.SetFloat("_FogDensity", fogDensity.value);
        mMaterial.SetFloat("_FogStart", fogStart.value);
        mMaterial.SetFloat("_FogEnd", fogEnd.value);

        mMaterial.SetColor("_FogColor", fogColor.value);

        cmd.Blit(source, destination, mMaterial, 0);
    }

    public override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
    }
}
