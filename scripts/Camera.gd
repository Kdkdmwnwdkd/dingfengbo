extends Camera3D
## 《定风波》横版侧视摄像机 —— 水墨长卷式运镜
## 相机固定在场景 +Z 外侧，横向跟随主角；受击抖屏 / 冲刺 FOV 保留
##
## 为什么侧视机位不再需要防穿模射线：
## 竹林已按「走廊式」重排（见 Bamboo.gd），相机所在的 Z > 7 空域全程无遮挡。
## 上一版怼脸 bug 的链路是：敌人近身 → 防穿模射线打中敌人（collision_mask 含角色层）
## → 相机被压到 1.15m 贴身距离 → 满屏后脑勺/正脸。横版机位从布局上消灭了这条链路。

@export_group("跟随")
@export var target_path: NodePath
@export var follow_lag: float = 6.5
@export var look_lag: float = 8.0
## 横版机位：主角 +Z 侧 7.2m、高 1.6m。
## 横屏 720p + fov 55° 下，纵向可视约 7.5m —— 主角（1.8m）占屏高约 24%；
## 横向可视约 13m —— 刚好装下一次三连击的进退距离。
@export var distance: float = 7.2
@export var camera_height: float = 1.6
## 横向前瞻：朝主角面朝方向多看 1.1m，起跑/急停带一点"甩镜头"预告
@export var lead_distance: float = 1.1
## 视线落点高度：胸口，画面重心略低于屏心，头顶留白（水墨立轴的呼吸感）
@export var look_height: float = 1.05
## 垂直跟随强度：0 = 完全锁定水平线；0.35 = 轻微上下跟（跳台/坡道时用）
@export_range(0.0, 1.0) var vertical_follow: float = 0.35

@export_group("动态")
@export var shake_decay: float = 7.0
@export var dof_track: bool = true
@export var dof_bias: float = 4.0

@export_group("景深（水墨长卷的背景虚化）")
@export var dof_enabled: bool = true
@export var dof_far_distance: float = 14.0
@export var dof_far_transition: float = 20.0
@export var dof_amount: float = 0.078
@export var dof_near_enabled: bool = false

var target: Node3D
var _shake: float = 0.0
var _cam_pos: Vector3
var _look_at: Vector3
var _lead: float = 0.0
var _env: WorldEnvironment
## 55° 是横版动作游戏的安全取值：角色不会太小，也不会广角畸变。
## 注意 Godot 默认 fov=75 是广角 —— 那正是"人显小"的元凶，_ready() 必须显式覆盖。
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

## 基础参数一次性写死；World.gd 兜底时也可调用
func _apply_base_settings() -> void:
	fov = _fov_base
	near = 0.08
	far = 620.0

## 由 World.gd 在玩家生成后立刻调用
func setup(t: Node3D) -> void:
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

## 开局先把相机摆到主角侧面，避免第一帧从原点猛甩过去
func _snap_to_target() -> void:
	if target == null:
		return
	_cam_pos = _desired_position()
	_look_at = _desired_look()
	global_position = _cam_pos
	look_at(_look_at, Vector3.UP)

func _desired_position() -> Vector3:
	if target == null:
		return global_position
	var p := target.global_position
	return Vector3(p.x + _lead, camera_height + p.y * vertical_follow, p.z + distance)

func _desired_look() -> Vector3:
	if target == null:
		return _look_at
	var p := target.global_position
	return Vector3(p.x + _lead, look_height + p.y * vertical_follow, p.z)

func _process(delta: float) -> void:
	if target == null:
		return

	# 横向前瞻：从 ModelRoot 的 yaw 里取朝向的 X 分量（面朝 +X 时 yaw=+90°）
	var want_lead := 0.0
	var mr := target.get_node_or_null("ModelRoot") as Node3D
	if mr:
		want_lead = sin(mr.rotation.y) * lead_distance
	_lead = lerpf(_lead, want_lead, 1.0 - exp(-5.0 * delta))

	var want := _desired_position()
	_cam_pos = _cam_pos.lerp(want, 1.0 - exp(-follow_lag * delta))
	global_position = _cam_pos

	_look_at = _look_at.lerp(_desired_look(), 1.0 - exp(-look_lag * delta))

	var final_look := _look_at
	if _shake > 0.001:
		var s := _shake
		final_look += Vector3(
			randf_range(-s, s),
			randf_range(-s, s),
			0.0
		)
		_shake = maxf(0.0, _shake - shake_decay * delta)

	look_at(final_look, Vector3.UP)

	if dof_track and _attrs and dof_enabled:
		var d := global_position.distance_to(target.global_position)
		_attrs.dof_blur_far_distance = maxf(8.0, d + dof_bias)

func shake(amount: float) -> void:
	_shake = minf(0.32, _shake + amount)

## 冲刺时轻微拉 FOV，增加速度感
func set_sprint(active: bool) -> void:
	var want := _fov_base + (4.5 if active else 0.0)
	fov = lerp(fov, want, 0.08)
