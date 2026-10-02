extends Node3D
## 《定风波》场景总装
## 全部程序化装配 —— 不依赖编辑器手工拖拽，确保任何人 clone 下来直接能跑
## 构建顺序：环境 → 地面 → 山 → 竹林 → 石头 → 玩家 → 摄像机 → 敌人 → HUD → 战斗

@export var spawn_bamboo: bool = true
@export var spawn_enemies: bool = true
@export var enemy_count: int = 3
@export var random_seed: int = 20261002

const PLAYER_CHARACTER_GLB := "res://assets/characters/Rogue_Hooded.glb"
const ENEMY_CHARACTER_GLB := "res://assets/characters/Knight.glb"
const OUTLINE_SHADER := "res://shaders/ink_outline.gdshader"
const CHAR_SHADER := "res://shaders/ink_character.gdshader"

var _rng := RandomNumberGenerator.new()
var _mat_ground: StandardMaterial3D
var _mat_rock: StandardMaterial3D
var _mat_mtn: Array[StandardMaterial3D] = []
var _player: CharacterBody3D
var _camera: Camera3D
var _hud: CanvasLayer
var _env: WorldEnvironment

func _ready() -> void:
	_rng.seed = random_seed
	_env = get_node_or_null("Env")
	if _env:
		_env.add_to_group("world_env")

	_build_materials()
	_build_ground()
	_build_mountains()
	if spawn_bamboo:
		_build_bamboo_field()
	_build_rocks()
	_spawn_player()
	_setup_camera()
	_setup_hud()
	_setup_combat()
	if spawn_enemies:
		_spawn_enemies()

	print("[定风波] 场景构建完成 | 敌人:%d | 竹林:%s" % [enemy_count, str(spawn_bamboo)])

# ---------------- 材质 ----------------
func _build_materials() -> void:
	# 地面：湿土褐，刻意压暗 —— 水墨画的地不是亮黄，是带水气的深褐
	_mat_ground = StandardMaterial3D.new()
	_mat_ground.albedo_color = Color(0.259, 0.235, 0.196)
	_mat_ground.roughness = 0.96
	_mat_ground.metallic_specular = 0.06

	_mat_rock = StandardMaterial3D.new()
	_mat_rock.albedo_color = Color(0.267, 0.278, 0.290)
	_mat_rock.roughness = 0.92

	# 三层山：这是水墨画的「远山」—— 不是灰白，是青墨
	# 关键：山体自身要够暗，雾只负责让它们"变淡"而不是"变白"
	_mat_mtn = [
		_mk_mtn(Color(0.376, 0.427, 0.463)),  # 远景：青灰
		_mk_mtn(Color(0.271, 0.322, 0.365)),  # 中景：深青
		_mk_mtn(Color(0.180, 0.220, 0.259)),  # 近景：墨青
	]

func _mk_mtn(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic_specular = 0.0
	return m

# ---------------- 地面 ----------------
func _build_ground() -> void:
	var size := 420.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = 32
	plane.subdivide_depth = 32
	plane.material = _mat_ground

	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 0.4, size)
	col.shape = box
	col.position = Vector3(0.0, -0.2, 0.0)
	body.add_child(col)
	add_child(body)

	_add_ground_patches(Color(0.557, 0.478, 0.369), 78, 26.0, 92.0, 0.30, 0.015)
	_add_ground_patches(Color(0.416, 0.337, 0.243), 62, 20.0, 76.0, 0.34, 0.025)
	_add_ground_patches(Color(0.784, 0.722, 0.612), 40, 14.0, 52.0, 0.20, 0.035)

func _add_ground_patches(col: Color, n: int, s_min: float, s_max: float, opacity: float, y: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, opacity)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh := PlaneMesh.new()
	mesh.orientation = PlaneMesh.FACE_Y
	mesh.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n

	for i in n:
		var a := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(8.0, 120.0)
		var sz := _rng.randf_range(s_min, s_max)
		var t := Transform3D()
		t.origin = Vector3(cos(a) * r, y, sin(a) * r)
		t = t.rotated(Vector3.UP, _rng.randf_range(0.0, TAU))
		t = t.scaled(Vector3(sz, 1.0, sz))
		mm.set_instance_transform(i, t)

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GroundPatch_%d" % n
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

