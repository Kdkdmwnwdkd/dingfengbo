extends Camera3D
## 《定风波》第三人称摄像机
## 燕云式：低机位、微微越肩、跟随滞后、受击轻微抖屏
## 并持续把焦点喂给景深 —— 保证主角永远实、背景永远虚

@export_group("跟随")
@export var target_path: NodePath
@export var follow_lag: float = 7.5
@export var look_lag: float = 9.5
## 越肩机位。主角身高 1.755m，机位高度取 ~1.62m（胸口偏上），
## 距离 3.9m —— 实测角色占屏高约 42%，是当下主流手游第三人称动作游戏的手感。
@export var offset: Vector3 = Vector3(0.5, 1.62, -3.9)
## 视线落点高度：瞄准角色胸口，而不是脚下，否则会俯视、显得人更小
@export var look_height: float = 1.15

@export_group("动态")
@export var shake_decay: float = 7.0
@export var dof_track: bool = true
@export var dof_bias: float = 6.0

@export_group("防穿模")
## 开启后，相机与玩家之间出现遮挡物时自动把机位拉近（竹林场景必开）
@export var collision_avoid: bool = true
## 检测哪一层：1=世界静态物(竹竿/石头/地形)，2=角色
@export var collision_mask_avoid: int = 1 | 2
## 机位到碰撞点之间保留的余量，防止贴面闪烁
@export var collision_margin: float = 0.28
## 无论如何不贴到玩家脸上的最近距离
@export var min_distance: float = 1.15

@export_group("景深（燕云式背景虚化）")
@export var dof_enabled: bool = true
@export var dof_far_distance: float = 15.0
@export var dof_far_transition: float = 21.0
@export var dof_amount: float = 0.078
@export var dof_near_enabled: bool = false

var target: Node3D
var _shake: float = 0.0
var _smooth_pos: Vector3
var _look_at: Vector3
var _env: WorldEnvironment
## 55° 是第三人称动作游戏的常用取值。
## 注意：Godot 的 Camera3D 默认 fov 是 75°，那是个广角，会把主角压得很小。
## 所以 _ready() 里必须显式赋值 —— 而 _ready() 只有在「节点进树时脚本已挂好」才会跑，
## 这正是在 Main.tscn 里直接挂 Camera.gd 的原因。
var _fov_base: float = 55.0
var _attrs: CameraAttributesPractical

func _ready() -> void:
	_apply_base_settings()
	_setup_attributes()
	_env = get_tree().get_first_node_in_group("world_env")
	# 优先用 setup() 显式注入的 target；其次才回退到 @export 的 target_path
	if target == null:
		_resolve_target()
	else:
		_snap_to_target()

## 基础参数一次性写死。抽成独立函数是为了让 World.gd 也能在必要时兜底调用，
## 防止 _ready() 因时序问题没跑时 fov 卡在默认 75。
func _apply_base_settings() -> void:
	fov = _fov_base
	near = 0.08
	far = 620.0

## 由 World.gd 在玩家生成后立刻调用 —— 比依赖 @export 的 target_path 更可靠。
## （动态 set("target_path") 在脚本挂载前是不生效的，那是写给了不存在的属性）
func setup(t: Node3D) -> void:
	# 兜底：_ready() 若因时序没跑到，这里把 fov/near/far 补上
	if not is_equal_approx(fov, _fov_base):
		_apply_base_settings()
	if _attrs == null:
		_setup_attributes()
	target = t
	target_path = get_path_to(t) if t else NodePath()
	_snap_to_target()

func _resolve_target() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path)
	if target:
		_snap_to_target()

## 立刻把相机摆到目标身后，避免开局第一帧从原点猛甩过去
func _snap_to_target() -> void:
	if target == null:
		return
	_smooth_pos = _desired_position()
	_look_at = target.global_position + Vector3.UP * look_height
	global_position = _smooth_pos
	look_at(_look_at, Vector3.UP)

## 景深必须挂在相机属性上 —— Godot 4 把 DOF 从 Environment 移到了 CameraAttributes
func _setup_attributes() -> void:
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = dof_enabled
	_attrs.dof_blur_far_distance = dof_far_distance
	_attrs.dof_blur_far_transition = dof_far_transition
	_attrs.dof_blur_near_enabled = dof_near_enabled
	_attrs.dof_blur_near_distance = 1.0
	_attrs.dof_blur_near_transition = 1.8
	_attrs.dof_blur_amount = dof_amount
	attributes = _attrs

func _desired_position() -> Vector3:
	if target == null:
		return global_position
	# 用目标朝向决定机位方向，转身时机位自然绕到身后
	var basis := target.global_transform.basis
	var local := offset
	var world := target.global_position \
		+ basis.x * local.x \
		+ basis.y * local.y \
		+ basis.z * local.z
	return world

func _process(delta: float) -> void:
	if target == null:
		return

	var want := _desired_position()
	# 防穿模：相机与玩家之间若有遮挡（竹竿、敌人、地形），把机位拉近
	want = _avoid_obstacles(want)
	_smooth_pos = _smooth_pos.lerp(want, 1.0 - exp(-follow_lag * delta))
	global_position = _smooth_pos

	var look_target := target.global_position + Vector3.UP * look_height + target.global_transform.basis.z * 1.2
	_look_at = _look_at.lerp(look_target, 1.0 - exp(-look_lag * delta))

	var final_look := _look_at
	if _shake > 0.001:
		var s := _shake
		final_look += Vector3(
			randf_range(-s, s),
			randf_range(-s, s),
			randf_range(-s, s) * 0.5
		)
		_shake = maxf(0.0, _shake - shake_decay * delta)

	look_at(final_look, Vector3.UP)

	if dof_track and _attrs and dof_enabled:
		var d := global_position.distance_to(target.global_position)
		_attrs.dof_blur_far_distance = maxf(6.0, d + dof_bias)

## 从聚焦点向理想机位打一条射线；撞到东西就把相机拉到碰撞点之前。
## 竹林场景必做 —— 否则相机会频繁插进竹竿里，满屏绿柱子。
func _avoid_obstacles(want: Vector3) -> Vector3:
	if not collision_avoid or target == null:
		return want
	var focus := target.global_position + Vector3.UP * look_height
	var space := get_world_3d().direct_space_state
	if space == null:
		return want
	var from := focus
	var to := want
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collision_mask = collision_mask_avoid
	params.exclude = [target.get_rid()] if target is CollisionObject3D else []
	params.hit_from_inside = false
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return want
	# 命中：把机位收到碰撞点内侧一点，留出 min_distance 兜底
	var hit_pos: Vector3 = hit["position"]
	var dir := (want - focus).normalized()
	var safe := focus + dir * maxf(min_distance, focus.distance_to(hit_pos) - collision_margin)
	return safe

func shake(amount: float) -> void:
	_shake = minf(0.32, _shake + amount)

## 冲刺时轻微拉 FOV，增加速度感（燕云常用手法）
func set_sprint(active: bool) -> void:
	var want := _fov_base + (4.5 if active else 0.0)
	fov = lerp(fov, want, 0.08)
