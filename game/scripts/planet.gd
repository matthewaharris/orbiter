@tool
class_name Planet
extends AnimatableBody3D
## A gravity body. All visuals are generated from `planet_type`, so one script makes every archetype.
## Gameplay hooks: mass (gravity), radius (collision), environment_force() (drag / wind), orbits.

const SURFACE_SHADER := preload("res://shaders/planet_surface.gdshader")
const CLOUD_SHADER := preload("res://shaders/clouds.gdshader")
const ATMO_SHADER := preload("res://shaders/atmosphere.gdshader")
const RINGS_SHADER := preload("res://shaders/planet_rings.gdshader")

@export var planet_type: PlanetType:
	set(v):
		planet_type = v
		_queue_rebuild()
@export var radius := 3.0:
	set(v):
		radius = v
		_queue_rebuild()
## Gravity strength. Acceleration at distance r is mass / r^2.
@export var mass := 400.0:
	set(v):
		mass = v
		_queue_rebuild()
@export var surface_seed := 1.0:
	set(v):
		surface_seed = v
		_queue_rebuild()
@export var spin_speed := 0.08
@export var axial_tilt_deg := 18.0:
	set(v):
		axial_tilt_deg = v
		_queue_rebuild()
@export var show_gravity_halo := true:
	set(v):
		show_gravity_halo = v
		_queue_rebuild()

@export_group("Orbit")
## Leave empty for a fixed body. Otherwise this body circles the given node.
@export var orbit_center: NodePath
@export var orbit_radius := 0.0
@export var orbit_period := 10.0
@export var orbit_phase_deg := 0.0
@export var orbit_clockwise := false

var _gen: Node3D
var _shape: CollisionShape3D
var _spinner: Node3D
var _clouds_mat: ShaderMaterial
var _orbit_line: MeshInstance3D
var _pulse_particles: GPUParticles3D
var _rebuild_queued := false
var _lightning_timer := 1.5
var _was_pulsing := false


func _ready() -> void:
	add_to_group(&"gravity_sources")
	add_to_group(&"force_sources")
	add_to_group(&"solid")
	_rebuild()
	if is_orbiting():
		_snap_to_orbit.call_deferred()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	if _gen:
		_gen.free()
	if _shape:
		_shape.free()
	_orbit_line = null
	_pulse_particles = null
	_clouds_mat = null
	_gen = Node3D.new()
	_gen.name = "_Generated"
	add_child(_gen)

	# Must be a direct child of the body to count as collision.
	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	_shape.shape = sphere
	add_child(_shape)

	_build_visuals(_gen)

	if show_gravity_halo and mass > 0.0:
		# Dashed ring where gravity pulls at 3 units/s^2: a quick read of "how strong is this well".
		var halo_r := sqrt(mass / 3.0)
		if halo_r > radius * 1.3:
			_gen.add_child(Fx.ring(halo_r, Color(0.5, 0.7, 1.0), 0.18, 0.06, 48.0, 0.004))

	if is_orbiting():
		_orbit_line = Fx.ring(orbit_radius, Color(0.6, 0.75, 1.0), 0.22, 0.05, 90.0, 0.0)
		_orbit_line.top_level = true
		_gen.add_child(_orbit_line)


