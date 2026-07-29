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

var player: Node = null
var _vocal_timer := 0.0
var _slots: Array[Panel] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	vocal_label.text = ""
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

func _build_slots() -> void:
	for i in Inventory.max_slots:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(52, 52)
		var lbl := Label.new()
		lbl.name = "ItemLabel"
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.clip_text = true
		slot.add_child(lbl)
		inventory_bar.add_child(slot)
		_slots.append(slot)

func _refresh_slots() -> void:
	for i in _slots.size():
		var lbl: Label = _slots[i].get_node("ItemLabel")
		lbl.text = Inventory.display_name(Inventory.items[i]) if i < Inventory.items.size() else ""

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
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent) -> void:
	if letter_panel.visible and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		letter_panel.visible = false
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()
