extends Node
## 相机自检探针：完全不接管相机，让 Camera.gd 自己跑。
## 每隔一段时间截一张，用来验证「默认第三人称视角」是否正确。
## 如果 Camera.gd 的 target 正常，画面里应该能看到主角背影 + 竹林纵深。

@export var out_dir: String = "/tmp/camcheck"
@export var total_time: float = 4.0
@export var interval: float = 1.0

var _t: float = 0.0
var _next: float = 0.0
var _i: int = 0
var _cam: Camera3D
var _player: Node3D
var _done: bool = false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await get_tree().process_frame
	_cam = get_viewport().get_camera_3d()
	_player = get_tree().get_first_node_in_group("player")

	print("==================== 相机自检 ====================")
	if _cam == null:
		print("❌ 场景里没有 Camera3D！")
	else:
		print("相机节点: ", _cam.name)
		print("相机脚本: ", _cam.get_script().resource_path if _cam.get_script() else "(无)")
		var tp = _cam.get("target_path")
		print("target_path = ", tp)
		var tg = _cam.get("target")
		print("target      = ", tg)
		if tg == null:
			print("❌❌ 致命：target 为 null —— 相机不会跟随，会卡死在原点！")
		else:
			print("✅ target 正常:", (tg as Node).name)
	if _player == null:
		print("❌ 找不到 player 组节点")
	else:
		print("玩家位置: ", _player.global_position)

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t >= _next:
		_next += interval
		_grab()
	if _t >= total_time:
		_done = true
		print("==================== 自检结束 ====================")
		get_tree().quit()

func _grab() -> void:
	if _cam == null:
		return
	var cp := _cam.global_position
	var pp := _player.global_position if _player else Vector3.ZERO
	var d := cp.distance_to(pp)
	var dir := (pp - cp).normalized()
	print("[t=%.1fs] 相机位置=(%.2f, %.2f, %.2f) 玩家=(%.2f, %.2f, %.2f) 距离=%.2fm 方向=%.2f" % [
		_t, cp.x, cp.y, cp.z, pp.x, pp.y, pp.z, d, _cam.global_transform.basis.z.dot(dir)])
	# 相机应看向玩家：basis.z 是相机的"后方"，与指向玩家的方向点积应约为 -1
	var facing: float = _cam.global_transform.basis.z.dot(dir)
	if facing < -0.6:
		print("   ✅ 相机正对玩家")
	elif facing > 0.6:
		print("   ❌ 相机背对玩家（看反了）")
	else:
		print("   ⚠ 相机没有对准玩家")

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/cam_%02d.png" % [out_dir, _i]
	img.save_png(path)
	print("   截图 → ", path)
	_i += 1
