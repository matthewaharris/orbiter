shader_type spatial;
// Animated cloud / weather shell with optional lightning flashes.
render_mode blend_mix, depth_draw_never, cull_back;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 cloud_color : source_color = vec3(1.0);
uniform float coverage = 0.5;
uniform float speed = 0.05;
uniform float seed = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_dir = vec3(0.0, 0.0, 1.0);
uniform vec3 flash_color : source_color = vec3(0.7, 0.8, 1.0);

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 p = normalize(obj_pos);
	// Latitude shear: equator and poles drift at different speeds.
	float ang = TIME * speed * (1.0 + 0.8 * p.y * p.y);
	float c = cos(ang);
	float s = sin(ang);
	vec3 rp = vec3(c * p.x - s * p.z, p.y, s * p.x + c * p.z);
	vec3 q = rp * 3.0 + vec3(seed);
	float w = fbm(q * 0.7 + vec3(TIME * speed * 0.5));
	float n = fbm(q + w * 1.8);
	float a = smoothstep(1.0 - coverage, 1.0 - coverage + 0.22, n);
	float f = flash * smoothstep(0.92, 1.0, dot(p, normalize(flash_dir)));
	ALBEDO = cloud_color;
	ROUGHNESS = 0.9;
	EMISSION = flash_color * f * 12.0 * (0.25 + a);
	ALPHA = max(a * 0.92, f * 0.8);
}
