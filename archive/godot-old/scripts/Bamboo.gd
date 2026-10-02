extends Node3D
## 《定风波》竹林生成 —— 横版「水墨长卷」式布局
##
## 横版改造后的空间语言（Z 轴即画卷纵深）：
##   z ∈ [-3.2, +3.2]   走道（玩家与敌人的横版战场，全程留空）
##   z ∈ [-16, -5.5]    背景密林（构成画面主体，无碰撞）
##   z ∈ [-42, -16]     远林（被雾吃掉大半，只留轮廓）
##   z ∈ [+3.6, +5.6]   走道近侧零星竹（有碰撞，触手可及增加层次）
##   z ∈ [+6.5, +9.0]   前景修竹（更稀更高，从镜头前掠过 —— 长卷的"近景压角"）
## 相机固定在 z ≈ +9.5 的外侧（见 Camera.gd），前景竹故意放稀就是给镜头让路。

@export_group("规模")
@export var side_near_count: int = 90   # 走道近侧（有碰撞）
@export var bg_mid_count: int = 420     # 背景密林
@export var far_count: int = 560        # 远林
@export var fg_front_count: int = 22    # 前景修竹

@export_group("布局")
@export var lane_half: float = 3.2      # 走道半宽
@export var x_extent: float = 140.0     # 横向铺开范围（±m）
@export var side_near_z: Vector2 = Vector2(3.6, 5.6)
@export var bg_mid_z: Vector2 = Vector2(-16.0, -5.5)
@export var far_z: Vector2 = Vector2(-42.0, -16.0)
@export var fg_front_z: Vector2 = Vector2(6.5, 9.0)

@export_group("造型")
@export var height_min: float = 7.0
@export var height_max: float = 13.5
@export var seg_height: float = 0.92
@export var seg_radius: float = 0.115
@export var lean_max: float = 0.09
@export var seed_val: int = 20261002
@export var merge_leaves: bool = true   # 竹叶合并成 MultiMesh（手机上必须开）

var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}
var _colliders: Array[StaticBody3D] = []
var _leaf_mesh: PlaneMesh
var _leaf_xforms: Array[Transform3D] = []

func _ready() -> void:
	_rng.seed = seed_val
	_build_materials()
	_leaf_mesh = _mk_leaf_mesh()

	var t0 := Time.get_ticks_msec()
	_place_layer("side_near", side_near_count, side_near_z, true, 1.0)
	_place_layer("bg_mid", bg_mid_count, bg_mid_z, false, 1.0)
	_place_layer("far", far_count, far_z, false, 1.22)
	_place_layer("fg_front", fg_front_count, fg_front_z, false, 1.18)

	var leaf_total := _leaf_xforms.size()

	# 竹叶：全部合并成一次绘制（否则每片叶子一个 draw call，手机上必崩）
	if merge_leaves and leaf_total > 0:
		_commit_leaf_multimesh()

	var dt := Time.get_ticks_msec() - t0
	print("[竹林] 横卷构建完成 | 竹竿实例:%d | 叶片实例:%d | 耗时:%dms" % [
		side_near_count + bg_mid_count + far_count + fg_front_count, leaf_total, dt])

func _mk_leaf_mesh() -> PlaneMesh:
	var lm := PlaneMesh.new()
	lm.size = Vector2(1.35, 0.42)
	lm.orientation = PlaneMesh.FACE_Y
	lm.material = _mats["leaf"]
	return lm

## 把收集到的叶片变换一次性提交给 MultiMesh
func _commit_leaf_multimesh() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _leaf_mesh
	mm.instance_count = _leaf_xforms.size()
	for i in _leaf_xforms.size():
		mm.set_instance_transform(i, _leaf_xforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Leaves_MultiMesh"
	mmi.multimesh = mm
	# 叶片不投影：数量太大，投影开销不值
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_leaf_xforms.clear()

func _build_materials() -> void:
	var stalk := StandardMaterial3D.new()
	stalk.albedo_color = Color(0.373, 0.443, 0.318)
	stalk.roughness = 0.85
	stalk.metallic_specular = 0.18
	_mats["stalk"] = stalk

	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.267, 0.376, 0.243)
	leaf.roughness = 0.9
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 叶片双面 + 轻微透光，逆光时才有"透"的感觉
	leaf.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_mats["leaf"] = leaf

