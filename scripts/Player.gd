extends CharacterBody3D
## 《定风波》主角控制器
## 逻辑继承自网页版 v6（四向移动 / 普攻三连 / 闪避无敌帧），
## 但动作全部换成 KayKit 真实骨骼动画 —— 这是观感质变的关键

signal health_changed(cur: int, max: int)
signal combo_changed(step: int)
signal attack_hit(damage: int, knock: Vector3)
signal dodged()

@export_group("移动")
@export var move_speed: float = 5.2
@export var sprint_speed: float = 7.6
@export var accel: float = 22.0
@export var friction: float = 26.0
@export var turn_speed: float = 13.0

@export_group("战斗")
@export var max_health: int = 100
@export var attack_damage: int = 12
@export var combo_window: float = 0.72
@export var attack_move_scale: float = 0.34

@export_group("闪避")
@export var dodge_speed: float = 13.5
@export var dodge_duration: float = 0.42
@export var dodge_iv_start: float = 0.05
@export var dodge_iv_end: float = 0.32
@export var dodge_cooldown: float = 0.55

var health: int
var is_alive: bool = true
var combo_step: int = 0
var combo_timer: float = 0.0
var is_attacking: bool = false
var attack_lock: float = 0.0
var is_dodging: bool = false
var dodge_time: float = 0.0
var dodge_cd: float = 0.0
var invulnerable: bool = false
var move_input: Vector2 = Vector2.ZERO
var facing: Vector3 = Vector3.FORWARD
var _want_attack: bool = false
var _want_dodge: bool = false

@onready var model_root: Node3D = $ModelRoot
## 递归查找动画机，而不是写死 "$ModelRoot/AnimationPlayer"。
## glb 自带的 AnimationPlayer 必须留在原层级，否则动画轨道
## （"Rig/Skeleton3D:xxx" 这类相对路径）会全部解析失败、骨架塌缩成方块。
@onready var anim: AnimationPlayer = _find_anim_player(model_root)
@onready var _env: WorldEnvironment = get_tree().get_first_node_in_group("world_env")

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
const COMBO_ANIMS := [
	"1H_Melee_Attack_Slice_Diagonal",
	"1H_Melee_Attack_Slice_Horizontal",
	"2H_Melee_Attack_Spin",
]
const ANIM_DODGE := "Dodge_Forward"

func _ready() -> void:
	add_to_group("player")
	health = max_health
	_connect_animations()
	if anim:
		anim.play(ANIM_IDLE)

func _connect_animations() -> void:
	if anim == null:
		push_warning("[Player] 未找到 AnimationPlayer，请确认 ModelRoot 下已挂载")
		return
	anim.animation_finished.connect(_on_anim_finished)

func _unhandled_input(event: InputEvent) -> void:
	if not is_alive:
		return
	if event.is_action_pressed("attack"):
		_want_attack = true
	if event.is_action_pressed("dodge"):
		_want_dodge = true

func _physics_process(delta: float) -> void:
	if not is_alive:
		_apply_gravity(delta)
		move_and_slide()
		return

	_read_input()
	_tick_timers(delta)
	_handle_dodge(delta)
	_handle_attack()
	_handle_locomotion(delta)
	_apply_gravity(delta)
	move_and_slide()

func _read_input() -> void:
	move_input = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)
	if move_input.length() > 1.0:
		move_input = move_input.normalized()

func _tick_timers(delta: float) -> void:
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_step = 0
			combo_changed.emit(0)
	if attack_lock > 0.0:
		attack_lock -= delta
	if dodge_cd > 0.0:
		dodge_cd -= delta

# ---------------- 闪避 ----------------
func _handle_dodge(delta: float) -> void:
	if _want_dodge and not is_dodging and dodge_cd <= 0.0:
		_start_dodge()
	_want_dodge = false

	if not is_dodging:
		return

	dodge_time += delta
	invulnerable = dodge_time >= dodge_iv_start and dodge_time <= dodge_iv_end

	var dir := _dodge_direction()
	velocity.x = dir.x * dodge_speed
	velocity.z = dir.z * dodge_speed

	if dodge_time >= dodge_duration:
		is_dodging = false
		invulnerable = false
		dodge_cd = dodge_cooldown

func _start_dodge() -> void:
	is_dodging = true
	dodge_time = 0.0
	is_attacking = false
	combo_step = 0
	combo_changed.emit(0)
	if anim and anim.has_animation(ANIM_DODGE):
		anim.play(ANIM_DODGE, 0.08, 1.25)
	dodged.emit()

func _dodge_direction() -> Vector3:
	var dir := Vector3(move_input.x, 0.0, move_input.y)
	if dir.length_squared() < 0.01:
		dir = facing
	return dir.normalized()

# ---------------- 攻击 ----------------
func _handle_attack() -> void:
	if _want_attack and not is_attacking and not is_dodging:
		_start_attack()
	_want_attack = false

func _start_attack() -> void:
	is_attacking = true
	combo_step += 1
	if combo_step > COMBO_ANIMS.size():
		combo_step = 1
	combo_timer = combo_window
	attack_lock = 0.18
	combo_changed.emit(combo_step)

	var a: String = COMBO_ANIMS[combo_step - 1]
	var speed := 1.0 + (combo_step - 1) * 0.12
	if anim and anim.has_animation(a):
		anim.play(a, 0.06, speed)
	attack_hit.emit(attack_damage + (combo_step - 1) * 4, facing)

func _on_anim_finished(name_: StringName) -> void:
	if String(name_).begins_with("1H_Melee") or String(name_).begins_with("2H_Melee"):
		is_attacking = false
		if combo_timer <= 0.0:
			combo_step = 0
			combo_changed.emit(0)

# ---------------- 移动 ----------------
func _handle_locomotion(delta: float) -> void:
	if is_dodging:
		return

	var dir := Vector3(move_input.x, 0.0, move_input.y)
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
		facing = dir
		var target_yaw := atan2(dir.x, dir.z)
		model_root.rotation.y = lerp_angle(model_root.rotation.y, target_yaw, turn_speed * delta)

		var want := move_speed
		if is_attacking:
			want *= attack_move_scale
		var target_vel := dir * want
		velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)
		_play_locomotion_anim(true, want)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		_play_locomotion_anim(false, 0.0)

	# 攻击/闪避期间不打断动作
	if is_attacking or is_dodging:
		return

func _play_locomotion_anim(moving: bool, speed: float) -> void:
	if anim == null:
		return
	var target := ANIM_IDLE
	if moving:
		target = ANIM_RUN if speed > move_speed + 0.5 else ANIM_WALK
	if anim.current_animation != target and anim.has_animation(target):
		anim.play(target, 0.14)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0

# ---------------- 受击 ----------------
func take_damage(amount: int, from: Vector3) -> void:
	if not is_alive or invulnerable:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()

func _die() -> void:
	is_alive = false
	if anim and anim.has_animation("Death_A"):
		anim.play("Death_A", 0.12)

func heal(amount: int) -> void:
	if not is_alive:
		return
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)

func get_facing() -> Vector3:
	return facing
