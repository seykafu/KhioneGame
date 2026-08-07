extends CanvasLayer
## HUD: interaction prompt, vocalization feedback, inventory bar, and the
## letter panel (which pauses the game while open).

const VOCAL_TEXT := {"meow": "Meow!", "hiss": "Hsss!", "growl": "Grrrr…"}
const VOCAL_UNKNOWN_TEXT := {
	"meow": "…",
	"hiss": "Khione hasn't learned to hiss yet…",
	"growl": "Khione hasn't learned to growl yet…",
}

@onready var prompt: Label = $Prompt
@onready var vocal_label: Label = $VocalLabel
@onready var letter_panel: PanelContainer = $LetterPanel
@onready var inventory_bar: HBoxContainer = $InventoryBar

const INK := Color(0.28, 0.2, 0.12)

var player: Node = null
var _vocal_timer := 0.0
var _slots: Array[Panel] = []
var _paw_marks: Array[Control] = []
var _icons: Array[Control] = []
var _slot_counts: Array[Label] = []
var _location_label: Label
var _location_tween: Tween
var _objective_panel: PanelContainer
var _objective_label: Label
var _last_objective := ""
var _letter_hint_shown := false
var _msg_panel: PanelContainer
var _msg_label: Label
var _msg_timer := 0.0

class PawMark:
	extends Control
	## Faint toe-bean watermark drawn in empty inventory slots.

	func _draw() -> void:
		var c := Color(0.5, 0.38, 0.24, 0.28)
		var ctr := size / 2.0
		draw_circle(ctr + Vector2(0, 6), 9.0, c)
		for off: Vector2 in [Vector2(-12, -5), Vector2(-4.5, -10), Vector2(4.5, -10), Vector2(12, -5)]:
			draw_circle(ctr + off, 4.2, c)

