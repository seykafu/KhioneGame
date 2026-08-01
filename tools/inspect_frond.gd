extends Node
## Dev inspection: prints what the FrondPalm puzzle actually built, with
## global positions and mesh bounds, to verify the trio and ledge alignment.
## godot --headless --path . res://tools/inspect_frond.tscn

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 10:
		await get_tree().process_frame
	var frond: Node3D = main.get_node("Ahalo/FrondPalm")
	print("FrondPalm global origin: ", frond.global_position)
	for c in frond.get_children():
		var desc := "%s (%s) at %s" % [c.name, c.get_class(), (c as Node3D).global_position]
		var mi := _fmi(c)
		if mi:
			var aabb: AABB = mi.global_transform * mi.get_aabb()
			desc += "  mesh_bounds: pos%s size%s" % [aabb.position, aabb.size]
		if c is StaticBody3D:
			for cs in c.get_children():
				if cs is CollisionShape3D and cs.shape is BoxShape3D:
					desc += "  LEDGE box size %s at global %s" % [cs.shape.size, cs.global_position]
				elif cs is CollisionShape3D and cs.shape is CylinderShape3D:
					desc += "  TRUNK cyl r%.2f h%.2f at global %s" % [cs.shape.radius, cs.shape.height, cs.global_position]
		print(desc)
	# Nearby scattered palms that could crowd the trio
	var count := 0
	for c in main.get_node("Ahalo").get_children():
		if c is Node3D and c.name.begins_with("tree_"):
			if c.global_position.distance_to(frond.global_position) < 8.0:
				count += 1
				print("NEARBY scattered palm at ", c.global_position)
	print("scattered palms within 8m: ", count)
	get_tree().quit()

func _fmi(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _fmi(c)
		if r:
			return r
	return null
