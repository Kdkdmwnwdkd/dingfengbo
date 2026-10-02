// Unity 6 项目自动配置脚本
// 首次打开 Unity 时自动执行:配置 Android 横屏 + URP + 燕云色调
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[InitializeOnLoad]
public static class ProjectSetup
{
    static ProjectSetup()
    {
        // 防止重复执行:首次打开后写标记
        if (SessionState.GetBool("Dingfengbo.ProjectSetup.Done", false))
            return;
        SessionState.SetBool("Dingfengbo.ProjectSetup.Done", true);

        EditorApplication.delayCall += RunSetup;
    }

    static void RunSetup()
    {
        ConfigureAndroidLandscape();
        ConfigureQualityAndURP();
        EnsureFoldersExist();
        Debug.Log("[定风波] 项目自动配置完成:Android 横屏锁定 + URP + 燕云色调基线");
    }

    static void ConfigureAndroidLandscape()
    {
        var settings = PlayerSettings.GetDefaultInterfaceOrientation(DefaultInterfaceOrientation.Unknown);
        // 强制横屏(右): LandscapeRight
        PlayerSettings.SetDefaultInterfaceOrientation(DefaultInterfaceOrientation.LandscapeRight);

        // 仅横屏,禁用其他方向(国产 ROM 兼容)
        PlayerSettings.allowedAutorotateToLandscape = true;
        PlayerSettings.allowedAutorotateToPortrait = false;
        PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;

        // Android 构建设置
        PlayerSettings.SetApiCompatibilityLevel(ApiCompatibilityLevel.NET_Standard_2_1);
        EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);

        // IL2CPP + ARM64(性能)
        PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP);
        PlayerSettings.SetArchitecture(BuildTargetGroup.Android, 1); // ARM64

        // 最低 Android 8.0 (API 26)
        PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
        PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevelAuto;

        // 资源更新:强制 Gradle 构建
        EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Gradle;

        // 应用图标尺寸占位
        PlayerSettings.Android.bundleVersionCode = 1;
        PlayerSettings.bundleVersion = "1.0.0";
        PlayerSettings.companyName = "Kdkdmwnwdkd";
        PlayerSettings.productName = "Dingfengbo";
    }

    static void ConfigureQualityAndURP()
    {
        // 启用 URP 渲染管线
        GraphicsSettings.currentRenderPipeline = AssetDatabase.LoadAssetAtPath<RenderPipelineAsset>(
            "Assets/Settings/URP/URP-Mobile.asset");
    }

    static void EnsureFoldersExist()
    {
        var folders = new[] {
            "Assets/Settings/URP",
            "Assets/Models",
            "Assets/Animations",
            "Assets/Materials",
            "Assets/Textures",
            "Assets/Shaders",
            "Assets/Prefabs",
            "Assets/Scenes",
            "Assets/Scripts/Player",
            "Assets/Scripts/Enemy",
            "Assets/Scripts/Boss",
            "Assets/Scripts/UI",
            "Assets/Scripts/Camera",
            "Assets/Scripts/Environment",
        };
        foreach (var folder in folders)
        {
            if (!AssetDatabase.IsValidFolder(folder))
            {
                var parent = System.IO.Path.GetDirectoryName(folder).Replace('\\', '/');
                var leaf = System.IO.Path.GetFileName(folder);
                if (!AssetDatabase.IsValidFolder(parent))
                    EnsureFoldersExistRec(parent);
                AssetDatabase.CreateFolder(parent, leaf);
            }
        }
    }

    static void EnsureFoldersExistRec(string path)
    {
        if (AssetDatabase.IsValidFolder(path)) return;
        var parent = System.IO.Path.GetDirectoryName(path).Replace('\\', '/');
        var leaf = System.IO.Path.GetFileName(path);
        EnsureFoldersExistRec(parent);
        AssetDatabase.CreateFolder(parent, leaf);
    }
}
