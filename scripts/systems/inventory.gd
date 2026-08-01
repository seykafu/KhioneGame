extends Node
## Khione's satchel: 5 pockets to start, and one new pocket for every
## island finished (islandN_complete flags). Identical items stack into
## one pocket with a count.

signal changed

const BASE_SLOTS := 5

func _ready() -> void:
	GameState.flag_changed.connect(_on_flag_changed)

func _on_flag_changed(flag: String, value: bool) -> void:
	if not value or not flag.begins_with("island") or not flag.ends_with("_complete"):
		return
	var completed := 0
	for f in GameState.flags:
		if String(f).begins_with("island") and String(f).ends_with("_complete") and GameState.flags[f]:
			completed += 1
	if BASE_SLOTS + completed != max_slots:
		max_slots = BASE_SLOTS + completed
		changed.emit()

const NAMES := {
	"sun_shell": "Sun Shell",
	"coconut": "Coconut",
	"rusty_locket": "Rusty Locket",
	"stranded_fish": "Stranded Fish",
	"old_oar": "Old Oar",
	"palm_frond": "Dry Frond",
	"vine_rope": "Vine Rope",
}

const DESCRIPTIONS := {
	"sun_shell": "A golden scallop, warm to the touch. Shaped like it was made for something.",
	"coconut": "Heavy, hairy, and full of promise. Old wood would tip under a few of these.",
	"rusty_locket": "Sea-worn bronze from the tide pool. The engraving inside is a pawprint far too big for a cat.",
	"stranded_fish": "Left behind when the pool drained. Somebody out there looks hungry.",
	"old_oar": "Smooth with years of use. Whose paws wore it smooth?",
	"palm_frond": "A great dry frond. Practically a sail already.",
	"vine_rope": "Fresh-cut vine, crab-approved. Strong enough to bind timbers.",
}

var max_slots: int = 5
var stacks: Array[Dictionary] = []  # ordered [{id: String, count: int}]

func display_name(id: String) -> String:
	return NAMES.get(id, id.capitalize())

func description(id: String) -> String:
	return DESCRIPTIONS.get(id, "Something the island offered up.")

func add_item(id: String) -> bool:
	for s in stacks:
		if s.id == id:
			s.count += 1
			changed.emit()
			return true
	if stacks.size() >= max_slots:
		return false
	stacks.append({"id": id, "count": 1})
	changed.emit()
	return true

func remove_item(id: String) -> bool:
	for i in stacks.size():
		if stacks[i].id == id:
			stacks[i].count -= 1
			if stacks[i].count <= 0:
				stacks.remove_at(i)
			changed.emit()
			return true
	return false

func has_item(id: String) -> bool:
	for s in stacks:
		if s.id == id:
			return true
	return false

func count_of(id: String) -> int:
	for s in stacks:
		if s.id == id:
			return s.count
	return 0

func upgrade_slots(new_max: int) -> void:
	max_slots = new_max
	changed.emit()

func reset() -> void:
	stacks.clear()
	max_slots = BASE_SLOTS
	changed.emit()
