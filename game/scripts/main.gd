extends Node3D
## Game controller: loads levels, handles aiming / launch / outcomes, and drives the HUD.
##
## Command-line helpers (after `--` when launching Godot):
##   --level=3            start on a level (1-based)
##   --aim=35,0.62        preset angle (deg) and power
##   --launch-at=1.5      auto-launch after N seconds
##   --chase              start in chase cam
##   --no-preview         start with the preview off
##   --shot=path.png      save a screenshot, then quit (use --shot-delay=seconds)
##   --solve              brute-force every level with the static-gravity sim and print solvability

enum State { AIMING, FLYING, ENDED }

const PREVIEW_DT := 1.0 / 120.0

@onready var level_root: Node3D = $LevelRoot
@onready var cam_rig: CameraRig = $CameraRig
@onready var sun: DirectionalLight3D = $Sun

var hud: Hud
var level: Level
var ship: Ship
var preview: DotPath
var ghost: DotPath
var state := State.AIMING
var aim_angle := 0.0
var aim_power := 0.6
var dragging := false
var flight_time := 0.0
var attempts := 0
var won := false
var _flight_points := PackedVector3Array()
var _sample_timer := 0.0
var _args := {}


func _ready() -> void:
	_parse_args()
	sun.look_at_from_position(Vector3(-30, 25, 40), Vector3.ZERO, Vector3.UP)

	hud = Hud.new()
	add_child(hud)
	preview = DotPath.new(0.1)
	preview.color_start = Color(1.0, 0.75, 0.35, 0.95)
	preview.color_end = Color(1.0, 0.45, 0.1, 0.0)
	add_child(preview)
	ghost = DotPath.new(0.06)
	ghost.color_start = Color(0.5, 0.75, 1.0, 0.5)
	ghost.color_end = Color(0.5, 0.75, 1.0, 0.15)
	add_child(ghost)

	if _args.has("solve"):
		_solve_all()
		return
	if _args.has("level"):
		Game.level_index = clampi(int(_args.level) - 1, 0, Game.LEVELS.size() - 1)
	if _args.has("no-preview"):
		Game.preview_enabled = false
	load_level(Game.level_index)
	if _args.has("aim"):
		var parts: PackedStringArray = str(_args.aim).split(",")
		aim_angle = deg_to_rad(float(parts[0]))
		if parts.size() > 1:
			aim_power = float(parts[1])
		_update_aim_visuals()
	if _args.has("chase"):
		cam_rig.toggle()
	if _args.has("launch-at"):
		get_tree().create_timer(float(_args["launch-at"])).timeout.connect(_launch)
	if _args.has("shot"):
		_screenshot_after(float(_args.get("shot-delay", "2.0")), str(_args.shot))


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"


# --- Level flow ------------------------------------------------------------------

func load_level(index: int) -> void:
	for c in level_root.get_children():
		level_root.remove_child(c)
		c.queue_free()
	ship = null
	won = false
	WorldClock.time = 0.0
	Game.level_index = index
	level = (load(Game.LEVELS[index]) as PackedScene).instantiate()
	level_root.add_child(level)
	sun.visible = level.use_sun
	aim_angle = deg_to_rad(level.default_aim_deg)
	aim_power = level.default_power
	attempts = 0
	ghost.clear()
	cam_rig.setup(level)
	level.portal().ship_entered.connect(_on_portal)
	hud.set_level(index, Game.LEVELS.size(), level)
	_spawn_ship()


func _spawn_ship() -> void:
	if is_instance_valid(ship):
		ship.get_parent().remove_child(ship)
		ship.queue_free()
	ship = Ship.new()
	level.add_child(ship)
	ship.global_position = level.launcher().global_position
	ship.crashed.connect(_on_crashed)
	cam_rig.target = ship
	state = State.AIMING
	flight_time = 0.0
	level.launcher().set_bands_visible(true)
	hud.show_message("")
	_update_aim_visuals()


func _aim_dir() -> Vector3:
	return Vector3(cos(aim_angle), sin(aim_angle), 0.0)


