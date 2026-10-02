# 《定风波》Unity 重制版 - 建模资源报告

> 报告版本:v1.0
> 日期:2026-10-02
> 决策:从 Godot 4.3 迁移到 Unity 6 LTS,Android 单机版,燕云十六声国风

---

## 一、项目背景与决策

### 1.1 迁移原因

原 Godot 4.3 项目在 Android ROM 兼容性上存在不可调和问题:

| 版本 | manifest screenOrientation | 性质 | ROM 能否无视 |
|---|---|---|---|
| v1.0.22 | 12 (userPortrait) | 用户竖屏 | 是(Godot 还映射错了) |
| v1.0.23 | 6 (sensorLandscape) | 传感器横屏 | 是(依赖自动旋转开关) |
| v1.0.24 | 0 (landscape) | 静态横屏 | 是(实测仍被强制竖屏) |

**结论**:Godot 预编译模板的 Android 导出在国产 ROM 上无法保证横屏锁定,继续 patch manifest 已无意义。决定**改用 Unity 6 LTS** 重做,理由:
- Unity 是 Android 武侠游戏主流引擎(深岩、老山、饮月之龙均为 Unity)
- Gradle 原生构建,横屏锁定不会被 ROM 无视
- URP 渲染管线对体积雾/PBR 材质/移动端优化成熟

### 1.2 视觉风格定位

参考对标:**《燕云十六声》**(Where Winds Meet)

#### 视觉要素
- **色彩**:低饱和青墨色调,玄黑/鸦青/赭石/蟹壳青,色彩纯度 20-40%
- **光影**:基于物理的渲染 + 风格化后期,漫射光为主,体积光克制使用
- **材质**:做旧美学,金属氧化暗沉、布料起球褪色、石材风化苔藓
- **场景**:竹林垂直线条 + 体积雾大气透视 + 留白构图
- **角色**:白袍点睛,万灰丛中一点白

#### 氛围公式
```
肃杀(武侠类型底色)
+ 寂寥(宋代美学气质)
+ 克制(当代极简设计)
= 燕云独特情绪签名
```

### 1.3 项目结构决策

- **仓库**:沿用 `Kdkdmwnwdkd/dingfengbo`,**清空重建**
- **平台**:Android 单机版(无网可玩)
- **构建**:Unity 6 LTS + URP + Gradle 模式
- **CI**:GitHub Actions + Unity 官方 Action 自动构建 APK

---

## 二、角色模型资源清单

### 2.1 主角 - Lanhwa(汉服女)

| 字段 | 内容 |
|---|---|
| **名称** | Lanhwa |
| **来源** | https://sketchfab.com/3d-models/lanhwa-c114521ec6764e819cf3ad03d63d96a9 |
| **作者** | SEKAYJI |
| **许可证** | CC-BY(署名,免费可商用) |
| **面数** | 1.1M 三角面 / 566.7k 顶点 |
| **动画** | 无(需 Mixamo Auto-Rigger 绑骨 + 套用动画) |
| **格式** | Sketchfab 导出 .gltf/.glb/.fbx |
| **造型** | 汉服女持莲花,汉 Dynasty 风格,龙纹白裙,仙气飘飘 |

#### 必需的优化工作

1. **减面**:1.1M → 30k-50k 三角面(Android 移动端友好)
   - 用 Blender Decimate modifier 或 Instant Meshes 重拓扑
   - 保留 UV,烘焙法线贴图补偿细节
2. **重拓扑**:AI 生成模型拓扑杂乱,关键变形区域(肩/肘/膝/腰)需重新布线
3. **Mixamo Auto-Rigger**:上传减面后的 .fbx 到 Mixamo 自动绑骨
4. **动画套用**:从 Mixamo 动画库选取
   - Idle: `Idle.fbx`
   - Walk: `Walk.fbx`
   - Run: `Run.fbx`
   - Attack: `Attack_1.fbx` / `Attack_2.fbx`(三连击组合)
   - Dodge: `Dodge.fbx`(闪避无敌帧)
   - Hit/Death: `Hit.fbx` / `Death.fbx`
5. **燕云青墨调色**:在 Unity Shader Graph 里调
   - 主色相:H 180-200°(青绿)
   - 饱和度:S 降到 20-30%
   - 明度压缩:L 限制在 20-80%
   - 红色发饰保留作为画面唯一暖色点缀(<2% 画面占比)

