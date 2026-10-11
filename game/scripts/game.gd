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

var level_index := 0
var preview_enabled := true

# --- Ship stats (Phase 2/3: these come from upgrades and parts) ---
## Fraction of SENSOR_HORIZON_SECONDS the aim preview shows.
var sensor_range := 0.12
var ship_mass := 1.0


func _ready() -> void:
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
	return SENSOR_HORIZON_SECONDS * sensor_range
