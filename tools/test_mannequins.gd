extends Node
## Headless test for the Mannequin Quartet (Island 2, riddle 3):
## godot --headless --path . res://tools/test_mannequins.tscn
## Verifies: door refuses without the key and opens with it, the naive
## poster copy fails (with the backwards tease), the mirrored pose solves,
## and the drummer surrenders the skylight crank.

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
	main.travel_to("res://scenes/islands/eaton.tscn", Vector3(0, 1.2, 40.0), "eaton", "The Eaton Centre")
	for i in 10:
		await get_tree().process_frame

	var puzzle: Node = main.get_node("Eaton/MannequinShop")
	assert(puzzle != null, "mannequin shop missing")

	# Locked without the key.
	assert(not puzzle.try_open_door(), "door should refuse without the key")
	assert(not GameState.get_flag("mannequin_shop_open"))
	Inventory.add_item("brass_key")
	assert(puzzle.try_open_door(), "the brass key should open the door")
	assert(GameState.get_flag("mannequin_shop_open"))
	print("brass key gate: OK")

	# Copying the poster literally: no solve.
	_set_config(puzzle, puzzle.NAIVE)
	assert(not GameState.get_flag("mannequins_posed"), "naive copy must not solve")
	print("naive copy fails: OK")

	# The mirrored pose: solve, and the crank appears.
	_set_config(puzzle, puzzle.TARGET)
	assert(GameState.get_flag("mannequins_posed"), "mirrored pose should solve")
	var crank_found := false
	for c in puzzle.get_children():
		if c is Area3D and c.get("item_id") == "skylight_crank":
			crank_found = true
	assert(crank_found, "skylight crank should appear")
	print("mirrored pose solves, crank revealed: OK")
	print("ALL MANNEQUIN TESTS PASSED")
	get_tree().quit()

func _set_config(puzzle: Node, config: Array) -> void:
	for i in config.size():
		while puzzle._facings[i] != config[i]:
			puzzle.rotate_mannequin(i)
