extends CanvasLayer
## 《定风波》HUD —— 燕云式：描边字 + 半透明暗色面板 + 极简
## 同时承载手机端虚拟摇杆与动作按钮

@export var joystick_radius: float = 74.0
@export var button_radius: float = 46.0
@export var joystick_anchor: Vector2 = Vector2(0.155, 0.74)
@export var attack_anchor: Vector2 = Vector2(0.855, 0.72)
@export var dodge_anchor: Vector2 = Vector2(0.715, 0.845)

var _joy_id: int = -1
var _joy_center: Vector2
var _joy_knob: Vector2
var _joy_active: bool = false
var _knob_node: Control
var _base_node: Control
var _attack_btn: Control
var _dodge_btn: Control
var _hp_fill: ColorRect
var _hp_label: Label
var _combo_label: Label
var _hint: Label

var _built: bool = false

const INK := Color(0.086, 0.094, 0.106)
const PAPER := Color(0.847, 0.827, 0.780)
const CRIMSON := Color(0.706, 0.196, 0.180)
const PANEL_BG := Color(0.055, 0.063, 0.071, 0.52)

func _ready() -> void:
	ensure_built()

## 幂等构建入口。
## World.gd 也会调它，用来兜底「脚本是 set_script 补挂的、_ready() 没触发」的情况。
## 重复调用安全 —— _built 守卫保证 UI 只建一次。
func ensure_built() -> void:
	if _built:
		return
	_built = true
	layer = 10
	_build_vignette()
	_build_hp()
	_build_hint()
	_build_joystick()
	_build_buttons()
	_connect_player()

func _connect_player() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		# 玩家可能稍后加入
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	if p.has_signal("health_changed"):
		p.health_changed.connect(_on_health)
		_on_health(p.health, p.max_health)
	if p.has_signal("combo_changed"):
		p.combo_changed.connect(_on_combo)

