# 定风波

> 莫听穿林打叶声,何妨吟啸且徐行。
>
> —— 苏轼《定风波·莫听穿林打叶声》

Unity 6 LTS 重制版 · 燕云十六声国风 · Android 单机

> **当前状态**:Unity 项目骨架已搭好(脚本 + Android 配置 + CI + 场景生成器),
> 等待用户在 Unity 编辑器打开项目首次自动配置 + 下载/导入模型资源。

---

## 项目背景

原 Godot 4.3 项目在国产 ROM 上有不可调和的 Android 横屏锁定兼容性问题,
故改用 Unity 6 LTS 重做。原 Godot 项目代码已归档至 `archive/godot-old/` 仅供参考。

- 完整背景与建模资源调研:[`docs/建模资源报告-Unity重制版.md`](docs/建模资源报告-Unity重制版.md)
- 原横屏 bug 排查过程:[`docs/排查报告-横版改造与模型损坏.md`](docs/排查报告-横版改造与模型损坏.md)

---

## 角色定型

| 角色 | 模型 | 来源 | 许可证 |
|---|---|---|---|
| 主角 | Lanhwa 汉服女 | https://sketchfab.com/3d-models/lanhwa-c114521ec6764e819cf3ad03d63d96a9 | CC-BY |
| Boss | 張飛 Zhang Fei | https://sketchfab.com/3d-models/zhang-fei-292f54372f6e4e56bd5b796f475005c2 | CC-BY |
| 小怪 | Chinese Warrior - Jin Dynasty | https://sketchfab.com/3d-models/chinese-warrior-jin-dynasty-220-280-ad-c8b2395af47f4ba8a161e0c96fc940a0 | CC-BY |
| NPC | Low Poly Chinese Merchant | https://sketchfab.com/3d-models/low-poly-chinese-merchant-characters-npc-f932b44eced84f0eb0adcd15a75bb933 | CC-BY |
| 补充 | GanzSe Modular | https://assetstore.unity.com/packages/3d/characters/humanoids/fantasy/ganzse-free-modular-character-fantasy-low-poly-pack-321521 | Unity 免费 |

动画用 Adobe Mixamo(免费可商用)。

---

## 项目结构

```
dingfengbo/
├── Assets/
│   ├── Editor/
│   │   └── ProjectSetup.cs            # 首次打开自动配置 Android 横屏 + URP + 目录
│   ├── Plugins/Android/
│   │   └── AndroidManifest.xml        # 强制 landscape + 禁小窗模式
│   ├── Scripts/
│   │   ├── Player/
│   │   │   ├── PlayerController.cs    # 主角控制(走/跑/跳/击/避 8 状态机)
│   │   │   └── Health.cs              # 血量组件
│   │   ├── Camera/
│   │   │   └── CameraRig.cs           # 第三人称相机
│   │   ├── UI/
│   │   │   └── VirtualHUD.cs          # 虚拟摇杆 + 按钮(横屏自适应)
│   │   ├── Enemy/
│   │   │   └── EnemyAI.cs             # 敌人 AI(巡逻+追击+攻击+受击)
│   │   └── Environment/
│   │       ├── BambooForest.cs        # 竹林场景生成器(燕云三远法调色)
│   │       └── YanYunVolume.cs        # 燕云后期处理(青冥色调+雾+做旧)
│   └── Settings/URP/                  # URP 配置(用户首次打开后由脚本生成)
├── Packages/manifest.json             # Unity 6 + URP 17.0.3 + Input System + TMP
├── ProjectSettings/ProjectVersion.txt # Unity 6000.0
├── archive/godot-old/                 # 原 Godot 项目存档
├── docs/                              # 排查 + 建模报告
└── .github/workflows/build-unity.yml  # GitHub Actions 自动构建 APK
```

---

## 模型导入工作流

每个角色的处理流程:

```
1. Sketchfab 下载 .glb/.fbx
2. Blender 减面(Decimate modifier,1.1M→30-50k 三角面)
3. (可选)Blender 重拓扑关键变形区域
4. 上传 Mixamo Auto-Rigger 自动绑骨
5. Mixamo 套用动画库(Idle/Walk/Run/Attack/Dodge/Hit/Death)
6. 下载 .fbx with skin
7. 拖入 Unity Assets/Models/
8. Inspector → Rig → Animation Type: Humanoid
9. 创建 Animator Controller 组合动画
10. 场景放置 + 挂脚本 + Collider
```

详见 [建模报告](docs/建模资源报告-Unity重制版.md) 第七节。

---

## 本地首次打开步骤

1. 装 Unity Hub:https://unity.com/download
2. 在 Hub 里装模块 **Unity 6000.0 LTS** + **Android Build Support + OpenJDK + Android SDK & NDK**
3. `Add project from disk` → 选本仓库根目录
4. 打开项目,首次会自动跑 `ProjectSetup.cs`:
   - 设置 Android 横屏锁定
   - 切换到 IL2CPP + ARM64
   - 切换渲染管线到 URP
   - 创建 Assets 下所有子目录
5. 切到 Android 平台(File → Build Profiles → Android → Switch)
6. 跑通后 Push 到 GitHub 触发 CI 构建 APK

---

## CI 配置(GitHub Actions)

仓库 Settings → Secrets and variables → Actions 需配置以下 secrets:

| Secret | 用途 | 获取方式 |
|---|---|---|
| `UNITY_LICENSE` | Unity Personal/Pro license | Unity Hub → Settings → License → 个人版可自动获取 |
| `ANDROID_KEYSTORE_NAME` | keystore 文件名(如 `user.keystore`) | 自签名生成 |
| `ANDROID_KEYSTORE_BASE64` | keystore 的 base64 编码 | `base64 user.keystore` |
| `ANDROID_KEYSTORE_PASS` | keystore 密码 | 自签名时设置 |
| `ANDROID_KEYALIAS_NAME` | key alias | 自签名时设置 |
| `ANDROID_KEYALIAS_PASS` | key alias 密码 | 自签名时设置 |

配置后 push 代码或打 `v*` tag 即可触发自动构建。

- 普通 push:在 Actions 页面下载 APK artifact
- push tag(`v1.0.0` 等):自动创建 Release 并附 APK

---

## 操作

| 操作 | 手机 | 键盘 |
|---|---|---|
| 移动 | 左下虚拟摇杆 | W A S D |
| 跑 | 摇杆推满 | Shift |
| 跳跃 | 右下「跳」 | Space |
| 攻击(三连击) | 右下「击」 | J / 鼠标左键 |
| 闪避 | 右下「避」 | K |

闪避有 0.05-0.22 秒无敌帧(`PlayerController.cs` `IsInvincible` 属性)。

---

## 协议

代码:MIT
角色模型:CC-BY(发布时需在 credits 署名作者,见建模报告第四节)