class ItemIcon:
	extends Control
	## Hand-drawn vector icon for each inventory item, in the storybook palette.

	var item_id := ""

	func _draw() -> void:
		var c := size / 2.0
		match item_id:
			"coconut":
				var brown := Color(0.42, 0.3, 0.17)
				var dark := Color(0.28, 0.19, 0.1)
				draw_circle(c, 13.0, brown)
				draw_arc(c, 13.0, 0.0, TAU, 32, dark, 2.0, true)
				draw_circle(c + Vector2(-4, -4), 1.9, dark)
				draw_circle(c + Vector2(4, -4), 1.9, dark)
				draw_circle(c + Vector2(0, 2), 1.9, dark)
			"sun_shell":
				var gold := Color(0.93, 0.76, 0.28)
				var rust := Color(0.72, 0.52, 0.16)
				var hinge := c + Vector2(0, 11)
				var fan := PackedVector2Array([hinge])
				for i in 13:
					var ang := deg_to_rad(lerpf(205.0, 335.0, i / 12.0))
					fan.append(hinge + Vector2(cos(ang), sin(ang)) * 19.0)
				draw_colored_polygon(fan, gold)
				for i in 5:
					var ang := deg_to_rad(lerpf(215.0, 325.0, i / 4.0))
					draw_line(hinge, hinge + Vector2(cos(ang), sin(ang)) * 18.0, rust, 1.6, true)
			"rusty_locket":
				var bronze := Color(0.55, 0.44, 0.28)
				var dark := Color(0.35, 0.27, 0.16)
				draw_arc(c + Vector2(0, -8), 5.5, PI, TAU, 16, dark, 2.0, true)
				draw_circle(c + Vector2(0, 3), 9.5, bronze)
				draw_arc(c + Vector2(0, 3), 9.5, 0.0, TAU, 32, dark, 2.0, true)
				draw_circle(c + Vector2(0, 5.5), 2.4, dark)
				for off: Vector2 in [Vector2(-3.2, 0.5), Vector2(0, -0.8), Vector2(3.2, 0.5)]:
					draw_circle(c + Vector2(0, 5.5) + off + Vector2(0, -3.2), 1.2, dark)
			"stranded_fish":
				var silver := Color(0.62, 0.72, 0.8)
				var deep := Color(0.4, 0.5, 0.6)
				draw_colored_polygon(_ellipse(c + Vector2(-2, 0), 11.0, 5.5), silver)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(8, 0), c + Vector2(15, -6), c + Vector2(15, 6)]), silver)
				draw_circle(c + Vector2(-8, -1.5), 1.5, deep)
				draw_arc(c + Vector2(-2, 0), 6.0, -0.6, 0.6, 8, deep, 1.4, true)
			"old_oar":
				var wood := Color(0.62, 0.53, 0.42)
				var dark := Color(0.42, 0.34, 0.26)
				draw_line(c + Vector2(-10, 12), c + Vector2(6, -7), wood, 3.4, true)
				draw_colored_polygon(_ellipse(c + Vector2(9, -11), 6.5, 4.0, -0.85), wood)
				draw_arc(c + Vector2(9, -11), 5.0, 0.0, TAU, 16, dark, 1.2, true)
			"brass_key":
				var brass := Color(0.78, 0.62, 0.26)
				draw_arc(c + Vector2(-7, -3), 5.5, 0.0, TAU, 20, brass, 3.0, true)
				draw_line(c + Vector2(-2, -3), c + Vector2(12, -3), brass, 3.0, true)
				draw_line(c + Vector2(8, -3), c + Vector2(8, 3), brass, 2.6, true)
				draw_line(c + Vector2(12, -3), c + Vector2(12, 4.5), brass, 2.6, true)
			"skylight_crank":
				var steel := Color(0.55, 0.55, 0.62)
				draw_line(c + Vector2(-11, 6), c + Vector2(2, 6), steel, 3.4, true)
				draw_line(c + Vector2(2, 6), c + Vector2(2, -6), steel, 3.4, true)
				draw_line(c + Vector2(2, -6), c + Vector2(11, -6), steel, 3.4, true)
				draw_circle(c + Vector2(11, -6), 3.4, Color(0.75, 0.35, 0.3))
			"elevator_fuse":
				var fuse_glass := Color(0.85, 0.75, 0.5)
				var metal := Color(0.6, 0.6, 0.65)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-8, -4), c + Vector2(8, -4),
					c + Vector2(8, 4), c + Vector2(-8, 4)]), fuse_glass)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-12, -5), c + Vector2(-8, -5),
					c + Vector2(-8, 5), c + Vector2(-12, 5)]), metal)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(8, -5), c + Vector2(12, -5),
					c + Vector2(12, 5), c + Vector2(8, 5)]), metal)
				draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color(0.5, 0.4, 0.25), 1.4, true)
			"palm_frond":
				var dry := Color(0.66, 0.61, 0.32)
				var rib := Color(0.48, 0.44, 0.2)
				draw_colored_polygon(_ellipse(c, 13.5, 4.5, -0.6), dry)
				draw_line(c + Vector2(-11, 8), c + Vector2(11, -8), rib, 1.6, true)
				draw_line(c + Vector2(11, -8), c + Vector2(15, -12), rib, 2.2, true)
			"vine_rope":
				var vine := Color(0.4, 0.5, 0.28)
				var dark_vine := Color(0.28, 0.36, 0.18)
				draw_arc(c, 10.5, 0.3, TAU + 0.1, 28, vine, 3.0, true)
				draw_arc(c, 7.0, -0.6, TAU - 0.9, 24, vine, 3.0, true)
				draw_arc(c, 3.8, 0.9, TAU + 0.4, 18, dark_vine, 2.6, true)
			"brass_clapper":
				var brass2 := Color(0.78, 0.62, 0.26)
				draw_line(c + Vector2(0, -10), c + Vector2(0, 6), brass2, 3.0, true)
				draw_circle(c + Vector2(0, 9), 4.5, brass2)
				draw_circle(c + Vector2(0, -10), 2.6, Color(0.6, 0.48, 0.2))
			"dog_biscuits":
				var biscuit := Color(0.72, 0.55, 0.3)
				for off: Vector2 in [Vector2(-5, -4), Vector2(5, 2)]:
					draw_circle(c + off + Vector2(-6, 0), 3.2, biscuit)
					draw_circle(c + off + Vector2(6, 0), 3.2, biscuit)
					draw_rect(Rect2(c + off + Vector2(-6, -2.4), Vector2(12, 4.8)), biscuit)
			"paw_key":
				var steel2 := Color(0.7, 0.66, 0.5)
				var ink := Color(0.3, 0.25, 0.2)
				draw_arc(c + Vector2(-7, 0), 5.0, 0.0, TAU, 20, steel2, 3.0, true)
				draw_line(c + Vector2(-2, 0), c + Vector2(11, 0), steel2, 3.0, true)
				draw_line(c + Vector2(7, 0), c + Vector2(7, 5), steel2, 2.4, true)
				draw_circle(c + Vector2(-7, 0), 2.0, ink)
				for off: Vector2 in [Vector2(-9.5, -2), Vector2(-7, -3), Vector2(-4.5, -2)]:
					draw_circle(c + off, 0.9, ink)
			"tennis_ball":
				var felt := Color(0.78, 0.88, 0.3)
				var seam := Color(0.9, 0.95, 0.85)
				draw_circle(c, 11.0, felt)
				draw_arc(c + Vector2(-7, 0), 10.0, -0.9, 0.9, 16, seam, 2.0, true)
				draw_arc(c + Vector2(7, 0), 10.0, PI - 0.9, PI + 0.9, 16, seam, 2.0, true)
				draw_circle(c + Vector2(4, -5), 1.4, Color(0.55, 0.6, 0.25))
			"cream_jug":
				var jug := Color(0.93, 0.9, 0.82)
				var band := Color(0.5, 0.65, 0.75)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-7, 12), c + Vector2(-9, -2), c + Vector2(-5, -8),
					c + Vector2(5, -8), c + Vector2(9, -2), c + Vector2(7, 12)]), jug)
				draw_rect(Rect2(c + Vector2(-8, 0), Vector2(16, 4)), band)
				draw_arc(c + Vector2(0, -8), 4.0, PI, TAU, 12, Color(0.7, 0.66, 0.6), 2.0, true)
			"frozen_mitten":
				var mitt := Color(0.8, 0.3, 0.28)
				draw_colored_polygon(_ellipse(c + Vector2(0, -2), 8.0, 10.0), mitt)
				draw_colored_polygon(_ellipse(c + Vector2(-8, 2), 4.0, 5.0, 0.5), mitt)
				draw_rect(Rect2(c + Vector2(-6, 8), Vector2(12, 5)), Color(0.9, 0.88, 0.85))
			"frozen_scarf":
				var scarf := Color(0.35, 0.5, 0.75)
				draw_rect(Rect2(c + Vector2(-11, -8), Vector2(22, 6)), scarf)
				draw_rect(Rect2(c + Vector2(2, -8), Vector2(7, 18)), scarf)
				for k in 3:
					draw_line(c + Vector2(3 + k * 2.4, 10), c + Vector2(3 + k * 2.4, 14), scarf, 1.6, true)
			"frozen_sock":
				var sock := Color(0.8, 0.3, 0.28)
				draw_rect(Rect2(c + Vector2(-3, -11), Vector2(7, 13)), sock)
				draw_colored_polygon(_ellipse(c + Vector2(-4, 6), 7.0, 5.0), sock)
				draw_rect(Rect2(c + Vector2(-3, -12), Vector2(7, 3.4)), Color(0.9, 0.88, 0.85))
			"cocoa_thermos":
				var thermos := Color(0.75, 0.35, 0.25)
				draw_rect(Rect2(c + Vector2(-6, -8), Vector2(12, 19)), thermos)
				draw_rect(Rect2(c + Vector2(-6, -12), Vector2(12, 5)), Color(0.85, 0.82, 0.78))
				draw_line(c + Vector2(-3, 2), c + Vector2(3, 2), Color(0.9, 0.85, 0.8), 2.0, true)
			"runner_wax":
				var tin := Color(0.85, 0.6, 0.3)
				draw_circle(c, 10.5, tin)
				draw_arc(c, 10.5, 0.0, TAU, 28, Color(0.6, 0.42, 0.2), 2.0, true)
				draw_arc(c, 6.0, 0.0, TAU, 20, Color(0.6, 0.42, 0.2), 1.4, true)
			"road_salt":
				var bag := Color(0.6, 0.75, 0.85)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-8, 12), c + Vector2(-6, -6), c + Vector2(-3, -10),
					c + Vector2(3, -10), c + Vector2(6, -6), c + Vector2(8, 12)]), bag)
				for off: Vector2 in [Vector2(-3, 2), Vector2(2, 5), Vector2(0, -1)]:
					draw_circle(c + off, 1.2, Color(0.95, 0.97, 1.0))
			"runner_bolts":
				var steel3 := Color(0.6, 0.62, 0.68)
				for off: Vector2 in [Vector2(-6, -5), Vector2(6, -5), Vector2(-6, 6), Vector2(6, 6)]:
					draw_circle(c + off, 3.6, steel3)
					draw_circle(c + off, 1.3, Color(0.35, 0.36, 0.4))
			"old_loonie":
				var gold2 := Color(0.85, 0.72, 0.3)
				draw_circle(c, 10.5, gold2)
				draw_arc(c, 10.5, 0.0, TAU, 28, Color(0.62, 0.5, 0.2), 2.0, true)
				draw_colored_polygon(_ellipse(c + Vector2(0, 1), 4.5, 3.0), Color(0.62, 0.5, 0.2))
				draw_circle(c + Vector2(3, -3), 1.4, Color(0.62, 0.5, 0.2))
			_:
				draw_circle(c, 10.0, Color(0.6, 0.55, 0.45))
				draw_arc(c, 10.0, 0.0, TAU, 24, Color(0.4, 0.35, 0.28), 2.0, true)

	func _ellipse(center: Vector2, a: float, b: float, rot := 0.0) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 24:
			var t := TAU * i / 24.0
			pts.append(center + Vector2(cos(t) * a, sin(t) * b).rotated(rot))
		return pts

