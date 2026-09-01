extends CanvasLayer
## Khione's Journal (Tab key): a tabbed storybook menu.
##   Satchel  — inventory with item art and flavor descriptions
##   Riddles  — solved, current, and still-hidden riddles of the island
##   Controls — key reference
## New tabs slot in via _add_tab(); future homes for the letter and a map.

const INK := Color(0.28, 0.2, 0.12)
const FADED := Color(0.55, 0.45, 0.3)
const HudScript := preload("res://scripts/ui/hud.gd")

const RIDDLES := [
	{"flag": "letter_read", "title": "The Bottle",
		"text": "Reach the bottle on the south beach."},
	{"flag": "echo_stones_solved", "title": "The Three Hollow Stones",
		"text": "Three hollow stones hum by the eastern cove, and a carving remembers their song."},
	{"flag": "seesaw_gate_open", "title": "The Vine Gate",
		"text": "Something sleeps behind the vine gate on the west hillside. Old wood tips under heavy things."},
	{"flag": "sundial_shell_placed", "title": "The Golden Heart",
		"text": "Atop the old summit, a dial waits for its golden heart."},
	{"flag": "raft_released", "title": "The Shadow's Rock",
		"text": "The shell's shadow points far across the water. Climb where it leads, and speak."},
	{"flag": "raft_frame_beached", "title": "The Drifting Timbers",
		"text": "Loose timbers drift toward the south beach…"},
	{"flag": "raft_rigged", "title": "Rig the Raft",
		"text": "The frame wants an oar, a sail, and rope to bind it."},
	{"flag": "island1_complete", "title": "Set Sail",
		"text": "The raft is ready. The sea is waiting."},
	{"flag": "mall_time_3", "title": "The Wrong-Way Stairs", "island": 2,
		"text": "Every stair runs against her. The stuck clock above the fountain still commands the mall, and the directory remembers when things happen."},
	{"flag": "fountain_wish_made", "title": "The Fountain of Small Wishes", "island": 2,
		"text": "Coins wait on the ledge, marked two ways. The mosaic under the water remembers three of them, in order."},
	{"flag": "mannequins_posed", "title": "The Mannequin Quartet", "island": 2,
		"text": "Four dancers behind brass-locked glass. The poster remembers their pose, but glass remembers things backwards."},
	{"flag": "pigeon_parliament_solved", "title": "The Pigeon Parliament", "island": 2,
		"text": "Pigeons rule the west tiles and flee from hisses, always away, one tile at a time. Four grated tiles wait beneath four birds."},
	{"flag": "island2_complete", "title": "Make the Flock Fly", "island": 2,
		"text": "Crank the sky open. Lean the light to evening. Follow sixty shadows to the sleeping elevator, wake it, and take the roof. The flock knows the rest."},
	{"flag": "regatta_done", "title": "The Paper Regatta", "island": 3,
		"text": "Paper boats lie becalmed on the lagoon. The fluff gives one beat of warning, and the little weir decides what passes under the red bridge."},
	{"flag": "ice_cream_done", "title": "The Ice Cream Round", "island": 3,
		"text": "The cart's bell wants its clapper back, and then the vendor's round: four painted notes, rung just so, in one short breath."},
	{"flag": "kite_freed", "title": "The Bridge and the Kite", "island": 3,
		"text": "A kite thrashes at the arch of the red bridge, still only in the lull. Its string runs down into the shallows, tied to something."},
	{"flag": "gopher_semaphore_done", "title": "The Gopher Semaphore", "island": 3,
		"text": "A crayon map under a picnic table numbers six burrows. Meows carry underground… pulse the doors in the map's order."},
	{"flag": "island3_complete", "title": "The Howl in the Off-Leash Meadow", "island": 3,
		"text": "The paw key opens the gate. The run-line loops tree, bench, stone: walk it backwards. Then cream, biscuits, and one good throw."},
	{"flag": "drift_line_done", "title": "The Drift Line", "island": 4,
		"text": "The squall buried the laundry. Meow at the lumps, let him dig, and hang each piece back by its paired clothespin."},
	{"flag": "rink_done", "title": "The Backyard Rink", "island": 4,
		"text": "The puck slides until it hits something, and the boards are never right. A dog on a stay is the proudest bumper alive."},
	{"flag": "mailbox_done", "title": "The Mailbox Morse", "island": 4,
		"text": "Odd flags up, even flags down, read from the top of the slide. All six in one stillness, before the squall scrambles them."},
	{"flag": "swing_done", "title": "The Swing Set Launch", "island": 4,
		"text": "Pump with the rhythm, let go with courage. The rooftops keep bolts, a loonie, and the view that matters."},
	{"flag": "island4_complete", "title": "The Longest Slide", "island": 4,
		"text": "Salt the gate, wake the toboggan, and dig the run open along the flag-line: she marks, he digs. Then ride it, all the way to the cellar."},
	{"flag": "horse_moved", "title": "The Calèche Horse", "island": 5,
		"text": "It ignored the meow and planted its hooves at the hiss. Oreo barked; it backed a step. She tried to bark, and what came out was a GROWL. Big things listen."},
	{"flag": "three_stars_done", "title": "The Three Stars", "island": 5,
		"text": "Hiss the Zamboni off the dot, growl the great cube awake, and hoist the three star numbers in the order it calls. The penalty box keeps spare arena glass."},
	{"flag": "mmfa_delivered", "title": "The Fallen Star", "island": 5,
		"text": "The horn shook number 10 out of the rafters, and the plaque said en prêt: on loan. TIREZ means pull, and pulling is a dog's work. The museum lit up warm, and a squirrel paid its debt in brass."},
	{"flag": "stairs_fixed", "title": "The Staircase Shuffle", "island": 5,
		"text": "Every lever swings its own flight and the next. From below, a maze; from the chalet balcony, a zigzag with two flights wrong. Climb high to think, then act."},
	{"flag": "bagels_placed", "title": "The Bagel Standard", "island": 5,
		"text": "Pull the bagel in the golden second. Twelve lantern bases wanted twelve, the toll took one, and the sign said à la douzaine. Squirrels count. So does the cross."},
	{"flag": "island5_complete", "title": "Light the Cross", "island": 5,
		"text": "Panes for the glassless lanterns, warm bagels for the fireflies, and the chalk-drum duet to make them settle: the cross lit tier by tier, and its shadow found the funicular gate."},
]

