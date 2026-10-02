extends Node
## 自动截图探针：启动后等待指定帧，把画面存成 PNG 再退出
## 用于在无 GUI 环境下验证渲染结果（需要 Xvfb 或 xvfb-run）

@export var out_dir: String = "/tmp/godot_shots"
@export var shots: Array = [
	{"name": "01_wide", "delay": 1.2, "cam_offset": Vector3(0, 3.2, 9.5), "look_h": 1.0},
	{"name": "02_shoulder", "delay": 0.6, "cam_offset": Vector3(1.2, 1.7, -3.2), "look_h": 1.3},
	{"name": "03_low", "delay": 0.6, "cam_offset": Vector3(0.6, 0.7, -2.6), "look_h": 1.5},
	{"name": "04_high", "delay": 0.6, "cam_offset": Vector3(0, 6.0, 6.0), "look_h": 0.4},
]

var _idx: int = 0
var _t: float = 0.0
var _cam: Camera3D
var _player: Node3D
var _waiting: bool = true

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	await get_tree().process_frame
	_cam = get_viewport().get_camera_3d()
	_player = get_tree().get_first_node_in_group("player")
	# 关掉摄像机的自动跟随，方便固定机位截图
	if _cam and _cam.has_method("set_process"):
		_cam.set_script(null)
		print("[shot] 已接管相机")

func _process(delta: float) -> void:
	_t += delta
	if _idx >= shots.size():
		print("[shot] 全部完成")
		get_tree().quit()
		return
	var s: Dictionary = shots[_idx]
	if _t < float(s["delay"]):
		return
	_t = 0.0
	_place_cam(s)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, s["name"]]
	img.save_png(path)
	print("[shot] 已保存 ", path, "  ", img.get_width(), "x", img.get_height())
	_idx += 1

func _place_cam(s: Dictionary) -> void:
	if _cam == null:
		return
	var base := _player.global_position if _player else Vector3.ZERO
	var off: Vector3 = s["cam_offset"]
	_cam.global_position = base + off
	_cam.look_at(base + Vector3.UP * float(s["look_h"]), Vector3.UP)