func _build_visuals(root: Node3D) -> void:
	var t := planet_type if planet_type else PlanetType.new()

	var tilt := Node3D.new()
	tilt.rotation = Vector3(deg_to_rad(axial_tilt_deg), 0.0, deg_to_rad(axial_tilt_deg * 0.5))
	root.add_child(tilt)
	_spinner = Node3D.new()
	tilt.add_child(_spinner)

	var surf_mat := ShaderMaterial.new()
	surf_mat.shader = SURFACE_SHADER
	surf_mat.set_shader_parameter(&"style", int(t.surface))
	surf_mat.set_shader_parameter(&"color_low", t.color_low)
	surf_mat.set_shader_parameter(&"color_mid", t.color_mid)
	surf_mat.set_shader_parameter(&"color_high", t.color_high)
	surf_mat.set_shader_parameter(&"emission_color", t.emission_color)
	surf_mat.set_shader_parameter(&"emission_strength", t.emission_strength)
	surf_mat.set_shader_parameter(&"noise_scale", t.noise_scale)
	surf_mat.set_shader_parameter(&"bands", t.band_count)
	surf_mat.set_shader_parameter(&"polar_caps", t.polar_caps)
	surf_mat.set_shader_parameter(&"seed", surface_seed)
	_spinner.add_child(_sphere(radius, surf_mat))

	if t.cloud_coverage > 0.0:
		_clouds_mat = ShaderMaterial.new()
		_clouds_mat.shader = CLOUD_SHADER
		_clouds_mat.set_shader_parameter(&"cloud_color", t.cloud_color)
		_clouds_mat.set_shader_parameter(&"coverage", t.cloud_coverage)
		_clouds_mat.set_shader_parameter(&"speed", t.cloud_speed)
		_clouds_mat.set_shader_parameter(&"seed", surface_seed * 13.0)
		var clouds := _sphere(radius * 1.025, _clouds_mat)
		clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tilt.add_child(clouds)

	if t.atmosphere_glow > 0.0:
		var atmo_mat := ShaderMaterial.new()
		atmo_mat.shader = ATMO_SHADER
		atmo_mat.set_shader_parameter(&"atmo_color", t.atmosphere_color)
		atmo_mat.set_shader_parameter(&"intensity", t.atmosphere_glow)
		var atmo := _sphere(radius * 1.09, atmo_mat)
		atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(atmo)

	if t.atmosphere_height > 0.0 and t.atmosphere_drag > 0.0:
		root.add_child(Fx.ring(radius + t.atmosphere_height, t.atmosphere_color, 0.25, 0.12))

	if t.rings:
		var rings_mat := ShaderMaterial.new()
		rings_mat.shader = RINGS_SHADER
		rings_mat.set_shader_parameter(&"ring_color", t.ring_color)
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * radius * 4.6
		var rings := MeshInstance3D.new()
		rings.mesh = plane
		rings.material_override = rings_mat
		tilt.add_child(rings)

	if t.embers:
		var p := Fx.make_particles(140, 2.6, 0.28)
		var pm := p.process_material as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
		pm.emission_sphere_radius = radius * 1.02
		pm.spread = 180.0
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 0.8
		pm.radial_accel_min = 0.6
		pm.radial_accel_max = 2.0
		pm.scale_min = 0.5
		pm.scale_max = 1.3
		pm.scale_curve = Fx.shrink_curve()
		pm.color_ramp = Fx.ramp([Color(4, 1.6, 0.4), Color(2, 0.45, 0.08, 0.8), Color(0.3, 0.05, 0.02, 0)])
		root.add_child(p)

	match t.wind:
		PlanetType.Wind.SWIRL:
			# Rotating dashes show which way the winds will carry you.
			var spin := -1.0 if spin_speed < 0.0 else 1.0
			root.add_child(Fx.ring(radius * t.wind_reach * 0.75, t.atmosphere_color, 0.35, 0.1, 14.0, -0.05 * spin))
			root.add_child(Fx.ring(radius * t.wind_reach * 0.5, t.atmosphere_color, 0.25, 0.08, 10.0, -0.08 * spin))
		PlanetType.Wind.PULSE:
			_pulse_particles = Fx.make_particles(260, 1.3, 0.4)
			_pulse_particles.one_shot = true
			_pulse_particles.explosiveness = 0.85
			_pulse_particles.emitting = false
			var pm := _pulse_particles.process_material as ParticleProcessMaterial
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
			pm.emission_sphere_radius = radius
			pm.particle_flag_disable_z = true
			pm.spread = 180.0
			pm.radial_accel_min = 20.0
			pm.radial_accel_max = 40.0
			pm.damping_min = 2.0
			pm.damping_max = 4.0
			pm.color_ramp = Fx.ramp([Color(2.5, 3.5, 4.5), Color(0.6, 1.2, 2.0, 0.6), Color(0.4, 0.7, 1.0, 0)])
			root.add_child(_pulse_particles)
			root.add_child(Fx.ring(radius * t.wind_reach, t.atmosphere_color, 0.2, 0.06, 36.0, 0.0))