static func parchment_style(alpha := 1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.89, 0.76, alpha)
	sb.border_color = Color(0.5, 0.38, 0.24)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 8
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	vocal_label.text = ""
	_apply_storybook_theme()
	_build_location_label()
	_build_objective()
	_build_message_box()
	_build_slots()
	# Items live in the journal's Satchel (Tab); no persistent bar on screen.
	inventory_bar.visible = false
	GameState.letter_opened.connect(_show_letter)
	GameState.flag_changed.connect(_on_flag_changed)
	Inventory.changed.connect(_refresh_slots)
	Inventory.changed.connect(_update_objective)
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.vocalized.connect(_on_vocal)
		player.vocal_unknown.connect(_on_vocal_unknown)

func _process(delta: float) -> void:
	if _vocal_timer > 0.0:
		_vocal_timer -= delta
		if _vocal_timer <= 0.0:
			vocal_label.text = ""
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			var t := create_tween()
			t.tween_property(_msg_panel, "modulate:a", 0.0, 0.35)
			t.tween_callback(func() -> void: _msg_panel.visible = false)
	if is_instance_valid(player) and not get_tree().paused:
		prompt.text = player.get_prompt_text()

func _apply_storybook_theme() -> void:
	letter_panel.add_theme_stylebox_override("panel", parchment_style())
	var letter_text: RichTextLabel = letter_panel.get_node("Margin/VBox/LetterText")
	letter_text.add_theme_color_override("default_color", INK)
	var close_hint: Label = letter_panel.get_node("Margin/VBox/CloseHint")
	close_hint.add_theme_color_override("font_color", Color(0.5, 0.38, 0.24))
	for lbl: Label in [prompt, vocal_label]:
		lbl.add_theme_color_override("font_color", Color(0.97, 0.94, 0.85))
		lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.14, 0.08))
		lbl.add_theme_constant_override("outline_size", 8)