---

### 2.2 Boss - 張飛 Zhang Fei ⭐ 用户选定

| 字段 | 内容 |
|---|---|
| **名称** | 張飛 Zhang Fei |
| **来源** | https://sketchfab.com/3d-models/zhang-fei-292f54372f6e4e56bd5b796f475005c2 |
| **作者** | 觀山閱海 Gwen&Rein(apishkaede) |
| **许可证** | CC-BY(署名,免费可商用) |
| **面数** | 2.8M 三角面 / 1.4M 顶点 |
| **动画** | 无(高模胸像/头雕,需补全身形 + Mixamo 绑骨) |
| **格式** | Sketchfab 导出 .gltf/.glb/.fbx |
| **造型** | 粗犷黑须猛将,豹头环眼、燕颔虎须、面色黝黑,持丈八蛇矛 |
| **参考扮相** | 李靖飞 1994 版《三国演义》张飞形象 |

#### 必需的优化工作

1. **大幅减面**:2.8M → 80k-150k 三角面(Boss 可比小怪面数高)
2. **补全身形**:原模型主要是胸像/头雕,需用 ZBrush/Blender 雕刻全身身体
3. **丈八蛇矛武器**:作者备注未包含,需独立建模长矛武器
4. **Mixamo 绑骨**:用 Mixamo Auto-Rigger 绑骨
5. **动画套用**:从 Mixamo 选取 Boss 专用动画
   - Idle: `Boss_Idle.fbx`(威严站立)
   - Walk: `Boss_Walk.fbx`(缓慢沉重)
   - Run: `Boss_Run.fbx`(冲锋)
   - Attack_Heavy: `Boss_Slash.fbx`(横扫)
   - Attack_Thrust: `Boss_Thrust.fbx`(突刺)
   - Hit: `Boss_Hit.fbx`(受击)
   - Death: `Boss_Death.fbx`(倒地)
6. **气场强化**(用户特别要求):
   - **体型放大**:缩放 1.5-2 倍主角身高
   - **暗色处理**:黑袍 + 暗金属盔甲
   - **能量光效**:身上有暗红色裂纹光(Boss 怒气值越高越亮)
   - **出场动画**:开战前从雾中走出,黑雾粒子
   - **BGM**:出场时切换为低频鼓点 + 古琴紧张音
   - **特效**:攻击时拖尾使用暗红色粒子,非白色常规拖尾

---

### 2.3 小怪 - Chinese Warrior Jin Dynasty(晋朝武士)

| 字段 | 内容 |
|---|---|
| **名称** | Chinese Warrior - Jin Dynasty (220-280 AD) |
| **来源** | https://sketchfab.com/3d-models/chinese-warrior-jin-dynasty-220-280-ad-c8b2395af47f4ba8a161e0c96fc940a0 |
| **作者** | Mariusz Waclawek |
| **许可证** | CC-BY(署名,免费可商用) |
| **面数** | 1.3k 三角面(超低面,完美适配 Android) |
| **贴图** | 512px |
| **动画** | 无(需 Mixamo 绑骨) |
| **格式** | Sketchfab 导出 .gltf/.glb/.fbx |
| **造型** | 正宗中国晋朝武士,持戟(戈矛),文化考据到位 |
| **优势** | 面数极低,可大量复制做小怪群(同屏 10+ 不掉帧) |

#### 必需的优化工作

1. **Mixamo 绑骨**:上传 .fbx 到 Mixamo Auto-Rigger
2. **动画套用**:
   - Idle: `Idle.fbx`
   - Walk: `Walk.fbx`
   - Attack: `Attack.fbx`(戟横扫)
   - Hurt: `Hit.fbx`
   - Death: `Death.fbx`
3. **AI 行为**:用 Unity NavMeshAgent 实现简单巡逻 + 围攻
4. **变体**:通过贴图色相微调做出 3-5 种小怪外观变体

---

### 2.4 NPC - Low Poly Chinese Merchant(中国商人 NPC 组合包)

