class_name Hud
extends CanvasLayer
## On-screen text: level title, hint, aim readout, space-weather warning, and messages.

const ACCENT := Color(1.0, 0.55, 0.15)
const COOL := Color(0.55, 0.8, 1.0)

var _title: Label
var _hint: Label
var _aim: Label
var _status: Label
var _weather: Label
var _message: Label
var _controls: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_title = _label(root, 34, Color.WHITE)
	_title.position = Vector2(28, 20)
	_hint = _label(root, 18, COOL)
	_hint.position = Vector2(30, 68)
	_hint.custom_minimum_size = Vector2(620, 0)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_weather = _label(root, 22, ACCENT)
	_weather.position = Vector2(30, 140)

	_controls = _label(root, 15, Color(1, 1, 1, 0.6))
	_place(_controls, Vector4(1, 0, 1, 0), Vector4(-640, 20, -28, 140))
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_controls.text = "\n".join([
		"Drag mouse: aim & power (pull back)",
		"A/D or Left/Right: fine angle   W/S or Up/Down: power",
		"Hold Shift: extra fine",
		"SPACE: launch      R: reset",
		"C: chase cam      P: aim preview",
	])

	_aim = _label(root, 24, Color.WHITE)
	_place(_aim, Vector4(0, 1, 1, 1), Vector4(0, -84, 0, -50))
	_aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_status = _label(root, 16, Color(1, 1, 1, 0.65))
	_place(_status, Vector4(0, 1, 1, 1), Vector4(0, -44, 0, -18))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_message = _label(root, 46, Color.WHITE)
	_place(_message, Vector4(0, 0, 1, 1), Vector4(0, -280, 0, -280))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## anchors / offsets as (left, top, right, bottom).
func _place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override(&"outline_size", maxi(4, size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func set_level(index: int, total: int, level: Level) -> void:
	_title.text = "SECTOR %d/%d  ·  %s" % [index + 1, total, level.level_name.to_upper()]
	_hint.text = level.hint
	show_message("")


func set_aim(angle_deg: float, power: float, flying: bool, flight_time: float, time_limit: float) -> void:
	if flying:
		_aim.text = "IN FLIGHT  %.1fs / %.0fs" % [flight_time, time_limit]
	else:
		var bars := int(round(power * 20.0))
		_aim.text = "POWER [%s%s] %3d%%     ANGLE %5.1f°" % ["|".repeat(bars), "·".repeat(20 - bars), int(round(power * 100.0)), angle_deg]


func set_status(attempts: int, preview_on: bool, chase: bool) -> void:
	_status.text = "Attempts: %d     Preview: %s     View: %s" % [
		attempts, "ON" if preview_on else "OFF (hard mode)", "CHASE" if chase else "TACTICAL"]


func set_weather(text: String, urgent: bool) -> void:
	_weather.text = text
	_weather.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.2) if urgent else ACCENT)


func show_message(text: String, color := Color.WHITE) -> void:
	_message.text = text
	_message.add_theme_color_override(&"font_color", color)