func _build_location_label() -> void:
	_location_label = Label.new()
	_location_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_location_label.offset_top = 90.0
	_location_label.offset_bottom = 150.0
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location_label.add_theme_font_size_override("font_size", 40)
	_location_label.add_theme_color_override("font_color", Color(0.97, 0.94, 0.85))
	_location_label.add_theme_color_override("font_outline_color", Color(0.2, 0.14, 0.08))
	_location_label.add_theme_constant_override("outline_size", 10)
	_location_label.modulate.a = 0.0
	add_child(_location_label)

func _build_objective() -> void:
	_objective_panel = PanelContainer.new()
	_objective_panel.add_theme_stylebox_override("panel", parchment_style(0.82))
	_objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_objective_panel.offset_left = 20.0
	_objective_panel.offset_top = 20.0
	_objective_panel.visible = false
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	_objective_panel.add_child(margin)
	_objective_label = Label.new()
	_objective_label.custom_minimum_size = Vector2(330, 0)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_font_size_override("font_size", 16)
	_objective_label.add_theme_color_override("font_color", INK)
	margin.add_child(_objective_label)
	add_child(_objective_panel)
	_update_objective()

func _on_flag_changed(_flag: String, _value: bool) -> void:
	_update_objective()

func _update_objective() -> void:
	var text := _current_objective_text()
	if text == _last_objective:
		return
	var had_previous := not _last_objective.is_empty()
	_last_objective = text
	if text.is_empty():
		_objective_panel.visible = false
		return
	_objective_label.text = text
	_objective_panel.visible = true
	_objective_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_objective_panel, "modulate:a", 1.0, 0.6)
	if had_previous and GameState.get_flag("intro_done"):
		Sfx.play("pickup_chime", 1.3, 0.0, -16.0)