# ---------------- 暗角：把视线压向中心（燕云常用）----------------
func _build_vignette() -> void:
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.color = Color(0, 0, 0, 0)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.15, 1.0));
	float v = smoothstep(0.34, 0.78, d);
	COLOR = vec4(0.02, 0.024, 0.03, v * 0.62);
}
"""
	mat.shader = sh
	cr.material = mat
	add_child(cr)

# ---------------- 血条 ----------------
func _build_hp() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 26)
	panel.custom_minimum_size = Vector2(268, 46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.30)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = "苏 轼 · 定风波"
	name_lbl.add_theme_color_override("font_color", PAPER)
	name_lbl.add_theme_font_size_override("font_size", 14)
	vb.add_child(name_lbl)

	var bar_bg := Panel.new()
	bar_bg.custom_minimum_size = Vector2(0, 8)
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = Color(0.10, 0.11, 0.12, 0.85)
	bar_sb.set_corner_radius_all(2)
	bar_bg.add_theme_stylebox_override("panel", bar_sb)
	vb.add_child(bar_bg)

	_hp_fill = ColorRect.new()
	_hp_fill.color = CRIMSON
	_hp_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_fill.offset_right = 0
	bar_bg.add_child(_hp_fill)

	_hp_label = Label.new()
	_hp_label.text = "100 / 100"
	_hp_label.add_theme_color_override("font_color", Color(PAPER.r, PAPER.g, PAPER.b, 0.66))
	_hp_label.add_theme_font_size_override("font_size", 11)
	vb.add_child(_hp_label)

func _on_health(cur: int, maxv: int) -> void:
	if _hp_fill == null:
		return
	var ratio := clampf(float(cur) / maxf(1.0, float(maxv)), 0.0, 1.0)
	var parent := _hp_fill.get_parent_control()
	var w := parent.size.x if parent else 240.0
	var tw := create_tween()
	tw.tween_property(_hp_fill, "size", Vector2(w * ratio, _hp_fill.size.y), 0.18)
	_hp_label.text = "%d / %d" % [cur, maxv]

func _on_combo(step: int) -> void:
	if _combo_label == null:
		return
	if step <= 0:
		_combo_label.modulate.a = 0.0
		return
	_combo_label.text = "连击 %d" % step
	_combo_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(_combo_label, "modulate:a", 0.0, 0.35)

func _build_hint() -> void:
	_combo_label = Label.new()
	_combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo_label.position = Vector2(0, 132)
	_combo_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.text = ""
	_combo_label.modulate.a = 0.0
	_combo_label.add_theme_color_override("font_color", Color(0.965, 0.847, 0.706))
	_combo_label.add_theme_font_size_override("font_size", 30)
	_combo_label.add_theme_constant_override("outline_size", 5)
	_combo_label.add_theme_color_override("font_outline_color", INK)
	add_child(_combo_label)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(0, -54)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = "莫听穿林打叶声 · 何妨吟啸且徐行"
	_hint.add_theme_color_override("font_color", Color(PAPER.r, PAPER.g, PAPER.b, 0.5))
	_hint.add_theme_font_size_override("font_size", 15)
	add_child(_hint)

# ---------------- 虚拟摇杆 ----------------
func _build_joystick() -> void:
	_base_node = _mk_circle(joystick_radius, Color(0.05, 0.06, 0.07, 0.30), Color(PAPER.r, PAPER.g, PAPER.b, 0.22))
	add_child(_base_node)
	_knob_node = _mk_circle(joystick_radius * 0.42, Color(0.85, 0.83, 0.79, 0.42), Color(PAPER.r, PAPER.g, PAPER.b, 0.5))
	add_child(_knob_node)
	_joy_center = Vector2(get_viewport().get_visible_rect().size) * joystick_anchor
	_joy_knob = _joy_center
	_place_joy()

func _mk_circle(radius: float, fill: Color, border: Color) -> Control:
	var p := Panel.new()
	p.size = Vector2(radius * 2.0, radius * 2.0)
	p.custom_minimum_size = p.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(radius))
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _place_joy() -> void:
	if _base_node:
		_base_node.position = _joy_center - _base_node.size * 0.5
	if _knob_node:
		_knob_node.position = _joy_knob - _knob_node.size * 0.5

# ---------------- 动作按钮 ----------------
func _build_buttons() -> void:
	_attack_btn = _mk_button("击", attack_anchor, button_radius, Color(0.706, 0.196, 0.180, 0.55))
	_dodge_btn = _mk_button("避", dodge_anchor, button_radius * 0.86, Color(0.29, 0.33, 0.42, 0.55))

func _mk_button(text: String, anchor: Vector2, radius: float, tint: Color) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := _mk_circle(radius, tint, Color(PAPER.r, PAPER.g, PAPER.b, 0.42))
	holder.add_child(c)
	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", PAPER)
	lbl.add_theme_font_size_override("font_size", int(radius * 0.72))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", INK)
	c.add_child(lbl)
	add_child(holder)
	var vp := Vector2(get_viewport().get_visible_rect().size)
	holder.position = vp * anchor - Vector2(radius, radius)
	return holder

# ---------------- 输入分发 ----------------
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var t := InputEventScreenTouch.new()
			t.index = 0
			t.pressed = mb.pressed
			t.position = mb.position
			_handle_touch(t)
	elif event is InputEventMouseMotion and _joy_id == 0:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = (event as InputEventMouseMotion).position
		_handle_drag(d)

func _handle_touch(t: InputEventScreenTouch) -> void:
	var vp := Vector2(get_viewport().get_visible_rect().size)
	var local_joy := vp * joystick_anchor
	var local_atk := vp * attack_anchor
	var local_dod := vp * dodge_anchor

	if t.pressed:
		# 动作按钮优先判定
		if t.position.distance_to(local_atk) <= button_radius * 1.35:
			_press_action("attack")
			return
		if t.position.distance_to(local_dod) <= button_radius * 1.25:
			_press_action("dodge")
			return
		# 左半屏任意位置起手摇杆（比固定圆心更好用）
		if t.position.x < vp.x * 0.5 or t.position.distance_to(local_joy) <= joystick_radius * 1.6:
			if _joy_id == -1:
				_joy_id = t.index
				_joy_center = t.position
				_joy_knob = t.position
				_joy_active = true
				_place_joy()
	else:
		if t.index == _joy_id:
			_joy_id = -1
			_joy_active = false
			_joy_center = vp * joystick_anchor
			_joy_knob = _joy_center
			_place_joy()
			_release_axis()

func _handle_drag(d: InputEventScreenDrag) -> void:
	if d.index != _joy_id or not _joy_active:
		return
	var v := d.position - _joy_center
	if v.length() > joystick_radius:
		v = v.normalized() * joystick_radius
	_joy_knob = _joy_center + v
	_place_joy()
	_push_axis(v / joystick_radius)

func _push_axis(v: Vector2) -> void:
	# 摇杆 y 轴向下为屏幕下，映射到 -Z(前) / +Z(后)
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_back")
	var dead := 0.18
	if absf(v.x) > dead:
		if v.x > 0.0: Input.action_press("move_right", absf(v.x))
		else: Input.action_press("move_left", absf(v.x))
	if absf(v.y) > dead:
		if v.y > 0.0: Input.action_press("move_back", absf(v.y))
		else: Input.action_press("move_forward", absf(v.y))
	# 摇杆推到底自动切冲刺
	if v.length() > 0.82:
		Input.action_press("sprint", 1.0)
	else:
		Input.action_release("sprint")

func _release_axis() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back", "sprint"]:
		Input.action_release(a)

func _press_action(a: String) -> void:
	Input.action_press(a, 1.0)
	# 短促释放，模拟"点按"
	get_tree().create_timer(0.09).timeout.connect(func(): Input.action_release(a))
