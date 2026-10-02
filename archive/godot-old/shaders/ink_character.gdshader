shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, ambient_light_disabled;
// 《定风波》角色水墨着色
// 核心：不用 PBR 贴图明暗，而用「墨分五色」的硬阶色带 —— 这正是水墨/燕云画感的来源
// 同时保留贴图色相，避免人物变成纯灰
//
// 注意：光照明暗在 vertex() 里算好传给 fragment。
// 原因：Godot 的 LIGHT 内建只在 light() 函数有效，fragment() 里没有；
//       而人物墨阶是"整体明暗"，vertex 级精度完全够用 —— 反而更省手机 GPU。

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient_map : hint_default_white, filter_linear, repeat_disable;

uniform vec3 ink_tint : source_color = vec3(0.91, 0.89, 0.85);
uniform float band_count : hint_range(2.0, 8.0) = 5.0;
uniform float band_softness : hint_range(0.0, 0.25) = 0.035;
uniform float shadow_tint_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec3 shadow_tint : source_color = vec3(0.29, 0.33, 0.42);
uniform float rim_power : hint_range(0.0, 8.0) = 3.2;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.62;
uniform vec3 rim_color : source_color = vec3(1.0, 0.86, 0.68);
uniform float ink_darken : hint_range(0.0, 1.0) = 0.16;
// —— 侠客调色（横版新增）——
// KayKit 素材是高饱和卡通色，直接上水墨色带会像塑料玩具。
// desaturate 先压掉饱和度，cloth_tint 再罩主色调：
// 玩家传月白 → 白衣侠客；敌人传暗褐 → 玄甲刀客
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform vec3 cloth_tint : source_color = vec3(1.0, 1.0, 1.0);
// 由 World.gd 在运行时注入主光方向（世界空间，指向光源）
// 不用内建 LIGHT_DIRECTION：它在 vertex 阶段不保证可用，显式注入最稳
uniform vec3 sun_dir = vec3(0.55, 0.62, -0.56);

varying float v_ndl;
varying float v_facing;

void vertex() {
	// 主光方向与法线的点乘 —— 在 vertex 里算，省 GPU
	vec3 n_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_ndl = clamp(dot(n_world, normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
	// 视角夹角：给边缘光用
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
	v_facing = 1.0 - abs(dot(n_world, to_cam));
}

void fragment() {
	vec3 tex = texture(albedo_tex, UV).rgb;
	vec3 base = tex * ink_tint;

	// 侠客调色：去饱和（压掉卡通塑料感）再罩主色 —— 月白 / 玄褐
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(base, vec3(luma), desaturate) * cloth_tint;

	// 硬阶色带：把连续光照明暗量化成 N 阶（墨分五色）
	float ndl = v_ndl;
	float bands = floor(ndl * band_count) / band_count;
	bands += smoothstep(0.5 - band_softness, 0.5 + band_softness, fract(ndl * band_count)) / band_count;
	bands = clamp(bands, 0.0, 1.0);
	vec3 ramp = texture(gradient_map, vec2(clamp(bands, 0.02, 0.98), 0.5)).rgb;

	// 暗部偏冷蓝：水墨画里墨不是黑的，是青灰
	vec3 shadow_mix = mix(ramp, ramp * shadow_tint, (1.0 - bands) * shadow_tint_strength);

	// 边缘光：模拟宣纸边缘透光，让人物从背景里"跳"出来
	float rim = pow(clamp(v_facing, 0.0, 1.0), rim_power);

	vec3 col = base * shadow_mix;
	col = mix(col, col * 0.6, ink_darken * (1.0 - bands));
	col += rim_color * rim * rim_strength * (0.35 + 0.65 * bands);

	ALBEDO = col;
	ROUGHNESS = 0.78;
	SPECULAR = 0.22;
	METALLIC = 0.0;
}