func _launch() -> void:
	if state != State.AIMING:
		return
	attempts += 1
	state = State.FLYING
	flight_time = 0.0
	_flight_points.clear()
	_sample_timer = 0.0
	preview.clear()
	dragging = false
	ship.launch(_aim_dir() * aim_power * Game.MAX_LAUNCH_SPEED)
	level.launcher().set_bands_visible(false)
	Fx.burst(level, level.launcher().global_position, Color(1.0, 0.5, 0.15), 60, 6.0)
	cam_rig.shake(0.12)


func _physics_process(delta: float) -> void:
	WorldClock.time += delta
	if state != State.FLYING or not is_instance_valid(ship):
		return
	flight_time += delta
	_sample_timer += delta
	if _sample_timer >= 0.05:
		_sample_timer = 0.0
		_flight_points.append(ship.global_position)
	var p := ship.global_position
	if not level.bounds().has_point(Vector2(p.x, p.y)):
		_end_attempt("LOST IN THE VOID")
	elif flight_time > level.time_limit:
		_end_attempt("SIGNAL LOST")


func _on_crashed(at: Vector3) -> void:
	if state != State.FLYING:
		return
	Fx.explosion(level, at)
	cam_rig.shake(0.7)
	ship.visible = false
	_end_attempt("HULL BREACH")


func _end_attempt(msg: String) -> void:
	state = State.ENDED
	ship.stop()
	ghost.set_points(_flight_points)
	hud.show_message(msg + "\n[R] retry", Color(1.0, 0.45, 0.35))
	var this_attempt := attempts
	await get_tree().create_timer(1.4).timeout
	if state == State.ENDED and not won and attempts == this_attempt:
		_spawn_ship()


func _on_portal() -> void:
	if state != State.FLYING:
		return
	state = State.ENDED
	won = true
	ship.stop()
	ghost.set_points(_flight_points)
	var portal_pos := level.portal().global_position
	Fx.burst(level, portal_pos, Color(0.65, 0.4, 1.0), 300, 16.0)
	cam_rig.shake(0.25)
	var tw := ship.create_tween().set_parallel()
	tw.tween_property(ship, "global_position", portal_pos, 0.35)
	tw.tween_property(ship.visual, "scale", Vector3.ONE * 0.01, 0.35)
	var last := Game.level_index == Game.LEVELS.size() - 1
	hud.show_message("SECTOR CLEAR\n%d attempt%s\n\n[Enter] %s" % [
		attempts, "" if attempts == 1 else "s",
		"play again from Sector 1" if last else "next sector"], Color(0.7, 1.0, 0.8))


# --- Aiming ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if level == null:
		return
	if state == State.AIMING:
		var fine := 0.12 if Input.is_key_pressed(KEY_SHIFT) else 1.0
		var turn := Input.get_axis(&"aim_cw", &"aim_ccw")
		var pw := Input.get_axis(&"power_down", &"power_up")
		if turn != 0.0 or pw != 0.0:
			aim_angle += turn * deg_to_rad(45.0) * fine * delta
			aim_power = clampf(aim_power + pw * 0.4 * fine * delta, 0.05, 1.0)
			_update_aim_visuals()
		elif Game.preview_enabled and _has_moving_bodies():
			_update_aim_visuals()
	hud.set_aim(fposmod(rad_to_deg(aim_angle), 360.0), aim_power, state == State.FLYING, flight_time, level.time_limit)
	hud.set_status(attempts, Game.preview_enabled, cam_rig.chase_mode)
	_update_weather_hud()


func _has_moving_bodies() -> bool:
	for n in get_tree().get_nodes_in_group(&"gravity_sources"):
		if (n as Planet).is_orbiting():
			return true
	return false


