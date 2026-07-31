extends Node
## Khione's inventory: 5 slots, upgradable to 10 later in the game.

signal changed

const NAMES := {
	"sun_shell": "Sun Shell",
	"coconut": "Coconut",
	"rusty_locket": "Rusty Locket",
	"stranded_fish": "Stranded Fish",
	"old_oar": "Old Oar",
	"palm_frond": "Dry Frond",
	"vine_rope": "Vine Rope",
}

var max_slots: int = 5
var items: Array[String] = []

const DESCRIPTIONS := {
	"sun_shell": "A golden scallop, warm to the touch — shaped like it was made for something.",
	"coconut": "Heavy, hairy, and full of promise. Old wood would tip under a few of these.",
	"rusty_locket": "Sea-worn bronze from the tide pool. The engraving inside is a pawprint — far too big for a cat.",
	"stranded_fish": "Left behind when the pool drained. Somebody out there looks hungry.",
	"old_oar": "Smooth with years of use. Whose paws wore it smooth?",
	"palm_frond": "A great dry frond — practically a sail already.",
	"vine_rope": "Fresh-cut vine, crab-approved. Strong enough to bind timbers.",
}

func display_name(id: String) -> String:
	return NAMES.get(id, id.capitalize())

func description(id: String) -> String:
	return DESCRIPTIONS.get(id, "Something the island offered up.")

func add_item(id: String) -> bool:
	if items.size() >= max_slots:
		return false
	items.append(id)
	changed.emit()
	return true

func remove_item(id: String) -> bool:
	var idx := items.find(id)
	if idx == -1:
		return false
	items.remove_at(idx)
	changed.emit()
	return true

func has_item(id: String) -> bool:
	return id in items

func upgrade_slots(new_max: int) -> void:
	max_slots = new_max
	changed.emit()

func reset() -> void:
	items.clear()
	max_slots = 5
	changed.emit()
