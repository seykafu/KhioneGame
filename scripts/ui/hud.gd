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
var _location_label: Label
var _location_tween: Tween

class PawMark:
	extends Control
	## Faint toe-bean watermark drawn in empty inventory slots.

	func _draw() -> void:
		var c := Color(0.5, 0.38, 0.24, 0.28)
		var ctr := size / 2.0
		draw_circle(ctr + Vector2(0, 6), 9.0, c)
		for off: Vector2 in [Vector2(-12, -5), Vector2(-4.5, -10), Vector2(4.5, -10), Vector2(12, -5)]:
			draw_circle(ctr + off, 4.2, c)

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
	_build_slots()
	GameState.letter_opened.connect(_show_letter)
	Inventory.changed.connect(_refresh_slots)
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

## Fades in a "~ Echo Cove ~" style card when entering a named place.
func show_location(title: String) -> void:
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
		var lbl := Label.new()
		lbl.name = "ItemLabel"
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.clip_text = true
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", INK)
		slot.add_child(lbl)
		inventory_bar.add_child(slot)
		_slots.append(slot)

func _refresh_slots() -> void:
	for i in _slots.size():
		var lbl: Label = _slots[i].get_node("ItemLabel")
		lbl.text = Inventory.display_name(Inventory.items[i]) if i < Inventory.items.size() else ""
		_paw_marks[i].visible = i >= Inventory.items.size()

func flash_message(text: String, dur := 3.0) -> void:
	vocal_label.text = text
	_vocal_timer = dur

func _on_vocal(kind: String) -> void:
	vocal_label.text = VOCAL_TEXT.get(kind, "")
	_vocal_timer = 1.2

func _on_vocal_unknown(kind: String) -> void:
	vocal_label.text = VOCAL_UNKNOWN_TEXT.get(kind, "")
	_vocal_timer = 1.6

func _show_letter() -> void:
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
