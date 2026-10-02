extends Node3D
## 《定风波》竹林生成 —— 燕云式「高密度 + 三层纵深」
## 关键：不是随机撒点，而是分层 ——
##   近景（玩家可穿行，有碰撞） / 中景（密，构成视觉墙） / 远景（稀+大，被雾吃掉）
## 用 MultiMeshInstance3D 保证手机上万个竹节仍是一个 draw call

@export_group("规模")
@export var near_count: int = 110
@export var mid_count: int = 380
@export var far_count: int = 620

@export_group("布局")
@export var near_radius: float = 26.0
@export var mid_radius_min: float = 24.0
@export var mid_radius_max: float = 58.0
@export var far_radius_min: float = 54.0
@export var far_radius_max: float = 130.0
@export var clear_radius: float = 7.5

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
	_place_layer("near", near_count, near_radius * 0.32, near_radius, true)
	_place_layer("mid", mid_count, mid_radius_min, mid_radius_max, false)
	_place_layer("far", far_count, far_radius_min, far_radius_max, false)

	var leaf_total := _leaf_xforms.size()

	# 竹叶：全部合并成一次绘制（否则每片叶子一个 draw call，手机上必崩）
	if merge_leaves and leaf_total > 0:
		_commit_leaf_multimesh()

	var dt := Time.get_ticks_msec() - t0
	print("[竹林] 构建完成 | 竹竿实例:%d | 叶片实例:%d | 耗时:%dms" % [
		near_count + mid_count + far_count, leaf_total, dt])

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

func _place_layer(layer: String, count: int, r_min: float, r_max: float, collide: bool) -> void:
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
		var pos := _scatter(r_min, r_max)
		var h := _rng.randf_range(height_min, height_max)
		# 远景竹子更高更细，制造"看不到顶"的压迫感
		if layer == "far":
			h *= 1.22
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

func _scatter(r_min: float, r_max: float) -> Vector3:
	# 环形撒点，保证中心留白（玩家活动区不被竹根塞住）
	for attempt in 24:
		var a := _rng.randf_range(0.0, TAU)
		var r := sqrt(_rng.randf_range(r_min * r_min, r_max * r_max))
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		if p.length() > clear_radius:
			return p
	return Vector3(r_max, 0.0, 0.0)

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
