extends Node
## 《定风波》战斗调度 —— 把玩家攻击信号翻译成对敌人的实际伤害
## 用扇形判定（正面 120°），和网页版 v6 的判定逻辑一致

@export var attack_reach: float = 2.9
@export var attack_arc_deg: float = 120.0

var _player: Node3D

func _ready() -> void:
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if _player and _player.has_signal("attack_hit"):
		_player.attack_hit.connect(_on_attack_hit)

func _on_attack_hit(damage: int, facing: Vector3) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var origin := _player.global_position
	var fwd := facing
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()

	var half := deg_to_rad(attack_arc_deg * 0.5)
	var hits := 0

	for e in get_tree().get_nodes_in_group("enemy"):
		if e == null or not is_instance_valid(e):
			continue
		if not (e is Node3D):
			continue
		var en := e as Node3D
		var to: Vector3 = en.global_position - origin
		to.y = 0.0
		var dist: float = to.length()
		if dist > attack_reach or dist < 0.01:
			continue
		var ang: float = fwd.angle_to(to.normalized())
		if ang > half:
			continue
		if en.has_method("take_damage"):
			en.take_damage(damage, origin)
			hits += 1

	if hits > 0:
		var cam := get_viewport().get_camera_3d()
		if cam and cam.has_method("shake"):
			cam.shake(0.055 + 0.02 * float(hits))
