extends Interactable
## A collectible item lying in the world. Disappears into the inventory on pickup.

@export var item_id: String = "item"
@export var display_name: String = "Item"

func _ready() -> void:
	super()
	prompt = "Pick up " + display_name

func interact(_player: Node) -> void:
	if Inventory.add_item(item_id):
		Sfx.play("pickup_chime", 1.0, 0.04, -4.0)
		var hud := get_node_or_null("/root/Main/HUD")
		if hud:
			hud.flash_message("+  " + display_name, 2.0)
		queue_free()
