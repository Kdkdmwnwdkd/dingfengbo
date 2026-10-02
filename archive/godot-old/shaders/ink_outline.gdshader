shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
// 《定风波》水墨描边 —— 反向外壳法
// 原理：复制模型 - 沿法线外扩 - 翻面 - 只画背面 => 形成描边轮廓
// 与网页版 v6 同源，但在 Godot 里用真实法线，描边粗细不随距离炸裂

uniform float outline_width : hint_range(0.0, 0.08) = 0.011;
uniform vec3 outline_color : source_color = vec3(0.078, 0.086, 0.098);
uniform float width_falloff : hint_range(0.0, 1.0) = 0.42;
uniform float min_pixel_width : hint_range(0.0, 8.0) = 1.1;

varying vec3 v_view_pos;

void vertex() {
	v_view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 距离衰减：远处的描边不收细，否则远景糊成一团黑
	float dist = length(v_view_pos);
	float scale = 1.0 + dist * width_falloff;
	// 像素级保底：保证最远也能看到 ~1px 描边
	float pixel_guard = min_pixel_width * dist * 0.0009;
	VERTEX += NORMAL * (outline_width * scale + pixel_guard);
}

void fragment() {
	// 用视角与法线的夹角做描边浓淡 —— 边缘处更实，正面几乎不可见
	vec3 vn = normalize(-v_view_pos);
	float facing = 1.0 - abs(dot(vn, normalize(NORMAL)));
	float alpha = smoothstep(0.05, 0.55, facing);
	ALBEDO = outline_color;
	ALPHA = alpha * 0.95;
}
