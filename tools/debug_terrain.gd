extends Node
func _ready() -> void:
	_run()
func _run() -> void:
	await get_tree().process_frame
	var ahalo: Node3D = load("res://scenes/islands/ahalo.tscn").instantiate()
	get_tree().root.add_child(ahalo)
	for i in 5:
		await get_tree().process_frame
	for p in [Vector2(0, 0), Vector2(8, 0), Vector2(15, 0), Vector2(25, 0), Vector2(35, 0), Vector2(45, 0)]:
		print("h(", p, ") = ", ahalo._terrain_height(p.x, p.y))
	for c in ahalo.get_children():
		if c is MeshInstance3D and c.mesh is ArrayMesh:
			var aabb: AABB = c.get_aabb()
			print("terrain AABB pos=", aabb.position, " size=", aabb.size)
			break
	get_tree().quit()
