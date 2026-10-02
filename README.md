# 定风波

> 莫听穿林打叶声，何妨吟啸且徐行。
>
> —— 苏轼《定风波·莫听穿林打叶声》

水墨侠客 3D 动作游戏 · Godot 4.3 · 安卓

---

## 这是什么

一个用 **Godot 4.3** 做的水墨风格第三人称动作游戏。推送到 GitHub 后，
GitHub Actions 会**自动编译出安卓 APK**，你不需要电脑、不需要装任何开发工具。

## 怎么拿到 APK（手机也能操作）

1. **Fork 或上传** 这个仓库到你的 GitHub 账号
2. 进入仓库页面 → 点上方 **Actions** 标签
3. 左侧选 **「构建安卓 APK」** → 右侧点 **Run workflow** 按钮
4. 等 5～10 分钟（第一次会久一点，要下载 Godot 和 Android SDK）
5. 构建完成后，去仓库右侧 **Releases** 区域
6. 下载 **`定风波.apk`**，用手机浏览器打开安装

> 提示：安卓安装非商店 APK 时，需要在「设置 → 安全 → 安装未知应用」里
> 允许你的浏览器安装应用。

## 操作

| 操作 | 手机 | 键盘 |
|------|------|------|
| 移动 | 左半屏虚拟摇杆 | W A S D |
| 冲刺 | 摇杆推到底 | Shift |
| 攻击（三连击） | 右下「击」 | J / 鼠标左键 |
| 闪避 | 右下「避」 | K |

**闪避有 0.27 秒无敌帧** —— 在敌人出手的瞬间闪避可以完全躲开。

## 技术要点

### 画面
- **水墨描边**：反向外壳法（`shaders/ink_outline.gdshader`），逐网格复制外壳、
  沿法线外扩、翻面只画背面 —— 得到不随距离炸裂的稳定轮廓线
- **墨分五色**：角色着色器把连续光照明暗量化成 5 阶硬色带
  （`shaders/ink_character.gdshader`），这是水墨画感的来源，而不是贴图
- **空气透视**：`FogExp2` + 三层山的色阶配合，远景自然褪色进天空
- **景深**：Godot 4 里景深属于**相机属性**（`CameraAttributesPractical`），
  不在 `Environment` 上 —— 摄像机持续把主角位置喂给焦点距离
- **电影级光照**：低角度暖色方向光 + 4096 阴影贴图 + ACES 色调映射 + 曝光 0.82

### 性能
- 竹林用 **MultiMesh**：约 770 根竹子、数千片竹叶，各自只占 **1 个 draw call**
- 构建期就计算好所有变换，运行时不创建中间节点

### 美术资产
- 角色模型：[KayKit Adventurers Character Pack](https://kaylousberg.itch.io/kaykit-adventurers)
  by Kay Lousberg —— **CC0 1.0**，可商用、无需署名
  - 41 根骨骼 · 76 个动画 · glTF 2.0
  - 授权原文见 `assets/characters/LICENSE_KayKit.txt`

## 目录结构

```
.
├── project.godot              # 工程配置（含输入映射）
├── export_presets.cfg         # 安卓导出预设
├── .github/
│   ├── workflows/
│   │   └── build-android.yml  # 云端构建 APK
│   └── export_presets.cfg     # CI 用的导出配置副本
├── scenes/
│   ├── Main.tscn              # 主场景（游戏入口）
│   └── Shot.tscn              # 截图探针场景（开发用）
├── scripts/
│   ├── World.gd               # 场景总装（程序化生成，不依赖编辑器）
│   ├── Environment.gd         # 天空 / 雾 / 光照 / 后期
│   ├── Player.gd              # 主角控制（移动 / 三连击 / 闪避无敌帧）
│   ├── Enemy.gd               # 敌人 AI（游荡 / 追击 / 攻击冷却）
│   ├── Camera.gd              # 第三人称摄像机 + 景深追踪
│   ├── HUD.gd                 # 界面 + 虚拟摇杆 + 动作按钮
│   ├── Bamboo.gd              # 竹林生成器（MultiMesh 合批）
│   └── CombatDirector.gd      # 扇形攻击判定
├── shaders/
│   ├── ink_outline.gdshader   # 水墨描边
│   └── ink_character.gdshader # 水墨角色着色
└── assets/
    └── characters/            # 角色模型（CC0）
```

## 本地运行（可选，需要装 Godot 4.3）

```bash
godot --path . res://scenes/Main.tscn
```

## 协议

代码：MIT
角色模型：CC0 1.0（Kay Lousberg / KayKit）
