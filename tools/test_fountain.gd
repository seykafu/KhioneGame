extends Node
## Headless test for the Fountain of Small Wishes (Island 2, riddle 2):
## godot --headless --path . res://tools/test_fountain.tscn
## Verifies: wrong coin fails and resets the pushed coins, the mosaic order
## (heads, heads, tails) drains the fountain, and the brass key appears.

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

	var puzzle: Node = main.get_node("Eaton/FountainWishes")
	assert(puzzle != null, "fountain puzzle missing")
	assert(puzzle._coins.size() == 8, "expected 8 rim coins")

	# Wrong first coin (tails) fails: pigeon, then everything resets.
	var tails_idx := _find_coin(puzzle, "T", [])
	puzzle.push_coin(tails_idx)
	assert(puzzle._progress == 0, "tails first should not progress")
	await get_tree().create_timer(2.5).timeout
	var pushed := 0
	for c: Dictionary in puzzle._coins:
		if c.pushed:
			pushed += 1
	assert(pushed == 0, "coins should reset after the pigeon")
	print("wrong coin resets: OK")

	# Correct order: heads, heads, tails.
	var used: Array = []
	for want: String in ["H", "H", "T"]:
		var idx := _find_coin(puzzle, want, used)
		used.append(idx)
		puzzle.push_coin(idx)
		await get_tree().process_frame
	assert(GameState.get_flag("fountain_wish_made"), "mosaic order should drain the fountain")
	print("mosaic order solves: OK")

	await get_tree().create_timer(1.0).timeout
	var key_found := false
	for c in puzzle.get_children():
		if c is Area3D and c.get("item_id") == "brass_key":
			key_found = true
	assert(key_found, "brass key should appear in the drain")
	print("brass key revealed: OK")
	print("ALL FOUNTAIN TESTS PASSED")
	get_tree().quit()

func _find_coin(puzzle: Node, type: String, used: Array) -> int:
	for i in puzzle._coins.size():
		var c: Dictionary = puzzle._coins[i]
		if c.type == type and not c.pushed and not used.has(i):
			return i
	return -1
