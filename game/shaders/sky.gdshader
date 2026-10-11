shader_type sky;
// Procedural starfield with soft nebula clouds. Uses no TIME, so the radiance map stays cached.
#include "res://shaders/noise.gdshaderinc"

uniform vec3 nebula_a : source_color = vec3(0.4, 0.12, 0.55);
uniform vec3 nebula_b : source_color = vec3(0.05, 0.35, 0.55);
uniform float nebula_strength = 0.55;
uniform float star_brightness = 1.6;

vec3 star_layer(vec3 d, float scale, float threshold) {
	vec3 p = d * scale;
	vec3 cell = floor(p);
	vec3 f = fract(p);
	float h = hash13(cell);
	if (h < threshold) {
		return vec3(0.0);
	}
	vec3 o = vec3(hash13(cell + 1.3), hash13(cell + 2.7), hash13(cell + 5.1)) * 0.6 + 0.2;
	float dist = length(f - o);
	float b = (h - threshold) / (1.0 - threshold);
	float core = smoothstep(0.09, 0.0, dist);
	float halo = smoothstep(0.35, 0.0, dist) * 0.15;
	vec3 tint = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.8, 0.6), hash13(cell + 9.9));
	return tint * (core + halo) * (0.3 + b * 2.0);
}

void sky() {
	vec3 d = EYEDIR;
	float n1 = fbm(d * 1.8 + vec3(3.1, 1.2, 0.4));
	float n2 = fbm(d * 3.6 + n1 * 2.2);
	float dust = fbm(d * 6.0 + 4.0);
	float mask = smoothstep(0.42, 0.85, n1 * 0.6 + n2 * 0.6);
	vec3 neb = mix(nebula_a, nebula_b, smoothstep(0.3, 0.7, n2)) * mask * nebula_strength;
	neb *= mix(0.4, 1.0, smoothstep(0.3, 0.6, dust));
	vec3 col = vec3(0.004, 0.005, 0.011) + neb;
	col += star_layer(d, 260.0, 0.982) * star_brightness;
	col += star_layer(d, 90.0, 0.994) * star_brightness * 1.8;
	COLOR = col;
}