# ---------------- 三层山 ----------------
func _build_mountains() -> void:
	# 加大了尺寸与数量，并让远景更高 —— 制造"群山连绵、层叠推远"的水墨感
	var layers := [
		{"R": 480.0, "h": 195.0, "n": 22, "mat": _mat_mtn[0], "y": -26.0, "w": 1.45},
		{"R": 355.0, "h": 122.0, "n": 24, "mat": _mat_mtn[1], "y": -14.0, "w": 1.30},
		{"R": 262.0, "h": 72.0, "n": 26, "mat": _mat_mtn[2], "y": -5.0, "w": 1.10},
	]

	var holder := Node3D.new()
	holder.name = "Mountains"
	add_child(holder)

	for li in layers.size():
		var L: Dictionary = layers[li]
		var n: int = L["n"]
		for i in n:
			var a := TAU * float(i) / float(n) + _rng.randf_range(-0.16, 0.16)
			var r: float = float(L["R"]) * _rng.randf_range(0.85, 1.15)
			var h: float = float(L["h"]) * _rng.randf_range(0.5, 1.45)
			var base := Vector3(cos(a) * r, float(L["y"]), sin(a) * r)
			_add_peak(holder, base, h, float(L["h"]), L["mat"], li, float(L["w"]))

func _add_peak(parent: Node3D, base: Vector3, height: float, ref_h: float, mat: Material, layer: int, wide: float) -> void:
	var rad := ref_h * _rng.randf_range(0.5, 0.95) * wide
	var cone := CylinderMesh.new()
	# 极小的顶半径 = 尖锐山尖，这才像水墨皴出的远山，不是雪糕筒
	cone.top_radius = rad * _rng.randf_range(0.004, 0.028)
	cone.bottom_radius = rad
	cone.height = height
	cone.radial_segments = 5      # 低边数 → 出现硬棱角，更像毛笔側锋
	cone.rings = 3
	cone.material = mat

	var mi := MeshInstance3D.new()
	mi.mesh = cone
	mi.position = base + Vector3(0.0, height * 0.5, 0.0)
	mi.rotation.y = _rng.randf_range(0.0, TAU)
	# 山体轻微侧倾 → 群峰错落，不是整齐一圈
	mi.rotation.x = _rng.randf_range(-0.09, 0.09)
	mi.rotation.z = _rng.randf_range(-0.07, 0.07)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

# ---------------- 竹林 ----------------
func _build_bamboo_field() -> void:
	var field := Node3D.new()
	field.name = "BambooField"
	field.set_script(load("res://scripts/Bamboo.gd"))
	add_child(field)

# ---------------- 石头 ----------------
func _build_rocks() -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 1.2
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 3
	rock_mesh.material = _mat_rock

	var n := 46
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock_mesh
	mm.instance_count = n

	for i in n:
		var a := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(9.0, 120.0)
		var s := _rng.randf_range(0.22, 0.85)
		var t := Transform3D()
		t.origin = Vector3(cos(a) * r, s * _rng.randf_range(0.15, 0.42), sin(a) * r)
		t = t.rotated(Vector3.UP, _rng.randf_range(0.0, TAU))
		t = t.scaled(Vector3(s * _rng.randf_range(0.8, 1.5), s * _rng.randf_range(0.5, 0.95), s * _rng.randf_range(0.8, 1.5)))
		mm.set_instance_transform(i, t)

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Rocks"
	mmi.multimesh = mm
	add_child(mmi)

# ---------------- 角色装配（含 glb 导入 + 水墨描边）----------------
func _load_character(glb_path: String, char_name: String) -> Node3D:
	var packed := load(glb_path) as PackedScene
	if packed == null:
		push_error("[定风波] 无法加载角色模型: %s" % glb_path)
		# 兜底：用胶囊体代替，保证游戏仍可运行
		return _fallback_body(char_name)

	var inst := packed.instantiate()
	inst.name = "Model"
	# 清掉 owner，避免后续挂节点时报 inconsistent 警告
	_clear_owner(inst)

	# 应用水墨角色着色器（保留贴图色相 + 硬阶色带 + 边缘光）
	_apply_character_shader(inst)

	# 叠加描边外壳
	_add_outline_shell(inst)

	return inst

func _clear_owner(n: Node) -> void:
	n.owner = null
	for c in n.get_children():
		_clear_owner(c)

func _apply_character_shader(root: Node) -> void:
	var shader := load(CHAR_SHADER)
	if shader == null:
		return
	# 取主光方向注入 shader —— 显式传比依赖内建变量稳
	var sun_dir := Vector3(0.55, 0.62, -0.56).normalized()
	if _env:
		var d: Vector3 = _env.get_sun_direction()
		if d.length_squared() > 0.01:
			sun_dir = d.normalized()

	for child in root.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("sun_dir", sun_dir)
			# 把原贴图接进来，保住人物色相
			var src := mi.get_active_material(0)
			if src is StandardMaterial3D:
				var st := src as StandardMaterial3D
				if st.albedo_texture:
					mat.set_shader_parameter("albedo_tex", st.albedo_texture)
			# 生成五阶渐变图（墨分五色）
			mat.set_shader_parameter("gradient_map", _make_gradient_texture(5))
			mi.set_surface_override_material(0, mat)
			# 角色需要投影，才有燕云那种落地硬阴影
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		else:
			# 只对非网格节点继续下钻（递归放在 else 里，避免网格被重复处理）
			_apply_character_shader(child)