## The current riddle, as an in-world nudge — points where to look, never
## spoils the answer. Priority-ordered over the island's beats.
func _current_objective_text() -> String:
	if not GameState.get_flag("intro_done"):
		return ""
	if GameState.get_flag("island1_complete"):
		# The mall chain only speaks while island 2 is actually in progress —
		# jumping ahead (which grants island2_complete) must silence it.
		if not GameState.get_flag("island2_complete"):
			if not GameState.knows_vocal("hiss"):
				return "A glass mall hums on the water… and something small and angry patrols its floors."
			if not GameState.get_flag("mall_time_3"):
				return "Every stair runs the wrong way. A clock hangs stuck above the fountain, and the directory by the doors remembers the mall's habits."
			if not GameState.get_flag("fountain_wish_made"):
				return "The fountain keeps old wishes. A mosaic under the water remembers three coins. Pay it in kind, in order."
			if not GameState.get_flag("mannequin_shop_open"):
				return "The fountain's brass key is warm in her satchel. A dark shop past the east escalator has been locked for years."
			if not GameState.get_flag("mannequins_posed"):
				return "Four dancers wait for their pose. The poster reads one way from the atrium… and another way from inside the glass."
			if not GameState.get_flag("pigeon_parliament_solved"):
				return "Pigeons have claimed the west tiles, and meows amuse them. They flee sharper sounds… always away from her, one tile at a time. The four grated tiles hum underneath."
			if not GameState.get_flag("skylight_open"):
				return "The drummer's crank wants a socket. The balcony above the atrium keeps one, near the skylight's edge."
			if not GameState.get_flag("mall_sunset"):
				return "Open sky above the frozen flock… now the light must lean. Evening reaches every mall at 6 o'clock."
			return "Sixty shadows point at the dark elevator, and it hungers for its glass fuse. Then: the roof, and the great banner."
		var mgr := get_tree().get_first_node_in_group("island_manager")
		if mgr and mgr.current_island and mgr.current_island.name == "Winnipeg":
			if GameState.get_flag("island4_complete"):
				return "The crescent sleeps under brand-new tracks. Somewhere warm, an indoor sea waits. (Island 5 coming soon)"
			if not GameState.get_flag("drift_line_done"):
				return "The squall stole the laundry off the line. Meow at the lumps in the drifts… somebody here was born to dig."
			if not GameState.get_flag("rink_done"):
				return "An old puck waits on the backyard rink, and the target circle is nowhere near the boards. Snow will not pack on ice. A dog on a stay, though…"
			if not GameState.get_flag("mailbox_done"):
				return "Six red flags, and a squall that hates neat rows. The curb numbers only read from the top of the slide: odd up, even down, all in one stillness."
			if not GameState.get_flag("swing_done"):
				return "The swing remembers how to fly. Pump with the rhythm, let go with courage, and see what the rooftops keep."
			if not GameState.get_flag("sled_ready"):
				return "Salt for the frozen gate at the top of the ridge. Wax and bolts for whatever sleeps under it."
			return "Six gates under the drifts, marked by little red flags. She marks, he digs. Then: the ride."
		if mgr and mgr.current_island and mgr.current_island.name == "Calgary":
			if GameState.get_flag("island3_complete"):
				return "Prince's Island hums with summer, two friends in a canoe. Winter waits east: Winnipeg. (travel from the pause menu)"
			if not GameState.get_flag("regatta_done"):
				return "Paper boats lie becalmed on the lagoon. The cottonwood fluff knows when the breeze comes… and the little weir decides what passes the narrows."
			if not GameState.get_flag("ice_cream_done"):
				return "A brass clapper wants a bell. The old ice-cream cart wears four painted notes: the vendor's round, rung just so."
			if not GameState.get_flag("kite_freed"):
				return "A kite thrashes at the top of the red bridge. Grab it when the fluff rests… and mind where its string leads."
			if not GameState.get_flag("gopher_semaphore_done"):
				return "The gophers keep something buried. A crayon map under a picnic table knows their doors by number, and meows carry underground."
			if not GameState.get_flag("meadow_open"):
				return "The howl comes from the fenced meadow at the north point. The vendor's spare key wears a paw."
			if not GameState.get_flag("oreo_untangled"):
				return "The run-line loops tree, bench, and stone, wound in that order. Walk it backwards, and it lets go."
			if not GameState.get_flag("oreo_joined"):
				return "Free is not the same as friends. Cream, biscuits… and one good throw."
			return "The canoe on the gravel bar is heavy, and she is small. Her new friend knows the way to the water."
		return "The Bow runs turquoise around a green park island, and something there is howling for company. (travel from the pause menu)"
	if GameState.get_flag("set_sail_started"):
		return ""
	if not GameState.get_flag("letter_read"):
		return "Reach the bottle on the south beach."
	if not GameState.get_flag("echo_stones_solved"):
		return "The letter is torn, but the island is humming. Three hollow stones wait by the eastern cove, and a carving remembers their song. (press M to meow)"
	if not GameState.get_flag("seesaw_gate_open"):
		return "Something sleeps behind the vine gate on the west hillside. Old wood tips under heavy things, and the palms drop them."
	if not GameState.get_flag("sundial_shell_placed"):
		return "Atop the old summit, a dial waits for its golden heart."
	if not GameState.get_flag("raft_released"):
		return "The shell's shadow points far across the water. Climb where it leads, and speak."
	if not GameState.get_flag("raft_frame_beached"):
		return "Loose timbers drift toward the south beach…"
	var rig := get_tree().get_first_node_in_group("raft_rigging")
	if rig and not rig._complete():
		return "Bind the raft. It still wants %s. The den keeps an oar, the tallest palm a dry frond, and the crab trades for a price." % rig._missing_text()
	return "The raft is ready. The sea is waiting."

