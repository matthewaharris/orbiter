@tool
class_name Star
extends Planet
## A star: gravity, light, a gusty solar wind, and periodic coronal mass ejections (CMEs).
## A CME charges up (the star brightens), then fires a shock ring that kicks the ship outward.

const STAR_SHADER := preload("res://shaders/star_surface.gdshader")
const CORONA_SHADER := preload("res://shaders/corona.gdshader")

@export var color_core := Color(1.0, 0.92, 0.7):
	set(v):
		color_core = v
		_queue_rebuild()
@export var color_edge := Color(1.0, 0.5, 0.15):
	set(v):
		color_edge = v
		_queue_rebuild()
@export var light_energy := 5.0
@export var light_range := 150.0

@export_group("Space Weather")
## Outward push at 10 units from the star; gusts vary it unpredictably.
@export var solar_wind := 1.5
## Seconds between CMEs. 0 disables them.
@export var cme_period := 0.0
@export var cme_charge_time := 2.5
@export var cme_speed := 14.0
@export var cme_strength := 25.0
@export var cme_band := 1.6
@export var cme_offset := 0.0
@export var cme_max_radius := 75.0

var _surface_mat: ShaderMaterial
var _corona_mat: ShaderMaterial
var _light: OmniLight3D
var _wind_particles: GPUParticles3D
var _burst_particles: GPUParticles3D
var _wave: MeshInstance3D
var _wave_mat: ShaderMaterial
var _gust := FastNoiseLite.new()
var _last_cycle := -1


func _ready() -> void:
	super()
	add_to_group(&"stars")
	_gust.seed = int(surface_seed * 1000.0)
	_gust.frequency = 0.5


func _build_visuals(root: Node3D) -> void:
	_spinner = Node3D.new()
	root.add_child(_spinner)

	_surface_mat = ShaderMaterial.new()
	_surface_mat.shader = STAR_SHADER
	_surface_mat.set_shader_parameter(&"color_core", color_core)
	_surface_mat.set_shader_parameter(&"color_edge", color_edge)
	var surf := _sphere(radius, _surface_mat)
	surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spinner.add_child(surf)

	_corona_mat = ShaderMaterial.new()
	_corona_mat.shader = CORONA_SHADER
	_corona_mat.set_shader_parameter(&"color", color_edge.lerp(color_core, 0.3))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 7.0
	var corona := MeshInstance3D.new()
	corona.mesh = quad
	corona.material_override = _corona_mat
	corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(corona)

	_light = OmniLight3D.new()
	_light.light_color = color_core.lerp(color_edge, 0.35)
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.omni_attenuation = 0.6
	_light.shadow_enabled = true
	root.add_child(_light)

	# Solar wind: streams of glowing particles flowing outward in the play plane.
	_wind_particles = Fx.make_particles(420, 6.0, 0.22)
	var pm := _wind_particles.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = radius * 1.1
	pm.particle_flag_disable_z = true
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.radial_accel_min = 1.0
	pm.radial_accel_max = 2.5
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var wc := color_edge.lerp(color_core, 0.5)
	pm.color_ramp = Fx.ramp([Color(wc * 2.5, 0.0), Color(wc * 2.0, 0.6), Color(wc, 0.25), Color(wc, 0.0)])
	root.add_child(_wind_particles)

	_burst_particles = Fx.make_particles(500, 2.2, 0.55)
	_burst_particles.one_shot = true
	_burst_particles.explosiveness = 0.9
	_burst_particles.emitting = false
	var bm := _burst_particles.process_material as ParticleProcessMaterial
	bm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	bm.emission_sphere_radius = radius
	bm.particle_flag_disable_z = true
	bm.spread = 180.0
	bm.radial_accel_min = cme_speed * 2.0
	bm.radial_accel_max = cme_speed * 3.0
	bm.initial_velocity_min = cme_speed * 0.6
	bm.initial_velocity_max = cme_speed
	bm.scale_curve = Fx.shrink_curve()
	bm.color_ramp = Fx.ramp([Color(color_core * 6.0), Color(color_edge * 3.0), Color(color_edge, 0.0)])
	root.add_child(_burst_particles)

	_wave = Fx.ring(1.0, color_edge.lerp(color_core, 0.5), 1.0, 0.05)
	_wave_mat = _wave.material_override as ShaderMaterial
	_wave.top_level = true
	_wave.visible = false
	root.add_child(_wave)


# --- CME schedule (driven by WorldClock so it's learnable) -----------------------

func has_cmes() -> bool:
	return cme_period > 0.0


func _cycle_time(t: float) -> float:
	return fposmod(t + cme_offset, cme_period)


func time_to_cme(t: float) -> float:
	return cme_period - _cycle_time(t) if has_cmes() else INF


func charge_level(t: float) -> float:
	if not has_cmes():
		return 0.0
	var ttc := time_to_cme(t)
	return clampf(1.0 - ttc / cme_charge_time, 0.0, 1.0) if ttc < cme_charge_time else 0.0


## Radius of the most recent shock wave, or -1 if none is in flight.
func wave_radius(t: float) -> float:
	if not has_cmes() or t + cme_offset < cme_period:
		return -1.0
	var r := radius + _cycle_time(t) * cme_speed
	return r if r < cme_max_radius else -1.0


func gust(t: float) -> float:
	return 1.0 + 0.8 * _gust.get_noise_1d(t)


func environment_force(pos: Vector3, _vel: Vector3, t: float) -> Vector3:
	var d := pos - global_position
	var dist := d.length()
	if dist < 0.001:
		return Vector3.ZERO
	var dir := d / dist
	var f := dir * solar_wind * gust(t) * 10.0 / maxf(dist, radius * 2.0)
	var wr := wave_radius(t)
	if wr > 0.0 and absf(dist - wr) < cme_band:
		f += dir * cme_strength
	return f


func _process(delta: float) -> void:
	super(delta)
	if _wave:
		_wave.global_position = global_position
	if Engine.is_editor_hint():
		return
	var t := WorldClock.time
	var charge := charge_level(t)
	_surface_mat.set_shader_parameter(&"charge", charge)
	_corona_mat.set_shader_parameter(&"charge", charge)
	_light.light_energy = light_energy * (1.0 + charge * 1.5)
	_wind_particles.speed_scale = clampf(gust(t), 0.3, 2.0)

	if has_cmes():
		var cycle := int(floor((t + cme_offset) / cme_period))
		if cycle != _last_cycle:
			if _last_cycle >= 0 or t > 0.5:
				_burst_particles.restart()
			_last_cycle = cycle
		var wr := wave_radius(t)
		_wave.visible = wr > 0.0
		if wr > 0.0:
			_wave.scale = Vector3.ONE * wr
			_wave_mat.set_shader_parameter(&"thickness", cme_band / (wr / 0.95) * 0.6)
			_wave_mat.set_shader_parameter(&"alpha", 1.4 * (1.0 - wr / cme_max_radius))
