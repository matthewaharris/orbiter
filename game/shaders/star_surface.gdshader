shader_type spatial;
// Boiling plasma surface. `charge` (0..1) brightens the star before a CME.
render_mode unshaded;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 color_core : source_color = vec3(1.0, 0.9, 0.6);
uniform vec3 color_edge : source_color = vec3(1.0, 0.45, 0.1);
uniform float energy = 3.0;
uniform float charge = 0.0;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 p = normalize(obj_pos);
	float n = fbm(p * 5.0 + vec3(TIME * 0.12, -TIME * 0.07, TIME * 0.05));
	float g = fbm(p * 16.0 + vec3(-TIME * 0.35, TIME * 0.2, 0.0));
	float limb = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c = mix(color_edge, color_core, smoothstep(0.0, 0.85, limb));
	c *= 0.55 + 0.7 * n + 0.35 * g;
	float flicker = 1.0 + charge * (2.0 + 0.6 * sin(TIME * 30.0));
	ALBEDO = c * energy * flicker;
}