## Fades in a "~ Echo Cove ~" style card when entering a named place.
func show_location(title: String) -> void:
	# Travel calls this on every island swap: the objective tracker must
	# re-read the world, or it keeps narrating the island she just left.
	_update_objective()
	if _location_tween and _location_tween.is_valid():
		_location_tween.kill()
	_location_label.text = "~  %s  ~" % title
	_location_tween = create_tween()
	_location_tween.tween_property(_location_label, "modulate:a", 1.0, 0.6)
	_location_tween.tween_interval(2.2)
	_location_tween.tween_property(_location_label, "modulate:a", 0.0, 0.9)

func _build_slots() -> void:
	for i in Inventory.max_slots:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(52, 52)
		slot.add_theme_stylebox_override("panel", parchment_style(0.85))
		var paw := PawMark.new()
		paw.name = "PawMark"
		paw.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(paw)
		_paw_marks.append(paw)
		var icon := ItemIcon.new()
		icon.name = "ItemIcon"
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.visible = false
		slot.add_child(icon)
		_icons.append(icon)
		var count_lbl := Label.new()
		count_lbl.name = "CountLabel"
		count_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		count_lbl.offset_right = -3.0
		count_lbl.offset_bottom = -1.0
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_lbl.add_theme_font_size_override("font_size", 12)
		count_lbl.add_theme_color_override("font_color", INK)
		slot.add_child(count_lbl)
		_slot_counts.append(count_lbl)
		inventory_bar.add_child(slot)
		_slots.append(slot)

