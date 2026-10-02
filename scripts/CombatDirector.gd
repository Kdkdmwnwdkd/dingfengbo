extends Node
## 《定风波》战斗调度 —— 把玩家攻击信号翻译成对敌人的实际伤害
## 用扇形判定（正面 120°），和网页版 v6 的判定逻辑一致

@export var attack_reach: float = 3.2   # 身前判定距离（横版加长，补偿走位节奏）
@export var attack_behind: float = 0.55 # 贴身时身后也算一点，缠斗不亏刀
@export var attack_lane: float = 1.6    # 纵深容差：|dz| 超过它打不到

var _player: Node3D
var _bound: bool = false

func _ready() -> void:
	ensure_bound()

## 幂等绑定入口 —— World.gd 的兜底调用点。
## 老场景文件里若脚本是 set_script() 补挂的，_ready() 不会触发，就得靠这里补上。
func ensure_bound() -> void:
	if _bound:
		return
	_bound = true
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if _player and _player.has_signal("attack_hit"):
		if not _player.attack_hit.is_connected(_on_attack_hit):
			_player.attack_hit.connect(_on_attack_hit)

func _on_attack_hit(damage: int, facing: Vector3) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var origin := _player.global_position
	var fwd := facing
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		fwd = Vector3(1.0, 0.0, 0.0)
	fwd = fwd.normalized()

	var hits := 0

	# 横版矩形判定：以前向投影 along 为主轴，纵深 side 设容差 ——
	# 老版扇形判定在侧视镜头下，玩家根本读不出 120° 是多大的扇区；
	# 矩形（身前 reach + 身后贴身 + 纵深 lane）所见即所得。
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == null or not is_instance_valid(e):
			continue
		if not (e is Node3D):
			continue
		var en := e as Node3D
		var to: Vector3 = en.global_position - origin
		to.y = 0.0
		var along: float = to.dot(fwd)
		var side: float = absf(to.z)
		if side > attack_lane:
			continue
		if along > attack_reach or along < -attack_behind:
			continue
		if en.has_method("take_damage"):
			en.take_damage(damage, origin)
			hits += 1

	if hits > 0:
		var cam := get_viewport().get_camera_3d()
		if cam and cam.has_method("shake"):
			cam.shake(0.055 + 0.02 * float(hits))