## 生成 N 阶硬色带贴图 —— 水墨「墨分五色」的技术实现
func _make_gradient_texture(steps: int) -> GradientTexture1D:
	var g := Gradient.new()
	var cols: PackedColorArray = []
	var offs: PackedFloat32Array = []
	for i in steps:
		var t := float(i) / float(steps - 1)
		# 从深墨(暗部)到纸白(亮部)，暗部带一点冷青
		var shade := lerpf(0.28, 1.0, t)
		var c := Color(shade * 0.92, shade * 0.95, shade, 1.0)
		cols.append(c)
		offs.append(t)
	g.colors = cols
	g.offsets = offs
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex

## 反向外壳描边：给每个带蒙皮的 MeshInstance3D 原地加一个「兄弟外壳」。
##
## 为什么不用「整棵复制」的老写法：
##   glb 里 mesh 的 skeleton 存的是【相对路径】（如 ".."，即父节点 Skeleton3D）。
##   把网格复制到另一个层级的节点树下，这个相对路径就解析不到了 ——
##   外壳会永远停在 rest pose，与动画后的本体错位，糊成一坨巨大的黑块。
##
## 现在的做法：外壳挂在【与源网格完全相同的父节点】下，作为兄弟节点。
## 相对路径不变 → skeleton 解析正常 → 描边严丝合缝跟着动画走。
func _add_outline_shell(root: Node) -> void:
	var shader := load(OUTLINE_SHADER)
	if shader == null:
		return
	_wrap_meshes(root, shader)

func _wrap_meshes(n: Node, shader: Shader) -> void:
	for child in n.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var sm := MeshInstance3D.new()
			sm.name = mi.name + "_Outline"
			sm.mesh = mi.mesh
			sm.transform = mi.transform
			# 关键：skeleton 是相对路径，必须保持在同一父节点下才能解析
			sm.skeleton = mi.skeleton
			sm.skin = mi.skin
			sm.material_override = _outline_material(shader)
			sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# 插到源网格后面，作为兄弟
			n.add_child(sm)
			if n is Node3D:
				sm.owner = null
		else:
			_wrap_meshes(child, shader)

