extends Node
## Dev preview: shows the HUD with every item in inventory so the icons can
## be eyeballed. Run: godot --path . res://tools/preview_icons.tscn

func _ready() -> void:
	var hud: CanvasLayer = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	for id: String in ["sun_shell", "coconut", "rusty_locket", "stranded_fish", "old_oar"]:
		Inventory.add_item(id)
