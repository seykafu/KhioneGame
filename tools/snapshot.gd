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