| 字段 | 内容 |
|---|---|
| **名称** | Low Poly Chinese Merchant Characters NPC |
| **来源** | https://sketchfab.com/3d-models/low-poly-chinese-merchant-characters-npc-f932b44eced84f0eb0adcd15a75bb933 |
| **作者** | Nisa Nurul Azizah(nisanurulazizah) |
| **许可证** | CC-BY(署名,免费可商用) |
| **面数** | 3k-5k 三角面(低面手绘风) |
| **动画** | 无(需 Mixamo 绑骨套 Idle) |
| **格式** | Sketchfab 导出 .gltf/.glb/.fbx |
| **造型** | 多角色组合包(商人 NPC),低面手绘风,Android 友好 |
| **优势** | 一包多用,可拼出集市/商铺多种 NPC |

#### 必需的优化工作

1. **拆分**:把组合包拆成独立 NPC 角色
2. **Mixamo 绑骨**:每个角色单独绑骨
3. **动画套用**:Idle + Talk + Gesture(对话姿势)
4. **交互**:Unity Collider + 对话 UI

---

### 2.5 Unity Asset Store 免费补充 - GanzSe Modular

| 字段 | 内容 |
|---|---|
| **名称** | GanzSe FREE Modular Character - Fantasy Low Poly Pack |
| **来源** | https://assetstore.unity.com/packages/3d/characters/humanoids/fantasy/ganzse-free-modular-character-fantasy-low-poly-pack-321521 |
| **许可证** | Standard Unity Asset Store EULA(免费 Extension,可商用) |
| **格式** | .unitypackage(Unity 6.0.3 原生兼容) |
| **造型** | 模块化奇幻低面角色,可拼装多种 NPC/小怪变体 |
| **用途** | 补充角色变体,填充场景人群 |

---

## 三、动画资源策略(Mixamo)

### 3.1 为什么用 Mixamo

- **免费可商用**:Mixamo EULA 允许个人/商业/非营利项目无限免费使用,免版税
- **2400+ 动画库**:覆盖所有武侠所需动作
- **Auto-Rigger**:上传静态网格自动绑骨,3 分钟搞定
- **Unity 集成**:.fbx 直接导入,Unity 自动识别 Humanoid Rig

### 3.2 必备动画清单

#### 主角动画
| 状态 | Mixamo 动画名 | 用途 |
|---|---|---|
| Idle | Idle | 站立 |
| Walk | Walk | 走 |
| Run | Run | 跑 |
| Jump | Jump | 跳 |
| Attack_1 | Attack_1 | 三连击第 1 段 |
| Attack_2 | Attack_2 | 三连击第 2 段 |
| Attack_3 | Attack_3 | 三连击第 3 段(终结) |
| Dodge | Dodge | 闪避(无敌帧) |
| Hit | Hit | 受击 |
| Death | Death | 死亡 |

#### Boss 张飞动画
| 状态 | Mixamo 动画名 | 用途 |
|---|---|---|
| Idle | Boss_Idle | 威严站立 |
| Walk | Walk_Large | 缓慢沉重 |
| Attack_Slash | Slash | 横扫丈八蛇矛 |
| Attack_Thrust | Thrust | 突刺 |
| Hit | Boss_Hit | 受击 |
| Death | Boss_Death | 倒地 |

#### 小怪动画
| 状态 | Mixamo 动画名 | 用途 |
|---|---|---|
| Idle | Idle | 巡逻站立 |
| Walk | Walk | 巡逻走 |
| Attack | Attack | 戟横扫 |
| Hurt | Hit | 受击 |
| Death | Death | 死亡 |

### 3.3 Mixamo 访问注意

- **中国大陆 IP 不可直接访问**,需用代理
- Adobe ID 免费注册即可使用
- 下载格式选 `.fbx`(without skin) 用于 Unity Humanoid

---

## 四、许可证与署名清单

发布游戏时需在 credits 里列出以下作者:

| 资源 | 作者 | 许可证 | 署名要求 |
|---|---|---|---|
| Lanhwa(主角) | SEKAYJI | CC-BY | 是 |
| 张飞(Boss) | 觀山閱海 Gwen&Rein | CC-BY | 是 |
| Jin Dynasty 武士(小怪) | Mariusz Waclawek | CC-BY | 是 |
| Chinese Merchant(NPC) | Nisa Nurul Azizah | CC-BY | 是 |
| Mixamo 动画 | Adobe | Mixamo EULA | 否 |
| GanzSe Modular(Asset) | GanzSe | Unity Standard EULA | 否 |

