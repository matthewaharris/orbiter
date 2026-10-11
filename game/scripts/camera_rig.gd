class_name CameraRig
extends Node3D
## Two views of the same flight: a tactical overhead camera and a 3D chase cam.

var tactical: Camera3D
var chase: Camera3D
var chase_mode := false
var target: Ship
## Where the chase cam looks while the ship is still on the pad.
var aim_dir := Vector3.RIGHT
var _fwd := Vector3.RIGHT
var _shake := 0.0


func _ready() -> void:
	tactical = Camera3D.new()
	tactical.fov = 40.0
	tactical.far = 4000.0
	add_child(tactical)
	chase = Camera3D.new()
	chase.fov = 72.0
	chase.near = 0.05
	chase.far = 4000.0
	add_child(chase)
	tactical.make_current()


func setup(level: Level) -> void:
	tactical.position = Vector3(level.camera_center.x, level.camera_center.y, level.camera_height)
	tactical.rotation = Vector3.ZERO
	_snap_chase()


func toggle() -> void:
	chase_mode = not chase_mode
	(chase if chase_mode else tactical).make_current()
	_snap_chase()


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func active_camera() -> Camera3D:
	return chase if chase_mode else tactical


func _desired_forward() -> Vector3:
	if target and target.launched and target.linear_velocity.length_squared() > 0.5:
		return target.linear_velocity.normalized()
	return aim_dir


func _snap_chase() -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	_fwd = _desired_forward()
	chase.global_position = target.global_position - _fwd * 7.0 + Vector3(0, 0, 2.4)
	chase.look_at(target.global_position + _fwd * 5.0, Vector3(0, 0, 1))


func _process(delta: float) -> void:
	if is_instance_valid(target) and target.is_inside_tree():
		_fwd = _fwd.slerp(_desired_forward(), 1.0 - exp(-delta * 3.0)).normalized()
		var desired := target.global_position - _fwd * 7.0 + Vector3(0, 0, 2.4)
		chase.global_position = chase.global_position.lerp(desired, 1.0 - exp(-delta * 8.0))
		chase.look_at(target.global_position + _fwd * 5.0, Vector3(0, 0, 1))

	if _shake > 0.0:
		var cam := active_camera()
		cam.h_offset = randf_range(-1, 1) * _shake
		cam.v_offset = randf_range(-1, 1) * _shake
		_shake = maxf(0.0, _shake - delta * 2.5)
		if _shake == 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
