shader_type spatial;
// Fresnel rim glow for atmospheres.
render_mode blend_add, unshaded, depth_draw_never, cull_back;

uniform vec3 atmo_color : source_color = vec3(0.4, 0.6, 1.0);
uniform float intensity = 1.0;
uniform float power = 3.0;

void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(f, power);
	ALBEDO = atmo_color * rim * intensity * 1.6;
}
