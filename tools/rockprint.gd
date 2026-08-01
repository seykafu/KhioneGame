extends Node
func _ready() -> void:
	_run()
func _run() -> void:
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 10:
		await get_tree().process_frame
	for c in main.get_node("Ahalo").get_children():
		if c is Node3D and c.name.begins_with("rock_"):
			var p: Vector3 = c.global_position
			var r := Vector2(p.x, p.z).length()
			if r > 40.0:
				print("SEA ROCK %s r=%.1f at (%.1f, %.1f)" % [c.name, r, p.x, p.z])
	get_tree().quit()
