shader_type spatial;
// Hot, swirling accretion disk around a black hole, drawn flat in the play plane.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://shaders/noise.gdshaderinc"

// Event horizon edge, as a fraction of the disk radius.
uniform float inner = 0.2;
uniform vec3 hot : source_color = vec3(1.0, 0.78, 0.5);
uniform vec3 warm : source_color = vec3(0.9, 0.22, 0.04);
uniform float energy = 1.5;
uniform float spin = 1.2;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float d = length(c);
	if (d > 1.0 || d < inner * 0.85) {
		discard;
	}
	float a = atan(c.y, c.x);
	// Inner gas orbits faster (Kepler-ish), which shears the streaks into spirals.
	float orbit = a + TIME * spin * 0.25 / pow(max(d, 0.05), 1.5);
	float n = fbm(vec3(cos(orbit) * 2.5, sin(orbit) * 2.5, d * 5.0));
	float rings = 0.85 + 0.15 * sin(d * 45.0 + n * 9.0);
	float temp = pow(clamp((1.0 - d) / (1.0 - inner), 0.0, 1.0), 1.8);
	vec3 col = mix(warm, hot, temp);
	// The side spinning toward the camera is brighter (relativistic beaming).
	float beaming = 1.0 + 0.75 * sin(a);
	float streaks = smoothstep(0.3, 0.8, n);
	float bright = (0.08 + streaks * 1.6) * rings * beaming * (temp * 2.2 + 0.15);
	float edge = smoothstep(inner * 0.95, inner * 1.2, d) * smoothstep(1.0, 0.5, d);
	vec3 photon_ring = hot * 2.5 * exp(-pow((d - inner * 1.08) / 0.012, 2.0));
	ALBEDO = (col * bright * edge + photon_ring) * energy;
}
