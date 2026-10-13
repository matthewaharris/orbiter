class_name UpgradePicker
extends Control
## Full-screen "choose 1 of 3" overlay shown after each cleared sector.
## Click a card or press 1 / 2 / 3.

signal picked(id: String)

var _row: HBoxContainer
var _title: Label
var _subtitle: Label
var _cards: Array[PanelContainer] = []
var _options: Array[Dictionary] = []
var _choosing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	_title = _label(col, 40, Color(0.7, 1.0, 0.8))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle = _label(col, 18, Color(1, 1, 1, 0.7))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 28)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_row)

	var footer := _label(col, 16, Color(1, 1, 1, 0.5))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.text = "Click a card or press 1 / 2 / 3"


func open(options: Array[Dictionary], run: RunState, title: String, subtitle: String) -> void:
	_options = options
	_choosing = false
	_title.text = title
	_subtitle.text = subtitle
	for c in _cards:
		c.queue_free()
	_cards.clear()
	for i in options.size():
		var card := _make_card(i, options[i], run)
		_row.add_child(card)
		_cards.append(card)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	# Deal the cards in one after another.
	for i in _cards.size():
		var card := _cards[i]
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.tween_interval(0.12 + i * 0.1)
		tw.tween_property(card, "modulate:a", 1.0, 0.25)


func _make_card(index: int, u: Dictionary, run: RunState) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 320)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override(&"panel", _card_style(u.color, false))

	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	_label(v, 15, Color(1, 1, 1, 0.45)).text = "[%d]" % (index + 1)
	var name_label := _label(v, 28, u.color)
	name_label.text = u.name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(v, 14, Color(u.color, 0.75)).text = Upgrades.tag(run, u)
	var line := ColorRect.new()
	line.color = Color(u.color, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	var desc := _label(v, 18, Color(1, 1, 1, 0.9))
	desc.text = u.text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(256, 0)

	card.mouse_entered.connect(func(): card.add_theme_stylebox_override(&"panel", _card_style(u.color, true)))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override(&"panel", _card_style(u.color, false)))
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_choose(index))
	return card


func _card_style(color: Color, hot: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.07, 0.12, 0.95) if not hot else Color(0.1, 0.1, 0.18, 0.98)
	s.border_color = color if hot else Color(color, 0.55)
	s.set_border_width_all(4 if hot else 2)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(22)
	s.shadow_color = Color(color, 0.35 if hot else 0.12)
	s.shadow_size = 18 if hot else 8
	return s


func _input(event: InputEvent) -> void:
	if not visible or _choosing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var i: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
		if i >= 0 and i < _options.size():
			get_viewport().set_input_as_handled()
			_choose(i)


func _choose(index: int) -> void:
	if _choosing:
		return
	_choosing = true
	for i in _cards.size():
		var card := _cards[i]
		if i == index:
			card.pivot_offset = card.size * 0.5
			card.create_tween().tween_property(card, "scale", Vector2.ONE * 1.08, 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			card.create_tween().tween_property(card, "modulate:a", 0.15, 0.2)
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		visible = false
		picked.emit(_options[index].id))


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override(&"outline_size", maxi(4, size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
