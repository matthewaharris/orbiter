extends Node3D
## Game controller: runs the roguelite loop, loads sectors, handles aiming / launch / abilities /
## outcomes, and drives the HUD.
##
## A run: clear sectors in order. Every launch burns 1 fuel; crashes cost 1 hull. After each
## clear you pick 1 of 3 upgrades. The run ends at 0 hull, 0 fuel, or after the last sector.
##
## Command-line helpers (after `--` when launching Godot):
##   --level=3            start the run on a sector (1-based)
##   --upgrades=boost,singularity   grant upgrades at the start of the run
##   --hull=N --fuel=N    override starting hull / fuel
##   --aim=35,0.62        preset angle (deg) and power
##   --launch-at=1.5      auto-launch after N seconds
##   --boost-at=2.0       auto-boost (toward the portal) N seconds after launch
##   --hole-at=X,Y        place a black hole at world X,Y (needs the singularity upgrade)
##   --picker             open the upgrade picker right away
##   --chase              start in chase cam
##   --no-preview         start with the preview off
##   --shot=path.png      save a screenshot, then quit (use --shot-delay=seconds)
##   --solve              brute-force every level with the static-gravity sim and print solvability

enum State { AIMING, FLYING, ENDED }

const PREVIEW_DT := 1.0 / 120.0
const STARDUST_PER_CLEAR := 10
const STARDUST_FIRST_TRY := 5
const STARDUST_BLIND := 10

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
var run_over := false
## True once any launch in this sector used the aim preview (no blind bonus).
var _used_preview := false
## Flight time until which impacts are ignored, right after a deflector bounce.
var _deflect_grace := 0.0
var _flight_points := PackedVector3Array()
var _sample_timer := 0.0
var _args := {}


func _ready() -> void:
	_parse_args()
	sun.look_at_from_position(Vector3(-30, 25, 40), Vector3.ZERO, Vector3.UP)

	hud = Hud.new()
	add_child(hud)
	hud.picker.picked.connect(_on_upgrade_picked)
	preview = DotPath.new(0.1)
	preview.color_start = Color(1.0, 0.75, 0.35, 0.95)
	preview.color_end = Color(1.0, 0.45, 0.1, 0.0)
	add_child(preview)
	ghost = DotPath.new(0.06)
	ghost.color_start = Color(0.5, 0.75, 1.0, 0.5)
	ghost.color_end = Color(0.5, 0.75, 1.0, 0.15)
	add_child(ghost)

	Game.new_run()
	if _args.has("solve"):
		_solve_all()
		return
	if _args.has("level"):
		Game.run.sector = clampi(int(_args.level) - 1, 0, Game.LEVELS.size() - 1)
	if _args.has("upgrades"):
		for id in str(_args.upgrades).split(","):
			Upgrades.apply(Game.run, id)
		Game.run.refill_launch()
	if _args.has("hull"):
		Game.run.hull = int(_args.hull)
	if _args.has("fuel"):
		Game.run.fuel = int(_args.fuel)
	if _args.has("no-preview"):
		Game.preview_enabled = false
	load_level(Game.run.sector)
	if _args.has("aim"):
		var parts: PackedStringArray = str(_args.aim).split(",")
		aim_angle = deg_to_rad(float(parts[0]))
		if parts.size() > 1:
			aim_power = float(parts[1])
		_update_aim_visuals()
	if _args.has("hole-at"):
		var xy: PackedStringArray = str(_args["hole-at"]).split(",")
		_place_black_hole(Vector3(float(xy[0]), float(xy[1]), 0.0))
	if _args.has("chase"):
		cam_rig.toggle()
	if _args.has("launch-at"):
		get_tree().create_timer(float(_args["launch-at"])).timeout.connect(_launch)
		if _args.has("boost-at"):
			get_tree().create_timer(float(_args["launch-at"]) + float(_args["boost-at"])).timeout.connect(
				func(): _boost(level.portal().global_position))
	if _args.has("picker"):
		_open_picker("SECTOR CLEAR", "Choose an upgrade for the rest of this run")
	if _args.has("shot"):
		_screenshot_after(float(_args.get("shot-delay", "2.0")), str(_args.shot))


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "true"


