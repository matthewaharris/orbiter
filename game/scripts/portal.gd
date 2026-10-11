@tool
class_name Portal
extends Area3D
## The exit. Fly the ship into it to clear the level.

signal ship_entered

const MODEL := preload("res://assets/models/portal.glb")
const SWIRL_SHADER := preload("res://shaders/portal_swirl.gdshader")

@export var capture_radius := 1.4

var _ring: Node3D
var _swirl: MeshInstance3D


func _ready() -> void:
	add_to_group(&"portal")
	monitoring = true
	body_entered.connect(_on_body_entered)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = capture_radius
	shape.shape = sphere
	add_child(shape)

	_ring = MODEL.instantiate()
	add_child(_ring)

	var mat := ShaderMaterial.new()
	mat.shader = SWIRL_SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.7
	_swirl = MeshInstance3D.new()
	_swirl.mesh = quad
	_swirl.material_override = mat
	add_child(_swirl)

	var p := Fx.make_particles(160, 1.6, 0.25)
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 0, 1)
	pm.emission_ring_radius = 2.6
	pm.emission_ring_inner_radius = 2.0
	pm.emission_ring_height = 0.1
	pm.radial_accel_min = -3.0
	pm.radial_accel_max = -1.5
	pm.scale_curve = Fx.shrink_curve()
	pm.color_ramp = Fx.ramp([Color(0.6, 0.3, 2.0, 0.0), Color(1.2, 0.6, 4.0), Color(0.3, 2.0, 3.0, 0.0)])
	add_child(p)

	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.4, 1.0)
	light.light_energy = 3.0
	light.omni_range = 10.0
	add_child(light)


func _process(delta: float) -> void:
	if _ring:
		_ring.rotate_object_local(Vector3(0, 0, 1), delta * 0.4)


func _on_body_entered(body: Node) -> void:
	if body is Ship and (body as Ship).launched:
		ship_entered.emit()
