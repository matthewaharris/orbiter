shader_type spatial;
// Procedural planet surface. `style` matches PlanetType.Surface.
#include "res://shaders/noise.gdshaderinc"

uniform int style = 0;
uniform vec3 color_low : source_color = vec3(0.25, 0.2, 0.18);
uniform vec3 color_mid : source_color = vec3(0.5, 0.42, 0.35);
uniform vec3 color_high : source_color = vec3(0.8, 0.76, 0.7);
uniform vec3 emission_color : source_color = vec3(1.0, 0.4, 0.1);
uniform float emission_strength = 0.0;
uniform float noise_scale = 2.0;
uniform float bands = 7.0;
uniform float polar_caps = 0.0;
uniform float seed = 0.0;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 p = normalize(obj_pos);
	vec3 q = p * noise_scale + vec3(seed * 7.13, seed * 3.71, seed * 1.37);
	float h = fbm(q);
	vec3 albedo = color_mid;
	float rough = 0.85;
	vec3 emit = vec3(0.0);

	if (style == 0) {
		// ROCKY: lowlands, highlands, ridges, a few dark maria.
		float r = ridged(q * 1.7);
		albedo = mix(color_low, color_mid, smoothstep(0.38, 0.62, h));
		albedo = mix(albedo, color_high, smoothstep(0.55, 0.85, h * 0.7 + r * 0.45));
		albedo *= mix(0.65, 1.0, smoothstep(0.25, 0.45, fbm(q * 0.6 + 11.0)));
	} else if (style == 1) {
		// OCEAN: deep/shallow water with continents.
		float land = smoothstep(0.52, 0.545, h);
		vec3 water = mix(color_low * 0.55, color_low * 1.25, smoothstep(0.3, 0.52, h));
		vec3 ground = mix(color_mid, color_high, smoothstep(0.58, 0.8, h));
		albedo = mix(water, ground, land);
		rough = mix(0.12, 0.9, land);
	} else if (style == 2) {
		// GAS GIANT: warped latitude bands with turbulence and a storm eye.
		float warp = fbm(q * 1.3 + vec3(TIME * 0.015, 0.0, 0.0));
		float lat = p.y + (warp - 0.5) * 0.22;
		float b = sin(lat * bands * 3.14159);
		float fine = fbm(vec3(q.x * 0.6, lat * bands * 2.2, q.z * 0.6));
		albedo = mix(color_low, color_mid, b * 0.5 + 0.5);
		albedo = mix(albedo, color_high, smoothstep(0.45, 0.75, fine) * 0.7);
		vec3 eye_dir = normalize(vec3(0.6, -0.35, 0.72));
		float eye = smoothstep(0.985, 0.995, dot(p, eye_dir) + fbm(q * 3.0) * 0.01);
		albedo = mix(albedo, emission_color, eye * 0.8);
		rough = 0.55;
	} else if (style == 3) {
		// ICE: bright crust with glowing blue fissures.
		float c = ridged(q * 2.2);
		albedo = mix(color_mid, color_high, smoothstep(0.3, 0.7, h));
		float crack = smoothstep(0.72, 0.86, c);
		albedo = mix(albedo, color_low, crack);
		emit = emission_color * crack * emission_strength;
		rough = 0.3;
	} else {
		// LAVA: dark crust, pulsing molten veins and lava seas.
		float c = ridged(q * 1.8 + vec3(0.0, TIME * 0.01, 0.0));
		float crack = smoothstep(0.68, 0.84, c);
		float sea = smoothstep(0.6, 0.66, h);
		float molten = max(crack, sea);
		albedo = mix(color_low, color_mid, smoothstep(0.3, 0.6, h)) * (1.0 - molten * 0.9);
		float pulse = 0.75 + 0.25 * sin(TIME * 1.7 + h * 14.0);
		emit = emission_color * molten * emission_strength * pulse;
		rough = mix(0.95, 0.5, molten);
	}

	if (polar_caps > 0.0) {
		float cap = smoothstep(1.0 - polar_caps, 1.0 - polar_caps + 0.06, abs(p.y) + (h - 0.5) * 0.15);
		albedo = mix(albedo, vec3(0.92, 0.95, 1.0), cap);
		rough = mix(rough, 0.4, cap);
	}

	ALBEDO = albedo;
	ROUGHNESS = rough;
	EMISSION = emit;
}