func _refresh_slots() -> void:
	for i in _slots.size():
		var filled := i < Inventory.stacks.size()
		var icon: ItemIcon = _icons[i]
		icon.visible = filled
		if filled:
			var stack: Dictionary = Inventory.stacks[i]
			icon.item_id = stack.id
			icon.queue_redraw()
			_slot_counts[i].text = ("×%d" % stack.count) if stack.count > 1 else ""
			_slots[i].tooltip_text = Inventory.display_name(stack.id)
		else:
			_slot_counts[i].text = ""
			_slots[i].tooltip_text = ""
		_paw_marks[i].visible = not filled

## A traditional text box: bottom-centre parchment panel with word wrap.
func _build_message_box() -> void:
	_msg_panel = PanelContainer.new()
	_msg_panel.add_theme_stylebox_override("panel", parchment_style(0.93))
	_msg_panel.anchor_left = 0.5
	_msg_panel.anchor_right = 0.5
	_msg_panel.anchor_top = 1.0
	_msg_panel.anchor_bottom = 1.0
	_msg_panel.offset_left = -370.0
	_msg_panel.offset_right = 370.0
	_msg_panel.offset_top = -168.0
	_msg_panel.offset_bottom = -78.0
	_msg_panel.visible = false
	_msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_panel.add_child(margin)
	_msg_label = Label.new()
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 18)
	_msg_label.add_theme_color_override("font_color", INK)
	_msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_msg_label)
	add_child(_msg_panel)

func flash_message(text: String, dur := 3.0) -> void:
	_msg_label.text = text
	_msg_panel.visible = true
	_msg_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_msg_panel, "modulate:a", 1.0, 0.25)
	_msg_timer = dur

func _on_vocal(kind: String) -> void:
	vocal_label.text = VOCAL_TEXT.get(kind, "")
	_vocal_timer = 1.2

func _on_vocal_unknown(kind: String) -> void:
	vocal_label.text = VOCAL_UNKNOWN_TEXT.get(kind, "")
	_vocal_timer = 1.6

var _letter_base := ""

func _show_letter() -> void:
	var letter_text: RichTextLabel = letter_panel.get_node("Margin/VBox/LetterText")
	if _letter_base.is_empty():
		_letter_base = letter_text.text
	var extra := ""
	if GameState.get_flag("letter_fragment_1"):
		extra += "\n\nA recovered scrap, tucked in the raft's knots:\n“… one final …”"
	if GameState.get_flag("letter_fragment_2"):
		extra += "\n\nA scrap that fell from the mall's banner:\n“… not supposed to …”"
	if GameState.get_flag("letter_fragment_3"):
		extra += "\n\nA scrap that slipped from a friendly collar:\n“Could I …”"
	if GameState.get_flag("letter_fragment_4"):
		extra += "\n\nA scrap pinned under a kite reel with no kite:\n“… meet you?”"
	letter_text.text = _letter_base + extra
	letter_panel.visible = true
	get_tree().paused = true
	prompt.text = ""
	Sfx.play("paper_open", 1.0, 0.05, -6.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent) -> void:
	if letter_panel.visible and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		letter_panel.visible = false
		get_tree().paused = false
		Sfx.play("paper_close", 1.0, 0.05, -8.0)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()
		if not _letter_hint_shown:
			_letter_hint_shown = true
			flash_message("A torn letter. And somewhere east, a low hum on the wind.", 4.5)
			_update_objective()