# --- Run / sector flow -------------------------------------------------------------

func _start_new_run() -> void:
	Game.new_run()
	run_over = false
	load_level(0)
	hud.toast("NEW RUN", Color(0.7, 1.0, 0.8))


func load_level(index: int) -> void:
	for c in level_root.get_children():
		level_root.remove_child(c)
		c.queue_free()
	ship = null
	won = false
	_used_preview = false
	WorldClock.time = 0.0
	Game.level_index = index
	level = (load(Game.LEVELS[index]) as PackedScene).instantiate()
	var portal := level.portal()
	portal.capture_radius *= Game.run.portal_mult
	level_root.add_child(level)
	if Game.run.portal_mult > 1.0:
		# Show the bigger catch zone.
		portal.add_child(Fx.ring(portal.capture_radius, Color(0.8, 0.5, 1.0), 0.35, 0.06, 32.0, 0.02))
	sun.visible = level.use_sun
	aim_angle = deg_to_rad(level.default_aim_deg)
	aim_power = level.default_power
	attempts = 0
	ghost.clear()
	cam_rig.setup(level)
	portal.ship_entered.connect(_on_portal)
	hud.set_level(index, Game.LEVELS.size(), level)
	Game.run.refill_sector()
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
	Game.run.refill_launch()
	level.launcher().set_bands_visible(true)
	hud.show_message("")
	_update_aim_visuals()


func _launch_speed() -> float:
	return Game.MAX_LAUNCH_SPEED * Game.run.launch_mult


func _aim_dir() -> Vector3:
	return Vector3(cos(aim_angle), sin(aim_angle), 0.0)


func _launch() -> void:
	if state != State.AIMING or run_over or hud.picker.visible:
		return
	if Game.run.fuel <= 0:
		return
	Game.run.fuel -= 1
	attempts += 1
	_used_preview = _used_preview or Game.preview_enabled
	state = State.FLYING
	flight_time = 0.0
	_deflect_grace = 0.0
	_flight_points.clear()
	_sample_timer = 0.0
	preview.clear()
	dragging = false
	ship.launch(_aim_dir() * aim_power * _launch_speed())
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


func _on_crashed(at: Vector3, body: Node3D) -> void:
	if state != State.FLYING:
		return
	if flight_time < _deflect_grace and not body is BlackHole:
		return
	var r := Game.run
	if r.deflectors_left > 0 and not body is BlackHole:
		r.deflectors_left -= 1
		_deflect_grace = flight_time + 0.3
		ship.deflect(body.global_position, float(body.get(&"radius")))
		Fx.burst(level, at, Color(0.4, 1.0, 0.85), 90, 9.0)
		cam_rig.shake(0.3)
		hud.toast("DEFLECTED", Color(0.4, 1.0, 0.85))
		return
	Fx.explosion(level, at)
	cam_rig.shake(0.7)
	ship.visible = false
	r.hull -= 1
	_end_attempt("CONSUMED BY THE SINGULARITY" if body is BlackHole else "HULL BREACH", "-1 hull")