func _sphere(r: float, mat: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 96
	m.rings = 48
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	return mi


func _process(delta: float) -> void:
	if _spinner:
		_spinner.rotate_y(spin_speed * delta)
	if _orbit_line:
		_orbit_line.global_position = _orbit_center_pos()
	if Engine.is_editor_hint() or planet_type == null:
		return

	if planet_type.storms and _clouds_mat:
		_lightning_timer -= delta
		if _lightning_timer <= 0.0:
			_lightning_timer = randf_range(0.4, 2.8)
			_flash_lightning()

	if planet_type.wind == PlanetType.Wind.PULSE and _pulse_particles:
		var pulsing := is_pulsing(WorldClock.time)
		if pulsing and not _was_pulsing:
			_pulse_particles.restart()
		_was_pulsing = pulsing


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_orbiting():
		global_position = position_at(WorldClock.time)


func _flash_lightning() -> void:
	var dir := Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(0.3, 1.0)).normalized()
	_clouds_mat.set_shader_parameter(&"flash_dir", dir)
	var tw := create_tween()
	tw.tween_method(_set_flash, 0.0, 1.0, 0.04)
	tw.tween_method(_set_flash, 1.0, 0.2, 0.06)
	tw.tween_method(_set_flash, 0.2, 0.9, 0.04)
	tw.tween_method(_set_flash, 0.9, 0.0, 0.25)


func _set_flash(v: float) -> void:
	if _clouds_mat:
		_clouds_mat.set_shader_parameter(&"flash", v)


# --- Orbits -----------------------------------------------------------------

func is_orbiting() -> bool:
	return orbit_radius > 0.0 and not orbit_center.is_empty() and has_node(orbit_center)


func _orbit_center_pos() -> Vector3:
	var c := get_node_or_null(orbit_center) as Node3D
	return c.global_position if c else global_position


func position_at(t: float) -> Vector3:
	var dir := -1.0 if orbit_clockwise else 1.0
	var a := deg_to_rad(orbit_phase_deg) + dir * TAU * t / maxf(orbit_period, 0.01)
	return _orbit_center_pos() + Vector3(cos(a), sin(a), 0.0) * orbit_radius


func _snap_to_orbit() -> void:
	global_position = position_at(0.0)


# --- Environment forces (not shown by the aim preview) -----------------------

func is_pulsing(t: float) -> bool:
	if planet_type == null or planet_type.wind != PlanetType.Wind.PULSE:
		return false
	return fposmod(t + surface_seed, planet_type.pulse_period) < planet_type.pulse_duration


## Non-gravity force on the ship: atmospheric drag and wind. Heavier ships feel it less.
func environment_force(pos: Vector3, vel: Vector3, t: float) -> Vector3:
	var pt := planet_type
	if pt == null:
		return Vector3.ZERO
	var d := pos - global_position
	var dist := d.length()
	if dist < 0.001:
		return Vector3.ZERO
	var f := Vector3.ZERO

	if pt.atmosphere_height > 0.0 and pt.atmosphere_drag > 0.0:
		var alt := dist - radius
		if alt < pt.atmosphere_height:
			var density := 1.0 - clampf(alt / pt.atmosphere_height, 0.0, 1.0)
			f -= vel * pt.atmosphere_drag * density * density

	var reach := radius * pt.wind_reach
	if dist < reach:
		var falloff := 1.0 - dist / reach
		match pt.wind:
			PlanetType.Wind.SWIRL:
				var spin := -1.0 if spin_speed < 0.0 else 1.0
				f += Vector3(-d.y, d.x, 0.0).normalized() * spin * pt.wind_strength * falloff
			PlanetType.Wind.PULSE:
				if is_pulsing(t):
					f += d / dist * pt.wind_strength * falloff
	return f
