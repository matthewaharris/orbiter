class_name BlackHole
extends AnimatableBody3D
## A singularity: pure gravity with no surface. It bends the aim preview like any planet,
## and touching the event horizon destroys the ship (deflectors can't save you).
## Placed by the player with the Singularity Seed upgrade.

const DISK_SHADER := preload("res://shaders/accretion_disk.gdshader")
const LENS_SHADER := preload("res://shaders/lens.gdshader")

## Read by Gravity.snapshot(): same fields as Planet.
var mass := 240.0
## Event horizon radius (collision).
var radius := 0.6
## The dark "shadow" you see is bigger than the horizon itself.
const SHADOW := 1.6

var _swirl: Node3D
var _light: OmniLight3D
var _shape: CollisionShape3D


func _ready() -> void:
	add_to_group(&"gravity_sources")
	add_to_group(&"solid")
	add_to_group(&"black_holes")

	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	_shape.shape = sphere
	add_child(_shape)

	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius * SHADOW
	sm.height = radius * SHADOW * 2.0
	core.mesh = sm
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	core.material_override = black
	add_child(core)

	# Lensing quad (billboarded in the shader): bends whatever is behind the hole.
	var lens := MeshInstance3D.new()
	var lq := QuadMesh.new()
	lq.size = Vector2.ONE * radius * 14.0
	lens.mesh = lq
	var lens_mat := ShaderMaterial.new()
	lens_mat.shader = LENS_SHADER
	lens_mat.render_priority = -1
	lens_mat.set_shader_parameter(&"horizon", SHADOW / 7.0)
	lens.material_override = lens_mat
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lens)

	var disk := MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2.ONE * radius * 11.0
	disk.mesh = dq
	var disk_mat := ShaderMaterial.new()
	disk_mat.shader = DISK_SHADER
	disk_mat.render_priority = 1
	disk_mat.set_shader_parameter(&"inner", SHADOW * 1.1 / 5.5)
	disk.material_override = disk_mat
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disk)

	# Gas spiralling in: particles live in a rotating frame and fall toward the center.
	_swirl = Node3D.new()
	add_child(_swirl)
	var p := Fx.make_particles(280, 2.0, 0.14)
	p.local_coords = true
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 0, 1)
	pm.emission_ring_radius = radius * 7.0
	pm.emission_ring_inner_radius = radius * 3.0
	pm.emission_ring_height = 0.05
	pm.radial_accel_min = -5.0
	pm.radial_accel_max = -2.5
	pm.scale_curve = Fx.shrink_curve()
	pm.color_ramp = Fx.ramp([Color(1.0, 0.35, 0.1, 0.0), Color(2.5, 1.2, 0.5), Color(4.0, 3.0, 2.2, 0.0)])
	_swirl.add_child(p)

	# Dashed halo where gravity pulls at 3 units/s^2, matching the planets.
	add_child(Fx.ring(sqrt(mass / 3.0), Color(0.8, 0.5, 1.0), 0.22, 0.06, 40.0, -0.01))

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.25)
	_light.light_energy = 2.0
	_light.omni_range = 9.0
	add_child(_light)

	scale = Vector3.ONE * 0.05
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(get_parent(), global_position, Color(0.7, 0.35, 1.0), 120, 9.0)


func _process(delta: float) -> void:
	_swirl.rotate_z(delta * 1.6)
	_light.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.004) * 0.4


## Remove from play right away, then shrink out of existence.
func collapse() -> void:
	remove_from_group(&"gravity_sources")
	remove_from_group(&"solid")
	remove_from_group(&"black_holes")
	_shape.set_deferred(&"disabled", true)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
