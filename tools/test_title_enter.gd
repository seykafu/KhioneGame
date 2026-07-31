extends Node
## Reproduction test: does pressing Enter (and Space) advance the title screen?
## godot --headless --path . res://tools/test_title_enter.tscn

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 30:
		await get_tree().process_frame
	var intro: Node = main.get_node("IntroSequence")
	print("state before Enter: ", intro._state)

	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 3:
		await get_tree().process_frame
	print("state after Enter: ", intro._state)

	if intro._state == 0:
		var sp := InputEventKey.new()
		sp.keycode = KEY_SPACE
		sp.physical_keycode = KEY_SPACE
		sp.pressed = true
		Input.parse_input_event(sp)
		for i in 3:
			await get_tree().process_frame
		print("state after Space: ", intro._state)
	get_tree().quit()
