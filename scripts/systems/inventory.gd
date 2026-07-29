extends Node
## Khione's inventory: 5 slots, upgradable to 10 later in the game.

signal changed

const NAMES := {
	"sun_shell": "Sun Shell",
	"coconut": "Coconut",
	"rusty_locket": "Rusty Locket",
	"stranded_fish": "Stranded Fish",
	"old_oar": "Old Oar",
}

var max_slots: int = 5
var items: Array[String] = []

func display_name(id: String) -> String:
	return NAMES.get(id, id.capitalize())

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
