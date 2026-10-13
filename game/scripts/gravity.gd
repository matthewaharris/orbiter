class_name Gravity
## Gravity math shared by the live ship and the aim preview / level solver.
## Acceleration from a body = mass / r^2 (G folded into mass).

const SOFTENING := 0.25


## A frozen copy of every gravity source: [{pos, mass, radius, node}].
## Any Node3D in the "gravity_sources" group with `mass` and `radius` vars counts (Planet, BlackHole).
static func snapshot(tree: SceneTree) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in tree.get_nodes_in_group(&"gravity_sources"):
		var body := n as Node3D
		if body == null or not body.is_inside_tree():
			continue
		out.append({pos = body.global_position, mass = float(body.get(&"mass")),
			radius = float(body.get(&"radius")), node = body})
	return out


static func acceleration(pos: Vector3, bodies: Array[Dictionary]) -> Vector3:
	var acc := Vector3.ZERO
	for b in bodies:
		var d: Vector3 = b.pos - pos
		var r2 := d.length_squared() + SOFTENING
		acc += d * (b.mass / (r2 * sqrt(r2)))
	return acc


## Integrates a ballistic path through static gravity (no wind / flares).
## Returns {points: PackedVector3Array, result: "open"|"crash"|"portal"|"lost", time: float}.
static func simulate(start: Vector3, velocity: Vector3, bodies: Array[Dictionary], duration: float,
		dt: float, portal_pos: Vector3, portal_radius: float, bounds: Rect2,
		sample_every := 6, ship_radius := 0.45) -> Dictionary:
	var points := PackedVector3Array()
	var pos := start
	var vel := velocity
	var steps := int(duration / dt)
	for i in steps:
		vel += acceleration(pos, bodies) * dt
		pos += vel * dt
		if i % sample_every == 0:
			points.append(pos)
		for b in bodies:
			var rr: float = b.radius + ship_radius
			if pos.distance_squared_to(b.pos) < rr * rr:
				points.append(pos)
				return {points = points, result = "crash", time = i * dt}
		if pos.distance_squared_to(portal_pos) < portal_radius * portal_radius:
			points.append(pos)
			return {points = points, result = "portal", time = i * dt}
		if not bounds.has_point(Vector2(pos.x, pos.y)):
			return {points = points, result = "lost", time = i * dt}
	return {points = points, result = "open", time = duration}
