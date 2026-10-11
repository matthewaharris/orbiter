shader_type spatial;
// Flat ring on a quad: orbit paths, gravity halos, wind arrows, and CME shock waves.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

uniform vec3 color : source_color = vec3(1.0);
uniform float alpha = 0.5;
uniform float ring_pos = 0.95;
uniform float thickness = 0.02;
uniform float dashes = 0.0;
uniform float dash_speed = 0.0;
uniform float fill = 0.0;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float d = length(c);
	float ring = 1.0 - smoothstep(0.0, thickness, abs(d - ring_pos));
	if (dashes > 0.0) {
		float a = atan(c.y, c.x) / 6.2831853 + TIME * dash_speed;
		float seg = fract(a * dashes);
		ring *= smoothstep(0.0, 0.08, seg) * smoothstep(0.6, 0.45, seg);
	}
	float inner = fill * smoothstep(0.0, ring_pos, d) * step(d, ring_pos);
	ALBEDO = color * (ring + inner) * alpha;
}