### CC-BY 署名模板
```
本游戏使用了以下 Sketchfab 作者的模型资源(按 CC-BY 协议授权):
- Lanhwa by SEKAYJI (https://sketchfab.com/SEKAYJI)
- 張飛 Zhang Fei by 觀山閱海 Gwen&Rein (https://sketchfab.com/apishkaede)
- Chinese Warrior - Jin Dynasty by Mariusz Waclawek
- Low Poly Chinese Merchant Characters NPC by Nisa Nurul Azizah

动画资源来自 Adobe Mixamo(https://www.mixamo.com)。
```

---

## 五、燕云风格强化方案

### 5.1 色调定位:"青冥"

- **色相**:H 160-180°(石青/花青/墨绿之间)
- **明度**:L 20-35(低)
- **饱和度**:S 10-20(极低)

### 5.2 后期处理(Unity URP Volume)

```
Bloom:        intensity 0.3, threshold 0.9(克制)
Color Filter: 青绿偏移(H+10, S-15, L-5)
Color Curves: 压暗暗部,提亮角色受光面
Depth of Field: 远景虚化(焦距 8m,范围 4m)
Vignette:     intensity 0.4(画面四周微暗,聚焦中心)
Film Grain:    intensity 0.15(模拟胶片质感)
Chromatic Aberration: 极弱 0.05
```

### 5.3 体积雾设置

```
Fog Color:    H 170, S 15, L 25(青墨雾)
Fog Density:  指数 0.015(克制,不喧宾夺主)
Fog Distance: 30m 开始,80m 完全雾化
```

### 5.4 材质策略(做旧美学)

| 材质 | 处理 | 着色器 |
|---|---|---|
| 金属盔甲 | 氧化层暗沉,无强烈反射 | URP Lit + Metallic 0.3, Smoothness 0.4 |
| 布料服装 | 微皱磨损,无丝绸光泽 | URP Simple Lit + 微噪点 |
| 皮肤 | 次表面散射,非过度磨皮 | URP Lit + SSS approximation |
| 石材 | 苔藓风化痕迹 | URP Lit + Detail Map |
| 木材 | 翘曲开裂 | URP Lit + 微噪点 |

---

## 六、Boss 气场强化方案(张飞专属)

用户特别要求"气场做足",具体方案:

### 6.1 体型对比

- 张飞身高 = 主角身高 × 1.8
- 张飞肩宽 = 主角肩宽 × 2.2
- 张飞武器(丈八蛇矛)= 主角身高 × 1.5

### 6.2 视觉气场

- **暗色处理**:黑袍为主,暗金属盔甲,与场景青墨色调融合
- **能量光效**:身上有暗红色裂纹光(怒气值越高越亮)
- **粒子效果**:周身常驻黑色雾气粒子,出场时浓密,战斗中稀疏
- **眼部**:双眸用红色自发光(Emission)材质

### 6.3 出场仪式

1. 雾中走出:从远处体积雾中逐渐显现轮廓
2. 黑雾粒子:出场时密集,2 秒内散开
3. 丈八蛇矛拖地:产生火花拖尾
4. BGM 切换:出场时切换为低频鼓点 + 古琴紧张音
5. 屏幕震动:出场瞬间 0.5 秒屏幕震动

### 6.4 战斗气场

- 攻击拖尾:暗红色粒子拖尾(非白色常规)
- 受击反馈:怒气值 +5,裂纹光亮度提升
- 怒气满(75%):进入"狂暴模式",体型放大 1.2 倍,攻击速度 +30%
- 死亡:缓慢倒地,黑雾散尽,BGM 渐弱

---

## 七、工作流(从下载到 Unity)

### 7.1 模型处理流程

```
Sketchfab 下载(.glb/.fbx)
    ↓
Blender 减面(Decimate modifier)
    ↓
Blender 重拓扑(关键变形区域)
    ↓
Mixamo Auto-Rigger 自动绑骨
    ↓
Mixamo 套用动画(下载 .fbx with skin)
    ↓
Unity 导入(FBX, Humanoid Rig)
    ↓
Unity Shader Graph 调青墨色
    ↓
Unity Animator Controller 组合动画
    ↓
场景放置 + Collider + 脚本
```

### 7.2 Unity 6 LTS 项目结构

