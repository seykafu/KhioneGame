extends Node
## Cinematic showcase shots for marketing footage, driven by Movie Maker
## mode. Each KH_SHOT is a settle wait followed by a 3-second camera move,
## printed frame-exact so the encoder can trim precisely:
##   godot --path . --write-movie <dir>/f.png --fixed-fps 30 res://tools/showcase.tscn
## Env: KH_SHOT = ahalo | calgary | winnipeg

const FPS := 30.0

## shot -> [travel track or "", settle_seconds, cam_from, cam_to, look_from, look_to]
const SHOTS := {
	"ahalo": ["", 7.0,
		Vector3(58, 24, 40), Vector3(38, 15, 60),
		Vector3(0, 2, 0), Vector3(0, 2, 8)],
	"calgary": ["calgary", 13.0,
		Vector3(10, 2.6, 18), Vector3(-2, 3.2, 8),
		Vector3(-11, 1.2, -2), Vector3(-11, 2.0, -2)],
	"winnipeg": ["winnipeg", 13.0,
		Vector3(10, 2.2, 15), Vector3(-6, 2.8, 12),
		Vector3(-6, 6, -60), Vector3(2, 10, -60)],
}

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	var shot_name := OS.get_environment("KH_SHOT")
	if not SHOTS.has(shot_name):
		push_error("unknown shot: " + shot_name)
		get_tree().quit()
		return
	var shot: Array = SHOTS[shot_name]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 5:
		await get_tree().process_frame
	main.get_node("IntroSequence").debug_fast_start()
	for i in 20:
		await get_tree().process_frame
	if shot[0] != "":
		var dests := {
			"calgary": ["res://scenes/islands/calgary.tscn", Vector3(0, 1.2, 42.0), "Prince's Island"],
			"winnipeg": ["res://scenes/islands/winnipeg.tscn", Vector3(0, 1.2, 42.0), "The Winnipeg Crescent"],
		}
		var d: Array = dests[shot[0]]
		main.travel_to(d[0], d[1], shot[0], d[2])
	# Hide every UI layer: footage wants the world, not the HUD.
	await get_tree().process_frame
	for c in main.get_children():
		if c is CanvasLayer:
			c.visible = false
	var hud := main.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	var cam := Camera3D.new()
	get_tree().root.add_child(cam)
	cam.global_position = shot[2]
	cam.look_at(shot[4])
	cam.current = true
	await get_tree().create_timer(shot[1]).timeout
	# Keep overlays hidden right up to the take (arrival fades, cards).
	for c in main.get_children():
		if c is CanvasLayer:
			c.visible = false
	print("SHOT_START_FRAME=", Engine.get_frames_drawn())
	var move := create_tween()
	var step := func(t: float) -> void:
		cam.global_position = (shot[2] as Vector3).lerp(shot[3], t)
		var look := (shot[4] as Vector3).lerp(shot[5], t)
		cam.look_at(look)
	move.tween_method(step, 0.0, 1.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await move.finished
	print("SHOT_END_FRAME=", Engine.get_frames_drawn())
	get_tree().quit()
