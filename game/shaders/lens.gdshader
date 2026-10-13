shader_type spatial;
// Gravitational lensing: a camera-facing quad that bends the scene behind a black hole
// and blacks out everything inside the event horizon.
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// Event horizon radius as a fraction of the quad's half-width.
uniform float horizon = 0.14;
// Einstein radius (same units): how hard the light bends.
uniform float einstein = 0.3;

void vertex() {
	// Billboard, keeping the node's scale so the spawn animation still works.
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float d = length(c);
	if (d > 1.0) {
		discard;
	}
	vec2 dir = c / max(d, 1e-4);
	float fade = smoothstep(1.0, 0.4, d);
	// Light we see at radius d comes from closer in: beta = theta - E^2 / theta.
	vec2 dc = -dir * (einstein * einstein / max(d, horizon)) * fade;
	// Convert the offset from quad UV space to screen UV space with the pixel Jacobians.
	mat2 juv = mat2(dFdx(UV), dFdy(UV));
	mat2 jsc = mat2(dFdx(SCREEN_UV), dFdy(SCREEN_UV));
	vec2 dscreen = jsc * inverse(juv) * (dc * 0.5);
	vec3 col = textureLod(screen_tex, SCREEN_UV + dscreen, 0.0).rgb;
	float outside = smoothstep(horizon, horizon * 1.3, d);
	ALBEDO = col * outside;
	ALPHA = 1.0;
}
