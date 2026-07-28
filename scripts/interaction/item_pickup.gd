extends Interactable
## A collectible item lying in the world. Disappears into the inventory on pickup.

@export var item_id: String = "item"
@export var display_name: String = "Item"

func _ready() -> void:
	super()
	prompt = "Pick up " + display_name

func interact(_player: Node) -> void:
	if Inventory.add_item(item_id):
		queue_free()
