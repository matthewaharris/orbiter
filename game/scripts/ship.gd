class_name Ship
extends RigidBody3D
## The player's craft. Godot physics moves it; we add gravity + environment forces each tick.
## Motion is locked to the Z=0 plane; the 3D model banks and turns for the chase cam.

signal crashed(at: Vector3, body: Node3D)

const MODEL := preload("res://assets/models/ship.glb")
const MODEL_SCALE := 0.75

var launched := false
var visual: Node3D
var _model: Node3D
var _trail: GPUParticles3D
var _engine_light: OmniLight3D
var _pending_velocity := Vector3.ZERO
var _has_pending := false
var _pending_dv := Vector3.ZERO
var _pending_origin := Vector3.ZERO
var _has_origin := false
## Velocities from the last few physics steps. The contact signal can arrive a step after the
## solver has already killed our speed, so deflect() looks back for the true impact velocity.
var _recent_velocities: Array[Vector3] = []
var _roll := 0.0
var _last_heading := Vector3.RIGHT


func _ready() -> void:
	mass = Game.ship_mass
	gravity_scale = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	body_entered.connect(_on_body_entered)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	shape.shape = sphere
	add_child(shape)

	visual = Node3D.new()
	add_child(visual)
	_model = MODEL.instantiate()
	_model.scale = Vector3.ONE * MODEL_SCALE
	visual.add_child(_model)

	_engine_light = OmniLight3D.new()
	_engine_light.light_color = Color(0.4, 0.7, 1.0)
	_engine_light.light_energy = 1.5
	_engine_light.omni_range = 4.0
	_engine_light.position = Vector3(0, 0, 1.3) * MODEL_SCALE
	visual.add_child(_engine_light)

	# World-space particle trail from the main engine.
	_trail = Fx.make_particles(400, 1.4, 0.16)
	_trail.local_coords = false
	_trail.emitting = false
	_trail.position = Vector3(0, 0, 1.15) * MODEL_SCALE
	var pm := _trail.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 8.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.5
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.scale_curve = Fx.shrink_curve()
	pm.color_ramp = Fx.ramp([Color(0.8, 1.6, 2.6), Color(0.5, 0.35, 1.8, 0.6), Color(0.3, 0.15, 0.8, 0.0)])
	visual.add_child(_trail)

	face(Vector3.RIGHT)


## Point the model along `dir` (in the play plane) with its canopy toward the tactical camera.
func face(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	visual.basis = Basis.looking_at(dir.normalized(), Vector3(0, 0, 1))
	visual.rotate_object_local(Vector3.FORWARD, _roll)
	_last_heading = dir.normalized()


## Visual-only pullback while aiming, like a drawn slingshot.
func set_pullback(offset: Vector3) -> void:
	visual.position = offset


func launch(velocity: Vector3) -> void:
	visual.position = Vector3.ZERO
	freeze = false
	_pending_velocity = velocity
	_has_pending = true
	launched = true
	_trail.emitting = true
	face(velocity)


## Instant change in velocity (Kick Booster).
func boost(dv: Vector3) -> void:
	_pending_dv += dv
	_engine_light.light_energy = 8.0


## Bounce off a round body centered at `center` (Deflector Shield).
func deflect(center: Vector3, body_radius: float) -> void:
	var n := global_position - center
	n.z = 0.0
	n = n.normalized()
	var v := linear_velocity
	for rv in _recent_velocities:
		if rv.dot(n) < v.dot(n):
			v = rv
	var vn := v.dot(n)
	if vn < 0.0:
		v -= 2.0 * vn * n
	v *= 0.85
	# Always leave with some outward speed so we don't grind along the surface.
	v += n * maxf(0.0, 4.0 - v.dot(n))
	_pending_velocity = v
	_has_pending = true
	_recent_velocities.clear()
	# Lift clear of the surface so the contact ends instead of re-triggering.
	_pending_origin = center + n * (body_radius + 0.6)
	_has_origin = true


func stop() -> void:
	launched = false
	_trail.emitting = false
	set_deferred(&"freeze", true)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _has_pending:
		state.linear_velocity = _pending_velocity
		_has_pending = false
	if _has_origin:
		state.transform.origin = _pending_origin
		_has_origin = false
	if _pending_dv != Vector3.ZERO:
		state.linear_velocity += _pending_dv
		_pending_dv = Vector3.ZERO
	_recent_velocities.push_back(state.linear_velocity)
	if _recent_velocities.size() > 6:
		_recent_velocities.pop_front()
	if not launched:
		return
	var pos := state.transform.origin
	var vel := state.linear_velocity
	var t := WorldClock.time
	var force := Gravity.acceleration(pos, Gravity.snapshot(get_tree())) * mass
	var weather := Vector3.ZERO
	for n in get_tree().get_nodes_in_group(&"force_sources"):
		weather += (n as Planet).environment_force(pos, vel, t)
	force += weather * Game.run.weather_resist
	force.z = 0.0
	state.apply_central_force(force)


func _process(delta: float) -> void:
	if not launched:
		return
	var vel := linear_velocity
	if vel.length_squared() < 0.01:
		return
	var heading := vel.normalized()
	# Bank into turns: signed turn rate around the camera axis.
	var turn := _last_heading.cross(heading).z / maxf(delta, 0.0001)
	_roll = lerpf(_roll, clampf(-turn * 0.35, -1.0, 1.0), 1.0 - exp(-delta * 4.0))
	face(heading)
	var idle := 1.2 + sin(Time.get_ticks_msec() * 0.03) * 0.3
	_engine_light.light_energy = lerpf(_engine_light.light_energy, idle, 1.0 - exp(-delta * 6.0))


func _on_body_entered(body: Node) -> void:
	if launched and body.is_in_group(&"solid"):
		crashed.emit(global_position, body as Node3D)
