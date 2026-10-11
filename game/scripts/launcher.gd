@tool
class_name Launcher
extends Node3D
## The slingshot: a pad with two prongs and an elastic band that stretches as you pull back.

const BAND_COLOR := Color(1.0, 0.45, 0.1)

var _prongs: Node3D
var _tips: Array[Node3D] = []
var _bands: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group(&"launcher")

	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.12, 0.13, 0.16)
	pad_mat.metallic = 0.9
	pad_mat.roughness = 0.3
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = BAND_COLOR
	glow_mat.emission_enabled = true
	glow_mat.emission = BAND_COLOR
	glow_mat.emission_energy_multiplier = 3.0

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.25
	ring.mesh = torus
	ring.material_override = glow_mat
	ring.rotation.x = PI / 2
	ring.position.z = -0.6
	add_child(ring)
	add_child(Fx.ring(2.2, BAND_COLOR, 0.35, 0.05, 24.0, 0.03))

	_prongs = Node3D.new()
	add_child(_prongs)
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.12
		cyl.height = 1.6
		post.mesh = cyl
		post.material_override = pad_mat
		# Prongs stand on either side of the launch line, leaning forward.
		post.position = Vector3(0.6, side * 1.0, 0)
		post.rotation = Vector3(0, 0, -side * 0.5)
		_prongs.add_child(post)
		var tip := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.15
		s.height = 0.3
		tip.mesh = s
		tip.material_override = glow_mat
		tip.position = Vector3(1.0, side * 1.35, 0)
		_prongs.add_child(tip)
		_tips.append(tip)

		var band := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.035
		bc.bottom_radius = 0.035
		bc.height = 1.0
		band.mesh = bc
		band.material_override = glow_mat
		add_child(band)
		_bands.append(band)

	set_aim(Vector3.RIGHT, 0.0, Vector3.ZERO)


## dir: launch direction; pull: ship's visual offset from the pad (world space delta).
func set_aim(dir: Vector3, _power: float, pull: Vector3) -> void:
	_prongs.rotation.z = atan2(dir.y, dir.x)
	var anchor := global_position + pull - dir.normalized() * 0.5
	for i in _tips.size():
		_stretch(_bands[i], _tips[i].global_position, anchor)


func set_bands_visible(v: bool) -> void:
	for b in _bands:
		b.visible = v


func _stretch(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.001:
		return
	var y := d / length
	var x := y.cross(Vector3(0, 0, 1))
	if x.length_squared() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x, y * length, z), (a + b) * 0.5)