func _end_attempt(msg: String, detail := "") -> void:
	state = State.ENDED
	ship.stop()
	ghost.set_points(_flight_points)
	if Game.run.hull <= 0:
		_end_run("SHIP DESTROYED")
		return
	if Game.run.fuel <= 0:
		_end_run("OUT OF FUEL")
		return
	hud.show_message(msg + "\n[R] retry", Color(1.0, 0.45, 0.35), detail)
	var this_attempt := attempts
	await get_tree().create_timer(1.4).timeout
	if state == State.ENDED and not won and not run_over and attempts == this_attempt:
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

	# Rewards.
	var r := Game.run
	var first_try := attempts == 1
	var fuel_gain := RunState.FUEL_PER_CLEAR + (1 if first_try else 0)
	var dust := STARDUST_PER_CLEAR
	var lines: Array[String] = ["+%d fuel" % RunState.FUEL_PER_CLEAR]
	if first_try:
		dust += STARDUST_FIRST_TRY
		lines.append("+1 fuel, +%d stardust: first-try clear" % STARDUST_FIRST_TRY)
	if not _used_preview:
		dust += STARDUST_BLIND
		lines.append("+%d stardust: flown blind (no preview)" % STARDUST_BLIND)
	lines.append("+%d stardust total" % dust)
	r.fuel += fuel_gain
	r.stardust += dust
	r.sectors_cleared += 1

	var last := r.sector >= Game.LEVELS.size() - 1
	hud.show_message("SECTOR CLEAR", Color(0.7, 1.0, 0.8), "\n".join(lines))
	var sector := r.sector
	await get_tree().create_timer(2.2).timeout
	if run_over or Game.run != r or r.sector != sector:
		return
	if last:
		_end_run("RUN COMPLETE", true)
	else:
		hud.show_message("")
		_open_picker("SECTOR %d CLEAR" % (sector + 1), "Choose an upgrade for the rest of this run")


func _open_picker(title: String, subtitle: String) -> void:
	hud.picker.open(Upgrades.roll(Game.run), Game.run, title, subtitle)


func _on_upgrade_picked(id: String) -> void:
	Upgrades.apply(Game.run, id)
	var u := Upgrades.find(id)
	Game.run.sector += 1
	load_level(Game.run.sector)
	hud.toast("UPGRADE: %s" % str(u.get("name", id)).to_upper(), u.get("color", Color.WHITE))


func _end_run(reason: String, victory := false) -> void:
	run_over = true
	state = State.ENDED
	var r := Game.run
	var lines: Array[String] = ["Sectors cleared: %d / %d" % [r.sectors_cleared, Game.LEVELS.size()]]
	if victory and r.fuel > 0:
		r.stardust += r.fuel * 2
		lines.append("+%d stardust: unused fuel" % (r.fuel * 2))
	var record := r.sectors_cleared > Game.best_sectors
	Game.bank_run()
	lines.append("+%d stardust banked  (total %d)" % [r.stardust, Game.stardust_bank])
	if record:
		lines.append("NEW BEST!")
	lines.append("\n[Enter] new run")
	hud.show_message(reason, Color(0.7, 1.0, 0.8) if victory else Color(1.0, 0.45, 0.35), "\n".join(lines))


# --- Abilities ---------------------------------------------------------------------

## Kick Booster: thrust toward `toward` (the mouse in tactical view; straight ahead in chase).
func _boost(toward: Variant = null) -> void:
	if state != State.FLYING or not is_instance_valid(ship):
		return
	var r := Game.run
	if r.boosts_left <= 0:
		if r.boosts_per_launch > 0:
			hud.toast("BOOSTER EMPTY", Color(1.0, 0.5, 0.4))
		return
	var dir := ship.linear_velocity.normalized()
	if toward == null and not cam_rig.chase_mode:
		toward = _mouse_on_plane(get_viewport().get_mouse_position())
	if toward != null:
		var d: Vector3 = (toward as Vector3) - ship.global_position
		d.z = 0.0
		if d.length() > 0.5:
			dir = d.normalized()
	r.boosts_left -= 1
	ship.boost(dir * Upgrades.BOOST_DV)
	Fx.burst(level, ship.global_position - dir * 0.6, Color(0.4, 0.8, 1.0), 70, 7.0)
	cam_rig.shake(0.15)


## Singularity Seed: right-click places a black hole, or picks one up.
func _toggle_black_hole(screen_pos: Vector2) -> void:
	var hit: Variant = _mouse_on_plane(screen_pos)
	if hit == null:
		return
	for bh in get_tree().get_nodes_in_group(&"black_holes"):
		if (bh as Node3D).global_position.distance_to(hit) < 2.0:
			(bh as BlackHole).collapse()
			Game.run.black_holes_left += 1
			_update_aim_visuals()
			return
	_place_black_hole(hit)


