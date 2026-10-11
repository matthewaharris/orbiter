shader_type spatial;
// Banded planetary rings on a flat plane mesh.
render_mode blend_mix, depth_draw_never, cull_disabled;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 ring_color : source_color = vec3(0.85, 0.75, 0.6);
uniform float inner = 0.55;
uniform float outer = 1.0;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float d = length(c);
	if (d < inner || d > outer) {
		discard;
	}
	float t = (d - inner) / (outer - inner);
	float bandsv = vnoise(vec3(t * 40.0, 0.0, 0.0)) * 0.6 + vnoise(vec3(t * 140.0, 3.0, 0.0)) * 0.4;
	float gap = smoothstep(0.02, 0.06, abs(t - 0.62));
	float edge = smoothstep(0.0, 0.05, t) * smoothstep(1.0, 0.9, t);
	ALBEDO = ring_color * (0.6 + bandsv * 0.6);
	ALPHA = clamp(bandsv * 1.1, 0.15, 0.9) * gap * edge;
	ROUGHNESS = 0.9;
}
