shader_type spatial;
// Camera-facing glow with streamers around a star.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.6, 0.2);
uniform float energy = 1.5;
uniform float charge = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float d = length(c);
	float a = atan(c.y, c.x);
	float rays = fbm(vec3(cos(a) * 3.0, sin(a) * 3.0, TIME * 0.25 - d * 1.5));
	float glow = pow(max(0.0, 1.0 - d), 2.5 - charge);
	float streamers = pow(max(0.0, 1.0 - d), 1.4) * smoothstep(0.45, 0.8, rays);
	ALBEDO = color * (glow * 1.2 + streamers * (0.8 + charge * 1.5)) * energy * (1.0 + charge);
}
