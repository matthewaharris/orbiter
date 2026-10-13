class_name RunState
extends RefCounted
## Everything that lasts for one roguelite run: resources, picked upgrades, and the ship
## stats those upgrades produce. A new RunState is created at the start of every run.

const START_HULL := 3
const START_FUEL := 8
## Fuel cells awarded for clearing a sector (+1 more for a first-try clear).
const FUEL_PER_CLEAR := 3

var sector := 0
var sectors_cleared := 0
var hull := START_HULL
var max_hull := START_HULL
## One fuel cell is burned per launch. The run ends when you run dry.
var fuel := START_FUEL
## Earned this run; banked into Game.stardust_bank when the run ends.
var stardust := 0
## Upgrade id -> how many times it has been picked.
var levels := {}

# --- Stats written by Upgrades.apply() ---
## Fraction of Game.SENSOR_HORIZON_SECONDS the aim preview shows.
var sensor_range := 0.12
var boosts_per_launch := 0
var black_holes_per_sector := 0
var deflectors_per_launch := 0
## Multiplier on wind, drag, and CME forces.
var weather_resist := 1.0
var launch_mult := 1.0
var portal_mult := 1.0

# --- Charges left right now ---
var boosts_left := 0
var deflectors_left := 0
var black_holes_left := 0


func level_of(id: String) -> int:
	return levels.get(id, 0)


## Called each time a fresh ship is put on the slingshot.
func refill_launch() -> void:
	boosts_left = boosts_per_launch
	deflectors_left = deflectors_per_launch


## Called when a sector loads.
func refill_sector() -> void:
	black_holes_left = black_holes_per_sector