func _update_aim_visuals() -> void:
	if not is_instance_valid(ship) or state != State.AIMING:
		return
	var dir := _aim_dir()
	var pull := -dir * aim_power * 1.6
	ship.set_pullback(pull)
	ship.face(dir)
	level.launcher().set_aim(dir, aim_power, pull)
	cam_rig.aim_dir = dir
	if not Game.preview_enabled:
		preview.clear()
		return
	var portal := level.portal()
	var sim := Gravity.simulate(level.launcher().global_position, dir * aim_power * Game.MAX_LAUNCH_SPEED,
		Gravity.snapshot(get_tree()), Game.preview_seconds(), PREVIEW_DT,
		portal.global_position, portal.capture_radius, level.bounds(), 3)
	var tail := Color(0.4, 1.0, 0.6, 0.9) if sim.result == "portal" else Color(-1, 0, 0)
	preview.set_points(sim.points, tail)


func _aim_from_mouse(screen_pos: Vector2) -> void:
	var cam := cam_rig.active_camera()
	var hit: Variant = Plane(Vector3(0, 0, 1), 0.0).intersects_ray(
		cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos))
	if hit == null:
		return
	var v: Vector3 = level.launcher().global_position - (hit as Vector3)
	if v.length() < 0.3:
		return
	aim_angle = atan2(v.y, v.x)
	aim_power = clampf(v.length() / Game.MAX_DRAG, 0.05, 1.0)
	_update_aim_visuals()


func _update_weather_hud() -> void:
	var t := WorldClock.time
	for s in level.stars():
		if not s.has_cmes():
			continue
		if s.wave_radius(t) > 0.0 and s.wave_radius(t) < 45.0:
			hud.set_weather("SOLAR SHOCKWAVE INBOUND", true)
		elif s.charge_level(t) > 0.0:
			hud.set_weather("STAR CHARGING: CME IN %.1fs" % s.time_to_cme(t), true)
		else:
			hud.set_weather("Next CME in %.1fs" % s.time_to_cme(t), false)
		return
	hud.set_weather("", false)


# --- Input -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if level == null:
		return
	if event.is_action_pressed(&"quit"):
		get_tree().quit()
	elif event.is_action_pressed(&"toggle_camera"):
		cam_rig.toggle()
	elif event.is_action_pressed(&"toggle_preview"):
		Game.preview_enabled = not Game.preview_enabled
		_update_aim_visuals()
	elif event.is_action_pressed(&"restart"):
		if won:
			load_level(Game.level_index)
		else:
			_spawn_ship()
	elif event.is_action_pressed(&"launch"):
		_launch()
	elif event.is_action_pressed(&"next_level") and won:
		load_level((Game.level_index + 1) % Game.LEVELS.size())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if won and event.pressed:
			load_level((Game.level_index + 1) % Game.LEVELS.size())
		elif state == State.AIMING:
			dragging = event.pressed
			if dragging:
				_aim_from_mouse(event.position)
	elif event is InputEventMouseMotion and dragging and state == State.AIMING:
		_aim_from_mouse(event.position)


# --- Tools -----------------------------------------------------------------------

func _screenshot_after(delay: float, path: String) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[orbiter] screenshot saved: ", path)
	get_tree().quit()


## Brute-forces angle x power for every level (static gravity only) to check that each level
## is solvable and to measure how forgiving it is.
func _solve_all() -> void:
	for i in Game.LEVELS.size():
		load_level(i)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var bodies := Gravity.snapshot(get_tree())
		var start := level.launcher().global_position
		var portal := level.portal()
		var hits := 0
		var total := 0
		var examples: Array[String] = []
		for a_deg in range(0, 360, 2):
			for p_i in range(3, 21):
				var pw := p_i * 0.05
				var v := Vector3(cos(deg_to_rad(a_deg)), sin(deg_to_rad(a_deg)), 0) * pw * Game.MAX_LAUNCH_SPEED
				var r := Gravity.simulate(start, v, bodies, level.time_limit, 1.0 / 60.0,
					portal.global_position, portal.capture_radius, level.bounds(), 1000000)
				total += 1
				if r.result == "portal":
					hits += 1
					if examples.size() < 8:
						examples.append("%d°@%.2f(%.1fs)" % [a_deg, pw, r.time])
		print("[solve] L%d %-14s %4d/%d solutions (%.2f%%)  %s" % [
			i + 1, level.level_name, hits, total, 100.0 * hits / total, ", ".join(examples)])
	get_tree().quit()
