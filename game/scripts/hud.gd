class_name Hud
extends CanvasLayer
## On-screen text: level title, hint, aim readout, space-weather warning, messages,
## plus the run panel (hull, fuel, stardust), ability charges, and the upgrade picker.

const ACCENT := Color(1.0, 0.55, 0.15)
const COOL := Color(0.55, 0.8, 1.0)
const HULL_COLOR := Color(1.0, 0.42, 0.32)
const FUEL_COLOR := Color(0.4, 0.9, 1.0)
const EMPTY_PIP := Color(1, 1, 1, 0.13)

var picker: UpgradePicker

var _title: Label
var _hint: Label
var _aim: Label
var _status: Label
var _weather: Label
var _message: Label
var _sub: Label
var _controls: Label
var _abilities: Label
var _toast: Label
var _toast_tween: Tween
var _hull_pips: HBoxContainer
var _fuel_pips: HBoxContainer
var _dust: Label
var _run_key := []


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
	_place(_controls, Vector4(1, 0, 1, 0), Vector4(-640, 20, -28, 160))
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_controls.text = "\n".join([
		"Drag mouse: aim & power (pull back)",
		"A/D or Left/Right: fine angle   W/S or Up/Down: power",
		"Hold Shift: extra fine",
		"SPACE: launch      R: reset",
		"C: chase cam      P: aim preview",
	])

	# Run panel, bottom-left: hull and fuel pips, stardust.
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override(&"separation", 6)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, Vector4(0, 1, 0, 1), Vector4(30, -112, 520, -20))
	panel.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(panel)
	_hull_pips = _pip_row(panel, "HULL", HULL_COLOR)
	_fuel_pips = _pip_row(panel, "FUEL", FUEL_COLOR)
	_dust = _label(panel, 16, Color(0.85, 0.75, 1.0))

	_abilities = _label(root, 16, Color(0.8, 0.9, 1.0))
	_place(_abilities, Vector4(1, 1, 1, 1), Vector4(-560, -112, -28, -20))
	_abilities.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_abilities.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

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

	_sub = _label(root, 22, Color(1, 1, 1, 0.85))
	_place(_sub, Vector4(0, 0.5, 1, 0.5), Vector4(0, -150, 0, 0))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_toast = _label(root, 26, Color.WHITE)
	_place(_toast, Vector4(0, 0.5, 1, 0.5), Vector4(0, 120, 0, 160))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	picker = UpgradePicker.new()
	add_child(picker)


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


func _pip_row(parent: Control, caption: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var l := _label(row, 16, color)
	l.text = caption
	l.custom_minimum_size = Vector2(52, 0)
	return row


func _set_pips(row: HBoxContainer, filled: int, total: int, color: Color, pip_size: Vector2) -> void:
	for i in range(row.get_child_count() - 1, 0, -1):
		row.get_child(i).free()
	for i in total:
		var pip := ColorRect.new()
		pip.custom_minimum_size = pip_size
		pip.color = color if i < filled else EMPTY_PIP
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)


func set_run(run: RunState, bank: int) -> void:
	var key := [run.hull, run.max_hull, run.fuel, run.stardust, bank]
	if key == _run_key:
		return
	_run_key = key
	_set_pips(_hull_pips, run.hull, run.max_hull, HULL_COLOR, Vector2(26, 12))
	_set_pips(_fuel_pips, run.fuel, run.fuel, FUEL_COLOR, Vector2(10, 16))
	var fuel_count := _label(_fuel_pips, 16, FUEL_COLOR)
	fuel_count.text = " %d" % run.fuel
	_dust.text = "STARDUST  +%d this run   (%d banked)" % [run.stardust, bank]


func set_abilities(text: String) -> void:
	_abilities.text = text


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
	_status.text = "Launches this sector: %d     Preview: %s     View: %s" % [
		attempts, "ON" if preview_on else "OFF (hard mode)", "CHASE" if chase else "TACTICAL"]


func set_weather(text: String, urgent: bool) -> void:
	_weather.text = text
	_weather.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.2) if urgent else ACCENT)


## Big centered message, with optional smaller detail lines underneath.
func show_message(text: String, color := Color.WHITE, sub := "") -> void:
	_message.text = text
	_message.add_theme_color_override(&"font_color", color)
	_sub.text = sub


## Short-lived notice that fades out on its own.
func toast(text: String, color := Color.WHITE) -> void:
	_toast.text = text
	_toast.add_theme_color_override(&"font_color", color)
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
