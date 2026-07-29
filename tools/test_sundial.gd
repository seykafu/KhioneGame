extends Node
## Headless test for the Sundial Reef:
## godot --headless --path . res://tools/test_sundial.tscn
## Verifies: decoy rocks don't release the raft, the shell slots only when
## carried, and meowing atop the target rock releases + beaches the raft.

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

	var puzzle: Node = main.get_node("Ahalo/SundialReef")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	assert(puzzle != null and player != null)

	# Decoy rock: gulls scatter, nothing releases.
	player.global_position = (puzzle.DECOY_ROCKS[0] as Vector3) + Vector3(0.4, 3.0, 0)
	player.set("velocity", Vector3.ZERO)
	for i in 4:
		await get_tree().physics_frame
	GameState.vocal_used.emit("meow")
	await get_tree().process_frame
	assert(not puzzle._raft_released, "decoy must not release the raft")
	print("decoy rock: OK")

	# Sundial: refuses without the shell, accepts with it.
	puzzle.sundial_interact()
	assert(not GameState.get_flag("sundial_shell_placed"), "no shell yet")
	Inventory.add_item("sun_shell")
	puzzle.sundial_interact()
	assert(GameState.get_flag("sundial_shell_placed"), "shell should be placed")
	assert(not Inventory.has_item("sun_shell"), "shell should be consumed")
	print("sundial placement: OK")

	# Target rock: meow from the top releases the raft.
	player.global_position = puzzle.TARGET_ROCK + Vector3(0.3, 3.0, 0)
	player.set("velocity", Vector3.ZERO)
	for i in 4:
		await get_tree().physics_frame
	GameState.vocal_used.emit("meow")
	await get_tree().process_frame
	assert(puzzle._raft_released, "target rock should release the raft")
	print("gull rock meow: OK")

	await get_tree().create_timer(10.5).timeout
	assert(GameState.get_flag("raft_frame_beached"), "raft should reach the beach")
	assert(puzzle.get_node_or_null("RaftFrame") != null, "raft frame node should exist")
	print("raft beached: OK")
	print("ALL SUNDIAL TESTS PASSED")
	get_tree().quit()
