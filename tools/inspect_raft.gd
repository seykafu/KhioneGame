extends Node
## Dev inspection: releases the raft, waits for beaching, prints where it
## actually is and any large meshes (dunes) near the landing point.
## godot --headless --path . res://tools/inspect_raft.tscn

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 10:
		await get_tree().process_frame
	main.get_node("IntroSequence").debug_fast_start()
	for i in 20:
		await get_tree().process_frame
	var sundial: Node = main.get_node("Ahalo/SundialReef")
	sundial._release_raft()
	await get_tree().create_timer(10.5).timeout
	var raft: Node3D = sundial.get_node_or_null("RaftFrame")
	print("beached flag: ", GameState.get_flag("raft_frame_beached"))
	print("raft node: ", raft)
	if raft:
		print("raft global position: ", raft.global_position)
		print("raft visible: ", raft.visible)
		var log0: MeshInstance3D = null
		for c in raft.get_children():
			if c is MeshInstance3D:
				log0 = c
				break
		if log0:
			var aabb: AABB = log0.global_transform * log0.get_aabb()
			print("first log bounds: pos", aabb.position, " size", aabb.size)
	# Large sphere meshes (dunes) near the landing point
	var beach := Vector3(6.0, 0.0, 34.0)
	for c in main.get_node("Ahalo").get_children():
		if c is MeshInstance3D and c.mesh is SphereMesh and (c.mesh as SphereMesh).radius > 3.0:
			var d := Vector2(c.global_position.x - beach.x, c.global_position.z - beach.z).length()
			if d < 14.0:
				print("DUNE r=%.1f h=%.1f at %s (%.1fm from landing)" % [
						(c.mesh as SphereMesh).radius, (c.mesh as SphereMesh).height,
						c.global_position, d])
	get_tree().quit()
