extends Node
## Dev tool: loads a scene, waits, saves the viewport to a PNG, quits.
## Renders entirely in-engine (no OS screen capture needed).
## Env vars: KH_SCENE (res:// path), KH_WAIT (seconds), KH_OUT (output path).
## Run: KH_SCENE=res://scenes/main.tscn KH_WAIT=4 KH_OUT=/tmp/snap.png \
##      godot --path . res://tools/snapshot.tscn

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	var scene_path := OS.get_environment("KH_SCENE")
	var wait_s := 2.0
	if OS.get_environment("KH_WAIT") != "":
		wait_s = float(OS.get_environment("KH_WAIT"))
	var out := OS.get_environment("KH_OUT")
	if out.is_empty():
		out = "user://snap.png"
	if not scene_path.is_empty():
		var s: Node = load(scene_path).instantiate()
		get_tree().root.add_child(s)
	if OS.get_environment("KH_FAST") == "1":
		await get_tree().process_frame
		var intro := get_tree().root.find_child("IntroSequence", true, false)
		if intro:
			intro.debug_fast_start()
	if OS.get_environment("KH_JOURNAL") != "":
		await get_tree().create_timer(1.0).timeout
		for id: String in ["rusty_locket", "coconut", "coconut", "coconut", "old_oar"]:
			Inventory.add_item(id)
		GameState.set_flag("letter_read")
		GameState.set_flag("echo_stones_solved")
		var j := get_tree().root.find_child("Journal", true, false)
		if j:
			j._show()
			j._select_tab(int(OS.get_environment("KH_JOURNAL")))
	var travel := OS.get_environment("KH_TRAVEL")
	if travel != "":
		var dests := {
			"eaton": ["res://scenes/islands/eaton.tscn", Vector3(0, 1.2, 40.0), "The Eaton Centre"],
			"calgary": ["res://scenes/islands/calgary.tscn", Vector3(0, 1.2, 42.0), "Prince's Island"],
			"winnipeg": ["res://scenes/islands/winnipeg.tscn", Vector3(0, 1.2, 42.0), "The Winnipeg Crescent"],
		}
		if dests.has(travel):
			await get_tree().create_timer(0.5).timeout
			var mgr := get_tree().get_first_node_in_group("island_manager")
			if mgr:
				var d: Array = dests[travel]
				mgr.travel_to(d[0], d[1], travel, d[2])
	if OS.get_environment("KH_GOPHERMAP") == "1":
		await get_tree().create_timer(6.0).timeout
		var sem := get_tree().root.find_child("GopherSemaphore", true, false)
		if sem:
			sem.show_map()
	if OS.get_environment("KH_RAFT") == "1":
		await get_tree().create_timer(1.0).timeout
		var sundial := get_tree().root.find_child("SundialReef", true, false)
		if sundial:
			sundial._release_raft()
	if OS.get_environment("KH_HIDEWATER") == "1":
		for island in get_tree().get_first_node_in_group("island_manager").get_children():
			if island is Node3D:
				for c in island.get_children():
					if c is MeshInstance3D and c.material_override is ShaderMaterial \
							and c.mesh is PlaneMesh:
						c.visible = false
	if OS.get_environment("KH_HIDEGLASS") == "1":
		for island in get_tree().get_first_node_in_group("island_manager").get_children():
			if island is Node3D:
				for c in island.get_children():
					if c is MeshInstance3D and c.material_override is StandardMaterial3D \
							and (c.material_override as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						c.visible = false
	if OS.get_environment("KH_NOLIGHTS") == "1":
		for island in get_tree().get_first_node_in_group("island_manager").get_children():
			if island is Node3D:
				for c in island.get_children():
					if c is OmniLight3D:
						c.visible = false
	var msg := OS.get_environment("KH_MSG")
	if not msg.is_empty():
		var hud := get_tree().root.find_child("HUD", true, false)
		if hud:
			hud.flash_message(msg, 30.0)
	var cam_spec := OS.get_environment("KH_CAM")  # "px,py,pz|tx,ty,tz"
	if not cam_spec.is_empty():
		var parts := cam_spec.split("|")
		var p := parts[0].split_floats(",")
		var t := parts[1].split_floats(",")
		var cam := Camera3D.new()
		get_tree().root.add_child(cam)
		cam.global_position = Vector3(p[0], p[1], p[2])
		cam.look_at(Vector3(t[0], t[1], t[2]))
		cam.current = true
	await get_tree().create_timer(wait_s).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("snapshot saved: ", out)
	get_tree().quit()
