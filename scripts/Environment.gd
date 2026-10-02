extends WorldEnvironment
## 《定风波》环境氛围控制器
## 目标观感：燕云十六声 —— 高对比、暖褐主调、远景空气透视、背景虚化
##
## 调参记录（v1 → v2）：
##   v1 问题：山被雾洗成纯白圆锥、地面过黄像沙漠
##   v2 修正：降低雾密度并抬高雾的起始高度、压暗地面、山体加冷调

@export_group("光照")
@export var sun_energy: float = 3.8
@export var sun_color: Color = Color(1.0, 0.851, 0.643)
@export var ambient_energy: float = 0.62
@export var ambient_color: Color = Color(0.243, 0.286, 0.353)

@export_group("氛围")
@export var fog_density: float = 0.0055
@export var fog_light_color: Color = Color(0.647, 0.686, 0.702)
@export var fog_sky_affect: float = 0.30

@export_group("画质开关")
@export var enable_dof: bool = true
@export var enable_ssao: bool = true
@export var enable_glow: bool = true

var sun: DirectionalLight3D
var _env: Environment

func _ready() -> void:
	_env = Environment.new()
	_setup_sky()
	_setup_fog()
	_setup_tonemap()
	_setup_ssao()
	_setup_glow()
	environment = _env
	_setup_sun()
	add_to_group("world_env")

## 天空：顶部冷灰蓝 / 地平线暖米白 —— 燕云的天空是"带雾的暖灰"，不是纯蓝
func _setup_sky() -> void:
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.243, 0.310, 0.400)
	mat.sky_horizon_color = Color(0.749, 0.729, 0.686)
	mat.sky_curve = 0.18
	mat.ground_bottom_color = Color(0.212, 0.192, 0.161)
	mat.ground_horizon_color = Color(0.639, 0.616, 0.573)
	mat.ground_curve = 0.14
	mat.sun_angle_max = 18.0
	mat.sun_curve = 0.08
	sky.sky_material = mat
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = ambient_energy
	_env.ambient_light_color = ambient_color
	_env.sky_rotation = Vector3(0.0, deg_to_rad(-38.0), 0.0)

## 空气透视
## v1 雾太浓（0.014），把三层山全洗成白色圆锥 —— 山的颜色废了
## v2 降到 0.0055：近景清晰，中景起雾，远景才褪色 —— 这才是空气透视
func _setup_fog() -> void:
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_light_color = fog_light_color
	_env.fog_light_energy = 0.85
	_env.fog_density = fog_density
	_env.fog_sky_affect = fog_sky_affect
	_env.fog_aerial_perspective = 0.55
	_env.fog_sun_scatter = 0.28   # 逆光时雾会"发亮"，这是电影感来源
	_env.fog_height = 0.0
	_env.fog_height_density = 0.0

## ACES 色调映射 + 曝光压低 —— 70% 画面沉在暗部
func _setup_tonemap() -> void:
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 1.18
	_env.tonemap_white = 5.0

func _setup_ssao() -> void:
	_env.ssao_enabled = enable_ssao
	if not enable_ssao:
		return
	_env.ssao_radius = 1.9
	_env.ssao_intensity = 2.6
	_env.ssao_power = 1.9
	_env.ssao_detail = 0.5
	_env.ssao_horizon = 0.06
	_env.ssao_sharpness = 0.98
	_env.ssao_light_affect = 0.20

func _setup_glow() -> void:
	_env.glow_enabled = enable_glow
	if not enable_glow:
		return
	_env.glow_intensity = 0.48
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.05
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.glow_hdr_threshold = 1.22
	_env.glow_hdr_scale = 2.0

## 景深属于「相机属性」，见 Camera.gd 的 _setup_attributes()
func get_dof_params() -> Dictionary:
	return {
		"enabled": enable_dof,
		"far_distance": 16.0,
		"far_transition": 22.0,
		"amount": 0.075,
	}

## 主方向光：低角度暖光 + 硬阴影
func _setup_sun() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.light_angular_distance = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.05
	sun.directional_shadow_split_2 = 0.14
	sun.directional_shadow_split_3 = 0.34
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.1
	# 横版顺光：相机在 +Z，太阳也从 +Z 侧照向角色 → 角色正面受光，不再背光成黑影
	sun.rotation_degrees = Vector3(-50.0, 20.0, 0.0)
	add_child(sun)

func get_sun_direction() -> Vector3:
	if sun == null:
		return Vector3(0.55, 0.62, -0.56).normalized()
	return sun.global_transform.basis.z.normalized()

func set_dof_focus(world_pos: Vector3) -> void:
	if not enable_dof:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var attrs := cam.attributes
	if attrs is CameraAttributesPractical:
		var ap := attrs as CameraAttributesPractical
		var d := cam.global_position.distance_to(world_pos)
		ap.dof_blur_far_distance = maxf(6.0, d + 5.0)
