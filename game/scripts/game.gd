extends Node
## Global game state and settings (autoload "Game").

const LEVELS: Array[String] = [
	"res://scenes/levels/level_01.tscn",
	"res://scenes/levels/level_02.tscn",
	"res://scenes/levels/level_03.tscn",
	"res://scenes/levels/level_04.tscn",
	"res://scenes/levels/level_05.tscn",
]

## Launch speed at 100% slingshot power (units / second).
const MAX_LAUNCH_SPEED := 24.0
## How far (world units) you drag to reach 100% power.
const MAX_DRAG := 10.0
## The preview can show at most this many seconds of flight; sensor_range scales it.
const SENSOR_HORIZON_SECONDS := 12.0

const SAVE_PATH := "user://orbiter_save.cfg"

var level_index := 0
var preview_enabled := true
## The current roguelite run (resources, upgrades, ship stats).
var run := RunState.new()

# --- Persistent between runs (saved to SAVE_PATH) ---
## Meta currency. Phase 3 spends it on ship parts.
var stardust_bank := 0
var best_sectors := 0
var runs_played := 0

# --- Ship stats (Phase 3: these come from ship parts) ---
var ship_mass := 1.0


func _ready() -> void:
	load_meta()
	_add_action(&"launch", [KEY_SPACE])
	_add_action(&"aim_ccw", [KEY_A, KEY_LEFT])
	_add_action(&"aim_cw", [KEY_D, KEY_RIGHT])
	_add_action(&"power_up", [KEY_W, KEY_UP])
	_add_action(&"power_down", [KEY_S, KEY_DOWN])
	_add_action(&"toggle_camera", [KEY_C, KEY_TAB])
	_add_action(&"toggle_preview", [KEY_P])
	_add_action(&"restart", [KEY_R])
	_add_action(&"next_level", [KEY_ENTER, KEY_KP_ENTER])
	_add_action(&"quit", [KEY_ESCAPE])


func _add_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func preview_seconds() -> float:
	return SENSOR_HORIZON_SECONDS * run.sensor_range


func new_run() -> void:
	run = RunState.new()
	run.refill_launch()
	run.refill_sector()


## Moves the run's stardust into the bank and saves.
func bank_run() -> void:
	stardust_bank += run.stardust
	best_sectors = maxi(best_sectors, run.sectors_cleared)
	runs_played += 1
	save_meta()


func load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	stardust_bank = cfg.get_value("meta", "stardust", 0)
	best_sectors = cfg.get_value("meta", "best_sectors", 0)
	runs_played = cfg.get_value("meta", "runs_played", 0)


func save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "stardust", stardust_bank)
	cfg.set_value("meta", "best_sectors", best_sectors)
	cfg.set_value("meta", "runs_played", runs_played)
	cfg.save(SAVE_PATH)