func _outline_material(shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	# 角色 glb 在导入期被 root_scale 放大了，外壳继承同一缩放，
	# 于是 shader 里的 outline_width 也会被等比放大，描边会糊成一圈黑。
	# 这里按缩放倒数补偿，让屏幕上看到的线宽保持稳定。
	mat.set_shader_parameter("outline_width", 0.011 / 1.49)
	return mat

func _fallback_body(char_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var cap := CapsuleMesh.new()
	cap.radius = 0.34
	cap.height = 1.72
	cap.material = _mat_rock
	var mi := MeshInstance3D.new()
	mi.mesh = cap
	mi.position = Vector3(0.0, 0.86, 0.0)
	root.add_child(mi)
	push_warning("[定风波] %s 使用兜底胶囊体" % char_name)
	return root

func _find_anim_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for c in root.get_children():
		var r := _find_anim_player(c)
		if r:
			return r
	return null

## ⚠️ 角色缩放不要在这里做！
## 直接给 SkinnedMesh 的父节点设 scale，会破坏骨骼蒙皮绑定 ——
## 表现为"头大身子小"的畸形（已实测复现）。
## 正确做法：改 glb 的【导入设置】nodes/root_scale，让 Godot 在导入期
## 一次性缩放骨架+网格，蒙皮完全不受影响。
## 本工程的 Rogue_Hooded.glb / Knight.glb 都已在 .import 里设为 1.49。
const CHARACTER_SCALE := 1.0

func _build_body(glb: String, char_name: String, col_radius: float, col_height: float, col_y: float) -> Node:
	var body := CharacterBody3D.new()
	body.name = char_name

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = col_radius
	cap.height = col_height
	col.shape = cap
	col.position = Vector3(0.0, col_y, 0.0)
	body.add_child(col)

	var holder := Node3D.new()
	holder.name = "ModelRoot"
	body.add_child(holder)
	holder.add_child(_load_character(glb, char_name))

	return body

# ---------------- 玩家 ----------------
func _spawn_player() -> void:
	var body := _build_body(PLAYER_CHARACTER_GLB, "Player", 0.34, 1.72, 0.86)
	body.set_script(load("res://scripts/Player.gd"))

	# ⚠️ 绝对不要搬动 glb 里自带的 AnimationPlayer！
	# 动画轨道的路径（如 "Rig/Skeleton3D:root"）是【相对于 AnimationPlayer 自身】写的。
	# 一旦把它挪到别的父节点下，所有骨骼轨道都会解析失败 →
	# 骨骼被归零 → 角色塌缩成一坨方块（就是之前"主角变绿色方块"的真凶）。
	# 正确做法：保持 glb 原始结构不动，让 Player.gd 自己递归找到动画机。
	var mr := body.get_node("ModelRoot")
	if _find_anim_player(mr) == null:
		push_warning("[定风波] Player 模型里没有 AnimationPlayer，将只能静态站立")

	body.position = Vector3(0.0, 0.1, 0.0)
	add_child(body)
	_player = body as CharacterBody3D

## ⚠️⚠️ 血的教训：绝不要对【已经在场景树里】的节点调用 set_script()。
##
## Godot 的 _ready() 只在节点「进入场景树」的那一次触发。
## Main.tscn 里预置的 Camera / HUD / CombatDirector 在场景加载时就跑完了 _ready()（那时还没脚本），
## 之后 World.gd 再 set_script() 换上脚本 —— Godot 不会为它重新触发 _ready()。
## 后果（实测确认）：
##   · HUD.gd   的 _ready() 没跑 → 摇杆/按钮【从未被创建】→ 手机上完全动不了
##   · Camera.gd 的 _ready() 没跑 → fov 停在默认 75、near 0.05、far 4000 → 视野过广、人显小
##   · CombatDirector.gd 的 _ready() 没跑 → 攻击信号没接上 → 打不中敌人
##
## 正确做法：脚本直接写在 Main.tscn 里，节点加载时自带脚本，_ready() 自然触发。
## 下方各 _setup_* 只负责「注入依赖」，不再负责「挂脚本」。

func _setup_camera() -> void:
	_camera = get_node_or_null("Camera") as Camera3D
	if _camera == null:
		push_error("[定风波] 场景里找不到 Camera 节点")
		return
	if _camera.get_script() == null:
		# 兜底：真丢了脚本才补挂，并等一帧让 _ready() 有机会执行
		_camera.set_script(load("res://scripts/Camera.gd"))
		await get_tree().process_frame
	# 显式注入跟随目标。Camera.gd 自己的 _ready() 里也会尝试解析，
	# 但那时玩家可能还没 add_child，所以这里必须再调一次 setup()。
	if _camera.has_method("setup"):
		_camera.call("setup", _player)
	else:
		push_error("[定风波] Camera.gd 缺少 setup() 方法，相机将无法跟随")

func _setup_hud() -> void:
	_hud = get_node_or_null("HUD") as CanvasLayer
	if _hud == null:
		push_error("[定风波] 场景里找不到 HUD 节点")
		return
	if _hud.get_script() == null:
		_hud.set_script(load("res://scripts/HUD.gd"))
		await get_tree().process_frame
	# HUD 的摇杆/按钮在 _ready() 里创建；万一没跑（老场景文件），手动补建一次
	if _hud.has_method("ensure_built"):
		_hud.call("ensure_built")

func _setup_combat() -> void:
	var cd := get_node_or_null("CombatDirector")
	if cd == null:
		push_error("[定风波] 场景里找不到 CombatDirector 节点")
		return
	if cd.get_script() == null:
		cd.set_script(load("res://scripts/CombatDirector.gd"))
		await get_tree().process_frame
	if cd.has_method("ensure_bound"):
		cd.call("ensure_bound")

# ---------------- 敌人 ----------------
func _spawn_enemies() -> void:
	var holder := Node3D.new()
	holder.name = "Enemies"
	add_child(holder)

	for i in enemy_count:
		var body := _build_body(ENEMY_CHARACTER_GLB, "Enemy_%d" % (i + 1), 0.36, 1.8, 0.9)
		body.set_script(load("res://scripts/Enemy.gd"))
		# 同 Player：不搬 AnimationPlayer，保持 glb 原始层级，
		# 否则动画轨道 "Rig/Skeleton3D:xxx" 解析不到，敌人也会塌缩成方块。
		var mr := body.get_node("ModelRoot")
		if _find_anim_player(mr) == null:
			push_warning("[定风波] Enemy_%d 模型里没有 AnimationPlayer" % (i + 1))

		# 出生角度均匀分布；并且刻意避开玩家正后方 ±55°，
		# 否则开局第一个敌人会正好卡在相机与玩家之间，糊住整个屏幕。
		var a := TAU * float(i) / float(enemy_count) + _rng.randf_range(-0.3, 0.3)
		var rear_angle := PI  # 玩家初始朝向是 -Z，正后方即 +Z 方向（角度 π）
		var diff := absf(angle_difference(a, rear_angle))
		if diff < deg_to_rad(55.0):
			a += deg_to_rad(110.0)
		var r := _rng.randf_range(13.0, 19.0)
		body.position = Vector3(cos(a) * r, 0.1, sin(a) * r)
		holder.add_child(body)
