class_name DotPath
extends MultiMeshInstance3D
## Draws a path as glowing dots: used for the aim preview and the ghost of your last attempt.

const MAX_DOTS := 400

var color_start := Color(1, 1, 1, 1)
var color_end := Color(1, 1, 1, 0)


func _init(dot_radius := 0.09) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = dot_radius
	sphere.height = dot_radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	sphere.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = sphere
	multimesh.instance_count = MAX_DOTS
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_points(points: PackedVector3Array, end_color := Color(-1, 0, 0)) -> void:
	var n := mini(points.size(), MAX_DOTS)
	var tail := color_end if end_color.r < 0.0 else end_color
	for i in n:
		multimesh.set_instance_transform(i, Transform3D(Basis(), points[i]))
		var t := float(i) / maxf(n - 1, 1)
		multimesh.set_instance_color(i, color_start.lerp(tail, t))
	multimesh.visible_instance_count = n


func clear() -> void:
	multimesh.visible_instance_count = 0
