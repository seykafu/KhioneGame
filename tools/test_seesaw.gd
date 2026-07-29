extends Node
## Headless test for the Driftwood Seesaw:
## godot --headless --path . res://tools/test_seesaw.tscn
## Verifies: empty-paws guard, 3 coconuts open the gate and are consumed,
## and the Old Oar pickup exists in the den.

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

	var puzzle: Node = main.get_node("Ahalo/DriftwoodSeesaw")
	assert(puzzle != null, "seesaw missing")

	puzzle.place_coconut()
	assert(puzzle._placed == 0, "should not place without a coconut")
	print("empty-paws guard: OK")

	for i in 3:
		Inventory.add_item("coconut")
	for i in 3:
		puzzle.place_coconut()
	assert(puzzle._placed == 3, "expected 3 placed")
	assert(GameState.get_flag("seesaw_gate_open"), "gate should open")
	assert(not Inventory.has_item("coconut"), "coconuts should be consumed")
	print("gate opens after 3 coconuts: OK")

	var oar_found := false
	for c in puzzle.get_children():
		if c is Area3D and c.get("item_id") == "old_oar":
			oar_found = true
	assert(oar_found, "old oar pickup missing")
	print("old oar in den: OK")

	await get_tree().create_timer(3.0).timeout
	print("ALL SEESAW TESTS PASSED")
	get_tree().quit()
