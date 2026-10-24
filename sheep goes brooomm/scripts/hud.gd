extends CanvasLayer
## Everything on screen that isn't the world: score, title / game over /
## pause cards, the debug readout and the physics tuning panel.
## Built in code so it's easy to read in one place.

const INK := Color("f4f7fa")
const MUTED := Color("a9b6c9")
const PANEL := Color("1d2840")
const LINE := Color("33415f")
const CAP := Color("f2b134")
const SOIL := Color("24324d")
const RED := Color("e63946")

var _score: Label
var _best: Label
var _debug: Label
var _screens := {}
var _dead_title: Label
var _dead_body: Label
var _panel: PanelContainer
var _sliders := {}       # property -> [HSlider, value Label]
var _chaser_box: CheckBox
var _copy_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_score = _label("0 m", 34, SOIL)
	_score.position = Vector2(16, 6)
	root.add_child(_score)
	_best = _label("BEST 0 m", 14, SOIL)
	_best.position = Vector2(18, 50)
	root.add_child(_best)

	var hint := _label("T  tune physics     G  debug     P  pause     R  restart", 14, SOIL)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchor(hint, 1, 0, 1, 0, -620, 14, -16, 34)
	root.add_child(hint)

	_debug = _label("", 13, INK)
	var debug_box := _card_panel(10)
	debug_box.add_child(_debug)
	_anchor(debug_box, 0, 1, 0, 1, 16, -150, 300, -16)
	debug_box.name = "DebugBox"
	root.add_child(debug_box)

	_screens["title"] = _make_screen(root, "Red Rush", RED,
		"Run as far as you can. Beware of Spikes and Lava.\n\n"
		+ "Left / Right     run\n"
		+ "Up    jump (hold for higher)\n"
		+ "T     tune the physics\n"
		+ "G     physics debug info\n"
		+ "P / Esc     pause\n\n"
		+ "Press Enter to start")
	var dead: Control = _make_screen(root, "", INK, "")
	_screens["dead"] = dead
	_dead_title = dead.find_child("Title", true, false)
	_dead_body = dead.find_child("Body", true, false)
	_screens["pause"] = _make_screen(root, "Paused", INK, "Press P or Esc to keep rolling.")

	_build_tuning_panel(root)
	show_screen("")


# ---------- Called by main.gd ----------

func show_screen(screen_name: String) -> void:
	for key in _screens:
		_screens[key].visible = key == screen_name


func show_dead(cause: String, distance: int, best: int) -> void:
	_dead_title.text = cause
	_dead_body.text = "This run   %d m\nBest   %d m\n\nPress R or Enter to roll again" % [distance, best]
	show_screen("dead")


func set_score(distance: int, best: int) -> void:
	_score.text = "%d m" % distance
	_best.text = "BEST %d m" % best


func update_debug(player) -> void:
	var box := _debug.get_parent() as Control
	box.visible = Tuning.show_debug
	if not Tuning.show_debug:
		return
	_debug.text = "vx %6.0f    vy %6.0f\ngrounded  %s\ngravity   %s\ncoyote  %s\nbuffer  %s" % [
		player.velocity.x, player.velocity.y,
		"yes" if player.is_on_floor() else "no",
		player.gravity_mode,
		_bar(player.coyote_timer, Tuning.coyote_time),
		_bar(player.buffer_timer, Tuning.jump_buffer),
	]


func is_panel_open() -> bool:
	return _panel.visible


func toggle_panel() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_sliders["max_speed"][0].grab_focus()
	else:
		# Give the arrow keys back to the game
		get_viewport().gui_release_focus()


# ---------- Tuning panel ----------

func _build_tuning_panel(root: Control) -> void:
	_panel = _card_panel(14)
	_anchor(_panel, 1, 0, 1, 1, -340, 10, -10, -10)
	root.add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	box.add_child(_label("Tune physics", 24, INK))
	var help := _label("The game pauses while this is open. Use Up/Down to pick a value and Left/Right to change it. Press T to jump back in.", 12, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var presets := OptionButton.new()
	for item in ["Preset...", "Default", "Snappy", "Floaty", "Icy"]:
		presets.add_item(item)
	presets.item_selected.connect(func(i: int) -> void:
		if i == 0:
			return
		var preset_name := presets.get_item_text(i)
		if preset_name == "Default":
			Tuning.reset_values()
		else:
			Tuning.apply_preset(preset_name)
		_sync_sliders()
		presets.select(0))
	buttons.add_child(presets)
	var reset := Button.new()
	reset.text = "Reset"
	reset.pressed.connect(func() -> void:
		Tuning.reset_values()
		_sync_sliders())
	buttons.add_child(reset)
	_copy_button = Button.new()
	_copy_button.text = "Copy values"
	_copy_button.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(Tuning.values_as_code())
		_copy_button.text = "Copied")
	buttons.add_child(_copy_button)

	for group in Tuning.SLIDERS:
		var heading := _label(group[0].to_upper(), 12, CAP)
		box.add_child(heading)
		if group[0] == "World":
			_chaser_box = CheckBox.new()
			_chaser_box.text = "Lava wall chases you"
			_chaser_box.button_pressed = Tuning.chaser_on
			_chaser_box.toggled.connect(func(on: bool) -> void: Tuning.chaser_on = on)
			box.add_child(_chaser_box)
		for row in group[1]:
			var key: String = row[0]
			var line := HBoxContainer.new()
			var name_label := _label(row[1], 14, INK)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var value_label := _label("", 14, CAP)
			line.add_child(name_label)
			line.add_child(value_label)
			box.add_child(line)
			var slider := HSlider.new()
			slider.min_value = row[2]
			slider.max_value = row[3]
			slider.step = row[4]
			slider.value_changed.connect(func(v: float) -> void:
				Tuning.set(key, v)
				value_label.text = _fmt(v))
			box.add_child(slider)
			_sliders[key] = [slider, value_label]
	_sync_sliders()
	_panel.visible = false


func _sync_sliders() -> void:
	for key in _sliders:
		var v: float = Tuning.get(key)
		_sliders[key][0].set_value_no_signal(v)
		_sliders[key][1].text = _fmt(v)
	_chaser_box.set_pressed_no_signal(Tuning.chaser_on)


# ---------- Small helpers ----------

func _make_screen(root: Control, title: String, title_color: Color, body: String) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := _card_panel(24)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var t := _label(title, 40, title_color)
	t.name = "Title"
	var b := _label(body, 16, MUTED)
	b.name = "Body"
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 400
	box.add_child(t)
	box.add_child(b)
	card.add_child(box)
	center.add_child(card)
	root.add_child(center)
	return center


func _card_panel(margin: float) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_corner_radius_all(10)
	style.set_content_margin_all(margin)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _anchor(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, o_r: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = o_r
	c.offset_bottom = ob


func _fmt(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.2f" % v


func _bar(value: float, max_value: float) -> String:
	var filled := 0 if max_value <= 0.0 else int(round(10.0 * value / max_value))
	return "[" + "#".repeat(filled) + "-".repeat(10 - filled) + "]"