```
dingfengbo/
├── Assets/
│   ├── Models/          # .fbx 模型文件
│   ├── Animations/      # Mixamo 动画 .fbx
│   ├── Materials/       # 燕云青墨材质
│   ├── Textures/        # 贴图
│   ├── Shaders/         # 自定义 Shader Graph
│   ├── Prefabs/         # 角色/敌人/NPC 预制体
│   ├── Scenes/          # Main.unity 等场景
│   ├── Scripts/         # C# 脚本
│   │   ├── Player/
│   │   ├── Enemy/
│   │   ├── Boss/
│   │   ├── UI/
│   │   └── Camera/
│   └── Settings/        # URP 渲染设置
├── Packages/
├── ProjectSettings/
│   └── Android 设备:横屏锁定,Gradle 构建
└── .github/workflows/   # Unity CI 构建 APK
```

### 7.3 Android 构建配置

- **Player Settings**:
  - Default Orientation: Landscape Left(强制横屏)
  - Orientation: Landscape
  - Scripting Backend: IL2CPP
  - Target Architectures: ARM64
  - Minimum API Level: Android 8.0 (API 26)
  - Install Location: Automatic
- **Gradle 模式**:用 Gradle 自定义构建,可在 AndroidManifest 写死 screenOrientation=landscape,绕过 ROM 兼容问题

---

## 八、风险与待办

### 8.1 已知风险

| 风险 | 影响 | 缓解方案 |
|---|---|---|
| Lanhwa 1.1M 面减面后拓扑可能崩 | 主角模型质量下降 | 用 Instant Meshes 重拓扑,而非纯 Decimate |
| 张飞原是胸像,需补全身 | 工作量大 | 可考虑用 Mixamo Brute 角色套张飞头雕 |
| Mixamo 中国大陆访问受限 | 动画无法下载 | 用代理访问,提前下载缓存 |
| CC-BY 模型商业发布需署名 | 法律风险 | 在游戏内 credits 页面署名 |

### 8.2 待办优先级

**第 1 阶段(最小可玩原型)**:
- [ ] Unity 6 项目初始化(URP,Android 横屏)
- [ ] 一个竹林场景(程序化生成,燕云青墨色调)
- [ ] 主角 Lanhwa 减面 + 绑骨 + 控制脚本(走/跑/跳/击/避)
- [ ] HUD:虚拟摇杆 + 攻击/闪避按钮(横屏坐标正确)
- [ ] 1-2 个晋朝小怪 + 简单 AI
- [ ] Android 构建配置(Gradle 模式,强制横屏)
- [ ] CI:GitHub Actions 自动构建 APK

**第 2 阶段(燕云风格强化)**:
- [ ] 体积雾、大气透视、做旧材质
- [ ] 完整战斗系统(三连击、闪避无敌帧)
- [ ] 张飞 Boss 完整建模(头雕 + 补全身 + 丈八蛇矛)
- [ ] 张飞气场特效(暗红裂纹、黑雾粒子、出场动画)
- [ ] NPC 对话系统
- [ ] 商人 NPC 集市场景

**第 3 阶段(内容扩展)**:
- [ ] 多场景切换(竹林 → 集市 → Boss 房)
- [ ] 剧情过场
- [ ] 存档系统
- [ ] 设置菜单(画质/音效)

---

## 九、原 Godot 项目存档

原 Godot 项目代码保留在仓库 `archive/godot-old/` 目录下作为参考(代码逻辑可移植,渲染配置不可移植)。具体:

- `scripts/Player.gd` - 玩家状态机逻辑,可移植到 C# 的 `PlayerController.cs`
- `scripts/Enemy.gd` - 敌人 AI 逻辑,可移植到 `EnemyAI.cs`
- `scripts/HUD.gd` - HUD 坐标计算逻辑(注意:viewport 计算方式 Unity 不同,需改用 Screen.width/height)
- `scripts/CombatDirector.gd` - 战斗调度逻辑,可移植
- `shaders/ink_character.gdshader` - 水墨描边着色器,需用 Unity Shader Graph 重写

---

## 十、参考资料

- 燕云十六声实机视频(用户提供):用于视觉风格对标
- Sketchfab Chinese Warriors tag:https://sketchfab.com/tags/chinese_warriors
- Sketchfab Three Kingdoms tag:https://sketchfab.com/tags/three-kingdoms
- Mixamo 官网:https://www.mixamo.com
- Unity 6 LTS 文档:https://docs.unity3d.com/6000.0/Documentation/Manual/

---

**报告作者**:Trae Code Assistant
**报告日期**:2026-10-02
**报告版本**:v1.0