func _place_black_hole(pos: Vector3) -> void:
	var r := Game.run
	if r.black_holes_per_sector <= 0:
		return
	if r.black_holes_left <= 0:
		hud.toast("NO SINGULARITIES LEFT THIS SECTOR", Color(1.0, 0.5, 0.4))
		return
	var problem := _placement_problem(pos)
	if problem != "":
		hud.toast(problem, Color(1.0, 0.5, 0.4))
		return
	r.black_holes_left -= 1
	var bh := BlackHole.new()
	bh.position = level.to_local(pos)
	level.add_child(bh)
	cam_rig.shake(0.2)
	_update_aim_visuals()


func _placement_problem(p: Vector3) -> String:
	if not level.bounds().grow(-2.0).has_point(Vector2(p.x, p.y)):
		return "TOO FAR OUT"
	if p.distance_to(level.launcher().global_position) < 5.0:
		return "TOO CLOSE TO THE SLINGSHOT"
	if p.distance_to(level.portal().global_position) < 4.0:
		return "TOO CLOSE TO THE PORTAL"
	for n in get_tree().get_nodes_in_group(&"gravity_sources"):
		var body := n as Node3D
		if p.distance_to(body.global_position) < float(body.get(&"radius")) + 2.0:
			return "TOO CLOSE TO ANOTHER BODY"
	return ""


# --- Aiming ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if level == null:
		return
	if state == State.AIMING and not hud.picker.visible:
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
	hud.set_run(Game.run, Game.stardust_bank)
	hud.set_abilities(_abilities_text())
	_update_weather_hud()


func _abilities_text() -> String:
	var r := Game.run
	var lines: Array[String] = []
	if r.boosts_per_launch > 0:
		lines.append("BOOST  %d/%d   [SPACE in flight, toward cursor]" % [r.boosts_left, r.boosts_per_launch])
	if r.black_holes_per_sector > 0:
		lines.append("SINGULARITY  %d/%d   [Right-click while aiming]" % [r.black_holes_left, r.black_holes_per_sector])
	if r.deflectors_per_launch > 0:
		lines.append("DEFLECTOR  %d/%d" % [r.deflectors_left, r.deflectors_per_launch])
	if r.weather_resist < 1.0:
		lines.append("MAG SHIELD  -%d%% weather" % int(round((1.0 - r.weather_resist) * 100.0)))
	return "\n".join(lines)


func _has_moving_bodies() -> bool:
	for n in get_tree().get_nodes_in_group(&"gravity_sources"):
		if n is Planet and (n as Planet).is_orbiting():
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
	var sim := Gravity.simulate(level.launcher().global_position, dir * aim_power * _launch_speed(),
		Gravity.snapshot(get_tree()), Game.preview_seconds(), PREVIEW_DT,
		portal.global_position, portal.capture_radius, level.bounds(), 3)
	var tail := Color(0.4, 1.0, 0.6, 0.9) if sim.result == "portal" else Color(-1, 0, 0)
	preview.set_points(sim.points, tail)


func _mouse_on_plane(screen_pos: Vector2) -> Variant:
	var cam := cam_rig.active_camera()
	return Plane(Vector3(0, 0, 1), 0.0).intersects_ray(
		cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos))


func _aim_from_mouse(screen_pos: Vector2) -> void:
	var hit: Variant = _mouse_on_plane(screen_pos)
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
		return
	if event.is_action_pressed(&"toggle_camera"):
		cam_rig.toggle()
		return
	if event.is_action_pressed(&"toggle_preview"):
		Game.preview_enabled = not Game.preview_enabled
		_update_aim_visuals()
		return
	if hud.picker.visible:
		return
	if run_over:
		var click: bool = event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT
		if event.is_action_pressed(&"next_level") or click:
			_start_new_run()
		return
	if won:
		return
	if event.is_action_pressed(&"restart"):
		if state == State.FLYING and Game.run.fuel <= 0:
			_end_attempt("ABORTED")
		else:
			_spawn_ship()
	elif event.is_action_pressed(&"launch"):
		if state == State.FLYING:
			_boost()
		else:
			_launch()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and state == State.AIMING and not cam_rig.chase_mode:
			_toggle_black_hole(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if state == State.AIMING:
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
