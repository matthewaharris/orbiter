shader_type spatial;
// Spiraling energy disc inside the portal ring.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.55, 0.25, 1.0);
uniform vec3 color_b : source_color = vec3(0.2, 0.9, 1.0);
uniform float energy = 1.6;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float d = length(c);
	if (d > 1.0) {
		discard;
	}
	float a = atan(c.y, c.x);
	float swirl = a + d * 7.0 - TIME * 2.2;
	float n = fbm(vec3(cos(swirl) * 1.5, sin(swirl) * 1.5, d * 3.0 - TIME * 0.6));
	float arms = 0.5 + 0.5 * sin(swirl * 3.0 + n * 5.0);
	float core = pow(1.0 - d, 2.5);
	vec3 col = mix(color_a, color_b, arms * (1.0 - d));
	col *= arms * 0.7 + core * 2.5;
	col *= smoothstep(1.0, 0.82, d);
	ALBEDO = col * energy;
}
