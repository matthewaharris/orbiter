class_name Upgrades
## The roguelite upgrade catalog. After each cleared sector the player picks 1 of 3.
##
## To add an upgrade: add an entry to CATALOG, then handle its id in apply().
## `max` = 0 marks a consumable that can be picked any number of times.
## `weight` is how often it shows up relative to the others.

## Speed change (units / second) from one boost.
const BOOST_DV := 7.0

const CATALOG := [
	{id = "boost", name = "Kick Booster", max = 3, weight = 1.0, color = Color(0.35, 0.8, 1.0),
		text = "+1 boost per launch.\n\nTap SPACE mid-flight to thrust toward your mouse cursor."},
	{id = "singularity", name = "Singularity Seed", max = 2, weight = 0.9, color = Color(0.75, 0.4, 1.0),
		text = "+1 black hole per sector.\n\nRight-click while aiming to place it. Right-click it again to pick it up."},
	{id = "sensors", name = "Long-Range Sensors", max = 4, weight = 1.0, color = Color(1.0, 0.75, 0.35),
		text = "The aim preview shows 1.2 more seconds of your flight."},
	{id = "plating", name = "Hull Plating", max = 3, weight = 0.8, color = Color(1.0, 0.45, 0.35),
		text = "+1 max hull, and repairs 1 hull."},
	{id = "deflector", name = "Deflector Shield", max = 2, weight = 0.8, color = Color(0.4, 1.0, 0.85),
		text = "Bounce off one planet impact per launch instead of crashing.\n\nBlack holes still win."},
	{id = "magshield", name = "Magnetic Shield", max = 2, weight = 0.7, color = Color(0.55, 0.65, 1.0),
		text = "Solar wind, CMEs, and storms push you 45% less."},
	{id = "bands", name = "Overcharged Bands", max = 2, weight = 0.7, color = Color(1.0, 0.55, 0.15),
		text = "+15% slingshot launch speed."},
	{id = "magnet", name = "Portal Magnet", max = 2, weight = 0.7, color = Color(0.85, 0.5, 1.0),
		text = "Portals catch you from 35% farther away."},
	{id = "fuel", name = "Fuel Cache", max = 0, weight = 0.6, color = Color(0.45, 0.95, 1.0),
		text = "+4 fuel cells (launches)."},
	{id = "repair", name = "Field Repair", max = 0, weight = 0.6, color = Color(0.5, 1.0, 0.5),
		text = "Repair 2 hull."},
]


static func find(id: String) -> Dictionary:
	for u in CATALOG:
		if u.id == id:
			return u
	return {}


static func is_available(run: RunState, u: Dictionary) -> bool:
	if u.id == "repair":
		return run.hull < run.max_hull
	return u.max == 0 or run.level_of(u.id) < u.max


## Weighted pick of `count` different upgrades the run can still take.
static func roll(run: RunState, count := 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for u in CATALOG:
		if is_available(run, u):
			pool.append(u)
	var out: Array[Dictionary] = []
	while out.size() < count and not pool.is_empty():
		var total := 0.0
		for u in pool:
			total += u.weight
		var r := randf() * total
		for i in pool.size():
			r -= pool[i].weight
			if r <= 0.0 or i == pool.size() - 1:
				out.append(pool[i])
				pool.remove_at(i)
				break
	return out


## Short tag for a card: NEW, LEVEL 2, or CONSUMABLE.
static func tag(run: RunState, u: Dictionary) -> String:
	if u.max == 0:
		return "CONSUMABLE"
	var lv := run.level_of(u.id)
	return "NEW" if lv == 0 else "LEVEL %d of %d" % [lv + 1, u.max]


static func apply(run: RunState, id: String) -> void:
	run.levels[id] = run.level_of(id) + 1
	match id:
		"boost":
			run.boosts_per_launch += 1
			run.boosts_left += 1
		"singularity":
			run.black_holes_per_sector += 1
		"sensors":
			run.sensor_range += 0.1
		"plating":
			run.max_hull += 1
			run.hull += 1
		"deflector":
			run.deflectors_per_launch += 1
			run.deflectors_left += 1
		"magshield":
			run.weather_resist *= 0.55
		"bands":
			run.launch_mult += 0.15
		"magnet":
			run.portal_mult += 0.35
		"fuel":
			run.fuel += 4
		"repair":
			run.hull = mini(run.hull + 2, run.max_hull)
		_:
			push_warning("Unknown upgrade id: %s" % id)
