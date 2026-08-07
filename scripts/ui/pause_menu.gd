extends CanvasLayer
## Pause menu (Esc during play): volume sliders, mouse sensitivity,
## fullscreen toggle, resume / restart island / quit. Settings persist via
## the Settings autoload. Doesn't open during the intro or over other panels.

const INK := Color(0.28, 0.2, 0.12)

const ISLANDS := [
	{"label": "Island 1: Ahalo", "scene": "res://scenes/islands/ahalo.tscn",
		"spawn": Vector3(0, 1, 30), "track": "ahalo", "display": "Ahalo"},
	{"label": "Island 2: The Eaton Centre", "scene": "res://scenes/islands/eaton.tscn",
		"spawn": Vector3(0, 1.2, 40), "track": "eaton", "display": "The Eaton Centre"},
	{"label": "Island 3: Prince's Island", "scene": "res://scenes/islands/calgary.tscn",
		"spawn": Vector3(0, 1.2, 42), "track": "calgary", "display": "Prince's Island"},
	{"label": "Island 4: The Winnipeg Crescent", "scene": "res://scenes/islands/winnipeg.tscn",
		"spawn": Vector3(0, 1.2, 42), "track": "winnipeg", "display": "The Winnipeg Crescent"},
]

var _open := false
var _panel: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _open:
		_close()
		get_viewport().set_input_as_handled()
	elif not get_tree().paused and GameState.get_flag("intro_done"):
		_show_menu()
		get_viewport().set_input_as_handled()

func _show_menu() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	Settings.save_settings()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Skip-travel between islands. Jumping ahead marks earlier islands
## complete so the riddle tracker and satchel stay coherent.
func _travel_to_island(isl: Dictionary) -> void:
	# Jumping ahead grants the flags earlier islands would have set.
	if isl.track in ["eaton", "calgary", "winnipeg"] and not GameState.get_flag("island1_complete"):
		GameState.set_flag("island1_complete")
	if isl.track in ["calgary", "winnipeg"] and not GameState.get_flag("island2_complete"):
		GameState.set_flag("island2_complete")
	if isl.track == "winnipeg" and not GameState.get_flag("island3_complete"):
		# Skipping Calgary still means Oreo joined there: the story says so.
		for f: String in ["island3_complete", "meadow_open", "oreo_untangled",
				"oreo_fed", "oreo_friend", "oreo_joined"]:
			GameState.set_flag(f)
	_close()
	var mgr := get_tree().get_first_node_in_group("island_manager")
	if mgr:
		mgr.travel_to(isl.scene, isl.spawn, isl.track, isl.display)

func _restart_island() -> void:
	GameState.reset()
	Inventory.reset()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().reload_current_scene()

# --- construction ---

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel",
			preload("res://scripts/ui/hud.gd").parchment_style())
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -250.0
	_panel.offset_top = -330.0
	_panel.offset_right = 250.0
	_panel.offset_bottom = 330.0
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 26)
	_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "~  Paused  ~"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", INK)
	vbox.add_child(title)

	_section(vbox, "Sound")
	_slider_row(vbox, "Master", Settings.master_vol, 0.0, 1.0,
			func(v: float) -> void:
				Settings.master_vol = v
				Settings.apply())
	_slider_row(vbox, "Music", Settings.music_vol, 0.0, 1.0,
			func(v: float) -> void:
				Settings.music_vol = v
				Settings.apply())
	_slider_row(vbox, "Effects", Settings.sfx_vol, 0.0, 1.0,
			func(v: float) -> void:
				Settings.sfx_vol = v
				Settings.apply()
				Sfx.play("pickup_chime", 1.0, 0.0, -10.0))

	_section(vbox, "Controls & Display")
	_slider_row(vbox, "Mouse speed", Settings.mouse_sensitivity, 0.3, 2.0,
			func(v: float) -> void:
				Settings.mouse_sensitivity = v)
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Settings.fullscreen
	fs.add_theme_color_override("font_color", INK)
	fs.toggled.connect(func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply())
	vbox.add_child(fs)

	_section(vbox, "Travel")
	for isl: Dictionary in ISLANDS:
		_button(vbox, isl.label, _travel_to_island.bind(isl))

	vbox.add_child(HSeparator.new())
	_button(vbox, "Resume", _close)
	_button(vbox, "Restart Island", _restart_island)
	_button(vbox, "Quit Game", func() -> void: get_tree().quit())

	var hint := Label.new()
	hint.text = "WASD move · Shift run · Space jump · E interact · M meow · Tab journal"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.4, 0.28))
	vbox.add_child(hint)

func _section(vbox: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.34, 0.2))
	vbox.add_child(lbl)

func _slider_row(vbox: VBoxContainer, label_text: String, initial: float,
		min_v: float, max_v: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(110, 0)
	lbl.add_theme_color_override("font_color", INK)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.05
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	vbox.add_child(row)

func _button(vbox: VBoxContainer, text: String, on_press: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	btn.pressed.connect(on_press)
	vbox.add_child(btn)
