extends Node
## Headless test for the Echo Stones puzzle:
## godot --headless --path . res://tools/test_echo_stones.tscn
## Verifies: wrong order resets progress, right order sets the solved flag
## and reveals the two cache pickups.

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 5:
		await get_tree().process_frame
	main.get_node("IntroSequence")._skipped = true
	for i in 20:
		await get_tree().process_frame

	var player: Node3D = get_tree().get_first_node_in_group("player")
	var puzzle: Node = main.get_node("Ahalo/EchoStones")
	assert(player != null, "player missing")
	assert(puzzle.stones.size() == 3, "expected 3 stones")

	# Wrong order first: large stone (idx 2) is not the expected start.
	await _meow_at(player, puzzle, 2)
	assert(puzzle._progress == 0, "wrong order should reset progress")
	print("wrong-order reset: OK")

	# Correct order: small (0) -> medium (1) -> large (2).
	for idx in [0, 1, 2]:
		await _meow_at(player, puzzle, idx)
	assert(GameState.get_flag("echo_stones_solved"), "puzzle should be solved")
	print("solved flag: OK")

	# Wait (real seconds — headless frames outpace the clock) for the drain
	# tween to finish and the cache to spawn.
	await get_tree().create_timer(3.5).timeout
	var pickups := 0
	for c in puzzle.get_children():
		if c is Area3D and c.get("item_id") != null:
			pickups += 1
	assert(pickups == 2, "expected 2 cache pickups, got %d" % pickups)
	print("cache pickups: OK")
	print("ALL ECHO STONES TESTS PASSED")
	get_tree().quit()

func _meow_at(player: Node3D, puzzle: Node, idx: int) -> void:
	player.global_position = puzzle.stones[idx].global_position + Vector3(1.2, 0.4, 0)
	player.set("velocity", Vector3.ZERO)
	for i in 4:
		await get_tree().physics_frame
	GameState.vocal_used.emit("meow")
	await get_tree().process_frame
