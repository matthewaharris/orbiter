class_name Fx
## Factory helpers for particles and flat ring effects, so scripts stay readable.

const RING_SHADER := preload("res://shaders/ring_fx.gdshader")

static var _soft_tex: Texture2D


static func soft_texture() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_soft_tex = t
	return _soft_tex


## Evenly spaced HDR color ramp (colors may exceed 1.0 to drive bloom).
static func ramp(colors: Array[Color]) -> GradientTexture1D:
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / max(colors.size() - 1, 1))
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	t.use_hdr = true
	return t


static func shrink_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var t := CurveTexture.new()
	t.curve = c
	return t


static func make_particles(amount: int, lifetime: float, size: float, additive := true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_texture()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = m
	p.draw_pass_1 = q
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	p.visibility_aabb = AABB(Vector3(-120, -120, -120), Vector3(240, 240, 240))
	return p


## A flat ring drawn on a quad in the gameplay (XY) plane.
## `radius` is in world units; `thickness` is in world units too.
static func ring(radius: float, color: Color, alpha := 0.5, thickness := 0.08, dashes := 0.0,
		dash_speed := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	var size := radius * 2.0 / 0.95
	q.size = Vector2(size, size)
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = RING_SHADER
	mat.set_shader_parameter(&"color", color)
	mat.set_shader_parameter(&"alpha", alpha)
	mat.set_shader_parameter(&"ring_pos", 0.95)
	mat.set_shader_parameter(&"thickness", thickness / (size * 0.5))
	mat.set_shader_parameter(&"dashes", dashes)
	mat.set_shader_parameter(&"dash_speed", dash_speed)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func explosion(parent: Node, pos: Vector3, color := Color(1.0, 0.5, 0.15)) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos

	var fire := make_particles(220, 1.6, 0.45)
	fire.one_shot = true
	fire.explosiveness = 0.95
	var pm := fire.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 180.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 16.0
	pm.damping_min = 4.0
	pm.damping_max = 9.0
	pm.scale_min = 0.4
	pm.scale_max = 2.2
	pm.scale_curve = shrink_curve()
	pm.color_ramp = ramp([Color(3, 2.2, 1.4), color * 2.5, Color(0.6, 0.25, 0.1, 0.7), Color(0.1, 0.1, 0.12, 0)])
	root.add_child(fire)
	fire.emitting = true

	var sparks := make_particles(80, 1.0, 0.18)
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	var sm := sparks.process_material as ParticleProcessMaterial
	sm.direction = Vector3(0, 0, 1)
	sm.spread = 180.0
	sm.initial_velocity_min = 12.0
	sm.initial_velocity_max = 28.0
	sm.damping_min = 6.0
	sm.damping_max = 10.0
	sm.color_ramp = ramp([Color(8, 6, 3), Color(3, 1, 0.2), Color(1, 0.2, 0, 0)])
	root.add_child(sparks)
	sparks.emitting = true

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 12.0
	light.omni_range = 18.0
	root.add_child(light)
	root.create_tween().tween_property(light, "light_energy", 0.0, 0.7)
	root.get_tree().create_timer(3.0).timeout.connect(root.queue_free)


static func burst(parent: Node, pos: Vector3, color: Color, amount := 160, speed := 10.0) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var p := make_particles(amount, 1.4, 0.35)
	p.one_shot = true
	p.explosiveness = 1.0
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.damping_min = 3.0
	pm.damping_max = 6.0
	pm.scale_curve = shrink_curve()
	pm.color_ramp = ramp([color * 5.0, color * 2.0, Color(color, 0.0)])
	root.add_child(p)
	p.emitting = true
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 8.0
	light.omni_range = 16.0
	root.add_child(light)
	root.create_tween().tween_property(light, "light_energy", 0.0, 1.0)
	root.get_tree().create_timer(2.5).timeout.connect(root.queue_free)
