extends Node
## Headless test for the Pigeon Parliament (Island 2, riddle 4):
## godot --headless --path . res://tools/test_pigeons.tscn
## Verifies: hissing pushes pigeons away one tile, meows do nothing, and
## four pigeons on the four vents solves it and pops the Elevator Fuse.

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

	var puzzle: Node = main.get_node("Eaton/PigeonParliament")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	assert(puzzle != null and puzzle._pigeons.size() == 4)

	# Meow: pigeons hold their ground.
	player.global_position = Vector3(-11.0, 1.0, -1.0)
	player.set("velocity", Vector3.ZERO)
	for i in 4:
		await get_tree().physics_frame
	var before: Array = []
	for p: Dictionary in puzzle._pigeons:
		before.append(p.cell)
	GameState.vocal_used.emit("meow")
	await get_tree().process_frame
	for i in 4:
		assert(puzzle._pigeons[i].cell == before[i], "meow must not move pigeons")
	print("meow does nothing: OK")

	# Hiss from the south: every pigeon in range steps away (north).
	GameState.vocal_used.emit("hiss")
	await get_tree().process_frame
	var moved := 0
	for i in 4:
		var cell: Vector2i = puzzle._pigeons[i].cell
		if cell != before[i]:
			moved += 1
			assert(cell.y <= (before[i] as Vector2i).y, "pigeons should flee away from the hiss")
	assert(moved >= 3, "most pigeons should scatter")
	print("hiss herds away: OK")

	# Let the hop tweens finish before staging positions directly.
	await get_tree().create_timer(0.7).timeout

	# Stage three pigeons on vents, herd the last one in with a real hiss.
	var cells := [Vector2i(0, 0), Vector2i(0, 3), Vector2i(3, 0), Vector2i(2, 3)]
	for i in 4:
		puzzle._pigeons[i].cell = cells[i]
		(puzzle._pigeons[i].node as Node3D).position = puzzle._cell_world(cells[i]) + Vector3(0, 0.12, 0)
	player.global_position = Vector3(-11.0, 1.0, -3.0)
	player.set("velocity", Vector3.ZERO)
	for i in 4:
		await get_tree().physics_frame
	GameState.vocal_used.emit("hiss")
	await get_tree().process_frame
	assert(GameState.get_flag("pigeon_parliament_solved"), "four birds on four vents should solve")
	print("parliament seated: OK")

	await get_tree().create_timer(3.0).timeout
	var fuse_found := false
	for c in puzzle.get_children():
		if c is Area3D and c.get("item_id") == "elevator_fuse":
			fuse_found = true
	assert(fuse_found, "elevator fuse should pop free")
	print("elevator fuse revealed: OK")
	print("ALL PIGEON TESTS PASSED")
	get_tree().quit()
