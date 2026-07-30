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
	await get_tree().create_timer(wait_s).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("snapshot saved: ", out)
	get_tree().quit()
