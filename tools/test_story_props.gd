extends Node
## Headless test for Ahalo's story flourishes:
## godot --headless --path . res://tools/test_story_props.tscn
## The buried streetlamp and the nest both exist, both interact, and both
## set their story flags without touching riddle state.

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 5:
		await get_tree().process_frame
	main.get_node("IntroSequence").debug_fast_start()
	for i in 20:
		await get_tree().process_frame

	var lamp: Node = main.get_node("Ahalo/BuriedStreetlamp")
	var nest: Node = main.get_node("Ahalo/KhioneNest")
	assert(lamp != null, "streetlamp missing")
	assert(nest != null, "nest missing")
	assert(lamp.is_in_group("interactable"), "lamp should ping Whisker Sense")
	assert(nest.is_in_group("interactable"), "nest should ping Whisker Sense")

	lamp.interact(null)
	assert(GameState.get_flag("memory_glitch_1"), "lamp should crack the first memory")
	print("streetlamp memory glitch: OK")

	nest.interact(null)
	assert(GameState.get_flag("nest_seen"), "nest should be seen")
	print("nest seen: OK")

	assert(not GameState.get_flag("island1_complete"), "story props must not touch riddle flags")
	print("ALL STORY PROP TESTS PASSED")
	get_tree().quit()