## 高度倍率 height_mul：远林/前景竹更高，走道旁竹稍矮 —— 层次感
func _place_layer(layer: String, count: int, z_range: Vector2, collide: bool, height_mul: float) -> void:
	if count <= 0:
		return

	var stalk_mesh := CylinderMesh.new()
	stalk_mesh.top_radius = seg_radius * 0.82
	stalk_mesh.bottom_radius = seg_radius
	stalk_mesh.height = seg_height
	stalk_mesh.radial_segments = 6
	stalk_mesh.rings = 1
	stalk_mesh.material = _mats["stalk"]

	# 收集本层所有竹节的变换 —— 不建任何中间节点
	var xforms: Array[Transform3D] = []

	for i in count:
		var pos := _scatter_rect(x_extent, z_range)
		var h := _rng.randf_range(height_min, height_max) * height_mul
		var tilt := Vector3(
			_rng.randf_range(-lean_max, lean_max),
			_rng.randf_range(0.0, TAU),
			_rng.randf_range(-lean_max, lean_max)
		)

		var base := Transform3D(Basis.from_euler(tilt), pos)

		# 竹节：垂直叠放，越往上越细（竹子的自然锥度）
		var segs := int(h / seg_height)
		var y := 0.0
		for s in segs:
			var t := float(s) / maxf(1.0, float(segs - 1))
			var taper := lerpf(1.0, 0.62, t)
			var local := Transform3D(Basis.IDENTITY.scaled(Vector3(taper, 1.0, taper)), Vector3(0.0, y, 0.0))
			xforms.append(base * local)
			y += seg_height

		# 顶部竹叶簇（同样只收集变换）
		_collect_leaves(base, y, h)

		if collide:
			_add_collider(pos, h)

	# 一次性提交本层竹竿
	_commit_stalk_multimesh(layer, stalk_mesh, xforms)

func _commit_stalk_multimesh(layer: String, mesh: CylinderMesh, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Stalks_" + layer
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)

## 竹叶分布：这是"像不像竹子"的关键
##
## v1：叶子全挤在顶端 → 看着像椰子树/松树
## v2：真实的竹子是「叶簇沿竹竿中上部散开，向外下垂」，形成透光的帘幕
##     所以叶簇要：① 从顶部往下铺满 45% 的高度 ② 向四周外扩得远 ③ 带下垂角
func _collect_leaves(base: Transform3D, top_y: float, h: float) -> void:
	# 叶区：从顶端往下 45% 的竿身都长叶子
	var leaf_zone := h * 0.45
	var clusters := _rng.randi_range(8, 14)
	for c in clusters:
		# 沿竿身随机取一个高度落点
		var along := _rng.randf_range(0.0, 1.0)
		# 越靠顶端叶子越密（用平方分布让叶簇集中在上部但不全堆顶）
		along = along * along
		var cy := top_y - along * leaf_zone

		# 叶簇向外伸展：离竿越远越好，竹叶是"甩"出去的
		var ang := _rng.randf_range(0.0, TAU)
		var spread := _rng.randf_range(0.45, 2.15)
		var cp := Vector3(cos(ang) * spread, cy, sin(ang) * spread)

		# 叶簇整体朝向：向外 + 向下垂
		var droop := _rng.randf_range(0.55, 1.15)   # 下垂角，竹叶的灵魂
		var tilt_axis := Vector3(-sin(ang), 0.0, cos(ang))
		var cluster_basis := Basis(tilt_axis, droop) * Basis(Vector3.UP, ang)
		var cluster_t := base * Transform3D(cluster_basis, cp)

		var blades := _rng.randi_range(6, 11)
		for b in blades:
			var lp := Vector3(
				_rng.randf_range(-0.42, 0.42),
				_rng.randf_range(-0.18, 0.18),
				_rng.randf_range(-0.42, 0.42)
			)
			var lr := Vector3(
				_rng.randf_range(-0.55, 0.55),
				_rng.randf_range(0.0, TAU),
				_rng.randf_range(-0.75, 0.75)
			)
			var s := _rng.randf_range(0.8, 1.5)
			var leaf_basis := Basis.from_euler(lr).scaled(Vector3(s, s, s))
			_leaf_xforms.append(cluster_t * Transform3D(leaf_basis, lp))

## 横卷矩形撒点：X 均匀铺开，Z 在指定带内随机 ——
## 替换旧版"环形撒点"：横版战场是走廊，不是圆形竞技场
func _scatter_rect(x_half: float, z_range: Vector2) -> Vector3:
	return Vector3(
		_rng.randf_range(-x_half, x_half),
		0.0,
		_rng.randf_range(minf(z_range.x, z_range.y), maxf(z_range.x, z_range.y))
	)

func _add_collider(pos: Vector3, h: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = seg_radius * 2.4
	cyl.height = h
	shape.shape = cyl
	shape.position = Vector3(0.0, h * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)
	_colliders.append(body)
