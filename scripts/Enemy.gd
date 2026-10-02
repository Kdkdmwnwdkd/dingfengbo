extends CharacterBody3D
## 《定风波》敌人 AI —— 暖褐黑甲 + 正红点缀
## 三态机：游荡 / 追击 / 攻击冷却。保持轻量，手机上一屏 3~6 个不卡

signal died(enemy: Node3D)

@export_group("数值")
@export var max_health: int = 38
@export var contact_damage: int = 6      # 横版下调：8 → 6，走道窄，围殴更致命
@export var move_speed: float = 2.9
@export var chase_speed: float = 4.1
@export var detect_range: float = 22.0
@export var attack_range: float = 2.0    # 2.25 → 2.0，配合横版矩形判定
@export var attack_cooldown: float = 1.9 # 1.35 → 1.9：上一版 14 秒掉 56 血太凶
@export var lane_tolerance: float = 1.2  # 纵深容差：|dz| 超过它就不出刀

@export_group("行为")
@export var wander_radius: float = 7.0

enum State { WANDER, CHASE, COOLDOWN, DEAD }

var health: int
var state: State = State.WANDER
var _cd: float = 0.0
var _wander_target: Vector3
var _wander_timer: float = 0.0
var _player: Node3D
var _flash: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var model_root: Node3D = $ModelRoot
@onready var _body_mesh: Node3D = $ModelRoot
## 同 Player：递归查找动画机，不写死路径，保持 glb 原始层级
@onready var anim: AnimationPlayer = _find_anim_player(model_root)

func _find_anim_player(n: Node) -> AnimationPlayer:
	if n == null:
		return null
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r != null:
			return r
	return null

const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walking_A"
const ANIM_RUN := "Running_A"
const ANIM_ATTACK := "1H_Melee_Attack_Chop"
const ANIM_HIT := "Hit_A"
const ANIM_DEATH := "Death_A"

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	_rng.seed = int(global_position.x * 1000.0) ^ int(global_position.z * 977.0) ^ 20261002
	_wander_target = global_position
	_player = get_tree().get_first_node_in_group("player")
	if anim and anim.has_animation(ANIM_IDLE):
		anim.play(ANIM_IDLE)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_apply_gravity(delta)
		move_and_slide()
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	if _cd > 0.0:
		_cd -= delta

	_tick_flash(delta)

	match state:
		State.WANDER: _do_wander(delta)
		State.CHASE: _do_chase(delta)
		State.COOLDOWN: _do_cooldown(delta)

	_face_move_dir(delta)
	_apply_gravity(delta)
	move_and_slide()

func _do_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = _rng.randf_range(2.4, 5.0)
		# 横版游荡：沿 X 轴晃悠，纵深锁在走道内（|z| ≤ 2.6）
		var a := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(2.0, wander_radius)
		var tz := clampf(global_position.z + sin(a) * r, -2.6, 2.6)
		_wander_target = Vector3(global_position.x + cos(a) * r, 0.0, tz)

	var to := _wander_target - global_position
	to.y = 0.0
	if to.length() > 0.6:
		var d := to.normalized()
		velocity.x = move_toward(velocity.x, d.x * move_speed, 9.0 * delta)
		velocity.z = move_toward(velocity.z, d.z * move_speed, 9.0 * delta)
		_play(ANIM_WALK)
	else:
		_slow_down(delta)
		_play(ANIM_IDLE)

	if _dx_to_player() < detect_range:
		state = State.CHASE

## 横版距离 = 横向 |dx|（纵深不再参与索敌）
func _dx_to_player() -> float:
	if _player == null:
		return 9999.0
	return absf(_player.global_position.x - global_position.x)

func _do_chase(delta: float) -> void:
	if _player == null:
		state = State.WANDER
		return

	var pp := _player.global_position
	var to := pp - global_position
	var dx := absf(to.x)
	var adz := absf(to.z)
	if dx > detect_range * 1.2:
		state = State.WANDER
		return

	# 横版出刀条件：横向够近 且 纵深对齐（错位太远时先贴线再出刀）
	if dx <= attack_range and adz <= lane_tolerance and _cd <= 0.0:
		_do_attack()
		return

	# X 轴接近为主；Z 轴向玩家所在纵深收敛（最多 ±1.4，避免人群叠成一列）
	var sx := signf(to.x) if dx > 0.05 else 0.0
	var sz := clampf(to.z, -1.4, 1.4)
	var spd := chase_speed if dx > 5.0 else move_speed * 1.1
	velocity.x = move_toward(velocity.x, sx * spd, 11.0 * delta)
	velocity.z = move_toward(velocity.z, sz * minf(spd, 2.4), 8.0 * delta)
	_play(ANIM_RUN if dx > 5.0 else ANIM_WALK)

func _do_cooldown(delta: float) -> void:
	_slow_down(delta)
	if _cd <= 0.0:
		state = State.CHASE

func _do_attack() -> void:
	state = State.COOLDOWN
	_cd = attack_cooldown
	velocity.x = 0.0
	velocity.z = 0.0
	if anim and anim.has_animation(ANIM_ATTACK):
		anim.play(ANIM_ATTACK, 0.06)
	# 命中判定：延迟到挥砍中段，给玩家闪避窗口 —— 横版矩形判定
	await get_tree().create_timer(0.28).timeout
	if state == State.DEAD or _player == null or not is_instance_valid(_player):
		return
	var to := _player.global_position - global_position
	if absf(to.x) <= attack_range * 1.35 and absf(to.z) <= lane_tolerance + 0.3:
		if _player.has_method("take_damage"):
			_player.take_damage(contact_damage, global_position)
		var cam := get_viewport().get_camera_3d()
		if cam and cam.has_method("shake"):
			cam.shake(0.09)

func _slow_down(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)

func _face_move_dir(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() < 0.05:
		return
	var want := atan2(flat.x, flat.z)
	model_root.rotation.y = lerp_angle(model_root.rotation.y, want, 9.0 * delta)

func _play(a: String) -> void:
	if anim == null:
		return
	if anim.current_animation == a:
		return
	if anim.has_animation(a):
		anim.play(a, 0.16)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0

func _tick_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta * 3.2
	if _flash <= 0.0:
		_flash = 0.0
	_set_flash(_flash)

func _set_flash(v: float) -> void:
	var root := get_node_or_null("ModelRoot")
	if root == null:
		return
	for c in root.get_children():
		if c is MeshInstance3D:
			var mat := (c as MeshInstance3D).get_active_material(0)
			if mat is StandardMaterial3D:
				var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.emission_enabled = v > 0.01
				m.emission = Color(0.85, 0.16, 0.13)
				m.emission_energy_multiplier = v * 2.4
				(c as MeshInstance3D).set_surface_override_material(0, m)

func take_damage(amount: int, from: Vector3) -> void:
	if state == State.DEAD:
		return
	health -= amount
	_flash = 1.0
	var knock := (global_position - from)
	knock.y = 0.0
	if knock.length_squared() > 0.001:
		knock = knock.normalized() * 4.2
		velocity.x += knock.x
		velocity.z += knock.z

	if health <= 0:
		_die()
	else:
		if anim and anim.has_animation(ANIM_HIT):
			anim.play(ANIM_HIT, 0.05)
		state = State.COOLDOWN
		_cd = 0.35

func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	if anim and anim.has_animation(ANIM_DEATH):
		anim.play(ANIM_DEATH, 0.1)
	died.emit(self)
	# 尸身停留一下再沉入雾中
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.9)
	tw.tween_callback(queue_free)