const CONTROLS := [
	["W A S D  /  arrows", "Walk"],
	["Shift", "Run"],
	["Space", "Jump, or paddle up in water"],
	["Mouse", "Look around"],
	["E  /  left click", "Interact, pick up, place"],
	["M", "Meow. Some things on the island listen"],
	["H  /  G", "Hiss and growl (not learned yet)"],
	["Tab  /  I", "Open or close this journal"],
	["Esc", "Pause and settings"],
]

var _open := false
var _panel: PanelContainer
var _tab_bar: HBoxContainer
var _tab_group := ButtonGroup.new()
var _pages: Array[Control] = []
var _satchel_header: Label
var _satchel_list: VBoxContainer
var _riddle_list: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 9
	visible = false
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if _open:
			_close()
			get_viewport().set_input_as_handled()
		elif not get_tree().paused and GameState.get_flag("intro_done"):
			_show()
			get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _show() -> void:
	_open = true
	_refresh_satchel()
	_refresh_riddles()
	visible = true
	get_tree().paused = true
	Sfx.play("paper_open", 1.0, 0.05, -6.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	Sfx.play("paper_close", 1.0, 0.05, -8.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# --- construction ---

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", HudScript.parchment_style())
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -390.0
	_panel.offset_top = -280.0
	_panel.offset_right = 390.0
	_panel.offset_bottom = 280.0
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "~  Khione's Journal  ~"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", INK)
	vbox.add_child(title)

	_tab_bar = HBoxContainer.new()
	_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_bar.add_theme_constant_override("separation", 8)
	vbox.add_child(_tab_bar)

	var content := MarginContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	_add_tab("Satchel", _build_satchel_page(), content)
	_add_tab("Riddles", _build_riddles_page(), content)
	_add_tab("Controls", _build_controls_page(), content)
	_select_tab(0)

	var hint := Label.new()
	hint.text = "Tab closes the journal"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", FADED)
	vbox.add_child(hint)

func _add_tab(label: String, page: Control, content: MarginContainer) -> void:
	var idx := _pages.size()
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.button_group = _tab_group
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(120, 36)
	btn.pressed.connect(_select_tab.bind(idx))
	_tab_bar.add_child(btn)
	page.visible = false
	content.add_child(page)
	_pages.append(page)

func _select_tab(idx: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == idx
	(_tab_bar.get_child(idx) as Button).button_pressed = true

func _build_satchel_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	_satchel_header = Label.new()
	_satchel_header.add_theme_font_size_override("font_size", 15)
	_satchel_header.add_theme_color_override("font_color", FADED)
	page.add_child(_satchel_header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	_satchel_list = VBoxContainer.new()
	_satchel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_satchel_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_satchel_list)
	return page

func _build_riddles_page() -> Control:
	var scroll := ScrollContainer.new()
	_riddle_list = VBoxContainer.new()
	_riddle_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_riddle_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_riddle_list)
	return scroll

func _build_controls_page() -> Control:
	var scroll := ScrollContainer.new()
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for pair: Array in CONTROLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var key := Label.new()
		key.text = pair[0]
		key.custom_minimum_size = Vector2(220, 0)
		key.add_theme_font_size_override("font_size", 15)
		key.add_theme_color_override("font_color", INK)
		row.add_child(key)
		var action := Label.new()
		action.text = pair[1]
		action.add_theme_font_size_override("font_size", 15)
		action.add_theme_color_override("font_color", FADED)
		row.add_child(action)
		list.add_child(row)
	return scroll

# --- refresh ---

func _refresh_satchel() -> void:
	for c in _satchel_list.get_children():
		c.queue_free()
	_satchel_header.text = "Slots used: %d of %d" % [Inventory.stacks.size(), Inventory.max_slots]
	if Inventory.stacks.is_empty():
		var empty := Label.new()
		empty.text = "Empty paws… but the island is generous. Look around."
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", FADED)
		_satchel_list.add_child(empty)
		return
	for stack: Dictionary in Inventory.stacks:
		var id: String = stack.id
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(56, 56)
		slot.add_theme_stylebox_override("panel", HudScript.parchment_style(0.9))
		var icon := HudScript.ItemIcon.new()
		icon.item_id = id
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(icon)
		row.add_child(slot)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = Inventory.display_name(id) \
				+ (("   ×%d" % stack.count) if stack.count > 1 else "")
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", INK)
		text_box.add_child(name_lbl)
		var desc := Label.new()
		desc.text = Inventory.description(id)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", FADED)
		text_box.add_child(desc)
		row.add_child(text_box)
		_satchel_list.add_child(row)

func _refresh_riddles() -> void:
	for c in _riddle_list.get_children():
		c.queue_free()
	var current_shown := false
	for r: Dictionary in RIDDLES:
		var solved: bool = GameState.get_flag(r.flag) \
				or (r.get("island", 1) == 1 and GameState.get_flag("island1_complete")) \
				or (r.get("island", 1) == 2 and GameState.get_flag("island2_complete")) \
				or (r.get("island", 1) == 3 and GameState.get_flag("island3_complete")) \
				or (r.get("island", 1) == 4 and GameState.get_flag("island4_complete"))
		var row := VBoxContainer.new()
		var title := Label.new()
		title.add_theme_font_size_override("font_size", 17)
		if solved:
			title.text = "✓  " + r.title
			title.add_theme_color_override("font_color", FADED)
		elif not current_shown:
			current_shown = true
			title.text = "❖  " + r.title
			title.add_theme_color_override("font_color", INK)
			var text := Label.new()
			text.text = r.text
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.add_theme_font_size_override("font_size", 14)
			text.add_theme_color_override("font_color", Color(0.4, 0.31, 0.18))
			row.add_child(title)
			row.add_child(text)
			_riddle_list.add_child(row)
			continue
		else:
			title.text = "·  · ·"
			title.add_theme_color_override("font_color", Color(0.6, 0.52, 0.38, 0.6))
		row.add_child(title)
		_riddle_list.add_child(row)
