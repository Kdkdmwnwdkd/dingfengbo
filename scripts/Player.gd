extends CharacterBody3D
## 《定风波》主角控制器 —— 横版水墨动作
## 逻辑继承自网页版 v6（四向移动 / 普攻三连 / 闪避无敌帧），
## 但动作全部换成真实骨骼动画 —— 这是观感质变的关键
##
## 【换模型零成本】动画名自适应：
## 不同来源的模型动画命名天差地别（KayKit 用 "Walking_A"、Mixamo 用 "Walk"、
## 原神提取常用 "walk" 或 "WalkForward"…）。_resolve_anims() 在 _ready 里
## 按候选名表逐个 has_animation 探测，命中即用 —— 换任何模型都不用改代码。

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

## 动画名候选表：每个语义按顺序探测 has_animation，命中即用。
## 覆盖 KayKit / Mixamo / 原神提取 / Quaternius 等主流命名。
const ANIM_CANDIDATES := {
	"idle":    ["Idle", "idle", "IDLE", "Standing", "Stand", "BreathIdle"],
	"walk":    ["Walking_A", "Walk", "walk", "Walking", "WalkForward", "WalkF"],
	"run":     ["Running_A", "Run", "run", "Running", "RunForward", "RunF", "Sprint"],
	"attack1": ["1H_Melee_Attack_Slice_Diagonal", "Attack01", "Attack_01", "Slash1", "Attack1", "attack_1", "Atk1", "Punch", "Punch1"],
	"attack2": ["1H_Melee_Attack_Slice_Horizontal", "Attack02", "Attack_02", "Slash2", "Attack2", "attack_2", "Atk2", "Punch2", "Punch"],
	"attack3": ["2H_Melee_Attack_Spin", "Attack03", "Attack_03", "Slash3", "Attack3", "attack_3", "Atk3", "Punch3", "Punch"],
	"dodge":   ["Dodge_Forward", "Dodge", "Roll", "DodgeForward", "Backstep", "dodge", "DodgeRoll", "Jump", "WalkJump"],
	"hurt":    ["Hit_A", "Hit", "Hurt", "Damage", "GetHit", "hit", "HitReaction"],
	"death":   ["Death_A", "Death", "Die", "Dead", "death", "Death01"],
}
var _anim_resolved: Dictionary = {}

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

func _ready() -> void:
	add_to_group("player")
	health = max_health
	_resolve_anims()
	_connect_animations()
	if anim and _a("idle") != "":
		anim.play(_a("idle"))

## 动画名自适应：探测模型自带的动画命名，建立语义→实际动画名的映射
func _resolve_anims() -> void:
	_anim_resolved.clear()
	if anim == null:
		push_warning("[Player] 未找到 AnimationPlayer，请确认 ModelRoot 下已挂载")
		return
	for semantic in ANIM_CANDIDATES.keys():
		for name in ANIM_CANDIDATES[semantic]:
			if anim.has_animation(name):
				_anim_resolved[semantic] = name
				break
		if not _anim_resolved.has(semantic):
			# 兜底：缺失的语义留空，播放时跳过
			_anim_resolved[semantic] = ""
	print("[Player] 动画解析: ", _anim_resolved)

## 取语义对应的实际动画名（已适配模型命名）
func _a(semantic: String) -> String:
	return _anim_resolved.get(semantic, "")

func _connect_animations() -> void:
	if anim == null:
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
	velocity.z = 0.0  # 横版：疾步只发生在 X 轴
	combo_changed.emit(0)
	if anim and _a("dodge") != "":
		anim.play(_a("dodge"), 0.08, 1.25)
	dodged.emit()

func _dodge_direction() -> Vector3:
	# 横版疾步：优先沿摇杆方向（±X），无输入则向后撤步
	if absf(move_input.x) > 0.12:
		return Vector3(signf(move_input.x), 0.0, 0.0)
	return -facing

# ---------------- 攻击 ----------------
func _handle_attack() -> void:
	if _want_attack and not is_attacking and not is_dodging:
		_start_attack()
	_want_attack = false

func _start_attack() -> void:
	is_attacking = true
	combo_step += 1
	if combo_step > 3:
		combo_step = 1
	combo_timer = combo_window
	attack_lock = 0.18
	combo_changed.emit(combo_step)

	var a := _a("attack%d" % combo_step)
	var speed := 1.0 + (combo_step - 1) * 0.12
	if anim and a != "":
		anim.play(a, 0.06, speed)
	attack_hit.emit(attack_damage + (combo_step - 1) * 4, facing)

func _on_anim_finished(name_: StringName) -> void:
	var s := String(name_)
	# 攻击动画播完才解除攻击锁，否则会卡在第一段
	if s == _a("attack1") or s == _a("attack2") or s == _a("attack3"):
		is_attacking = false
		if combo_timer <= 0.0:
			combo_step = 0
			combo_changed.emit(0)

# ---------------- 移动 ----------------
func _handle_locomotion(delta: float) -> void:
	if is_dodging:
		return

	# 横版走位：只取摇杆的横向分量 —— 左右移动是核心语言，纵向推杆忽略
	# （纵深锁定在走道上，与侧视镜头、横版判定框配套）
	var axis := move_input.x
	if absf(axis) > 0.12:
		var dir := Vector3(signf(axis), 0.0, 0.0)
		facing = dir
		# 目标朝向 ±90°：模型侧影对准镜头 —— 横版的标准站姿
		var target_yaw := atan2(dir.x, dir.z)
		model_root.rotation.y = lerp_angle(model_root.rotation.y, target_yaw, turn_speed * delta)

		var want := move_speed
		if is_attacking:
			want *= attack_move_scale
		# 摇杆轻推慢走：速度随推杆幅度缩放
		var target_vel := dir * want * absf(axis)
		velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
		_play_locomotion_anim(true, want * absf(axis))
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		_play_locomotion_anim(false, 0.0)

	# 纵深锁定：走道外的 Z 分量一律归零（横版）
	velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	# 攻击/闪避期间不打断动作
	if is_attacking or is_dodging:
		return

func _play_locomotion_anim(moving: bool, speed: float) -> void:
	if anim == null:
		return
	var target := _a("idle")
	if moving:
		target = _a("run") if speed > move_speed + 0.5 else _a("walk")
	if target == "":
		return
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
	else:
		if anim and _a("hurt") != "" and anim.has_animation(_a("hurt")):
			anim.play(_a("hurt"), 0.05)

func _die() -> void:
	is_alive = false
	if anim and _a("death") != "" and anim.has_animation(_a("death")):
		anim.play(_a("death"), 0.12)

func heal(amount: int) -> void:
	if not is_alive:
		return
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)

func get_facing() -> Vector3:
	return facing
