extends Node
## Headless test for island travel + the Eaton Centre arrival:
## godot --headless --path . res://tools/test_travel.tscn
## Verifies: travel swaps islands and moves the player, the mall builds its
## key nodes, the robot confrontation teaches hiss, and hissing repels it.

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

	var player: Node3D = get_tree().get_first_node_in_group("player")
	main.travel_to("res://scenes/islands/eaton.tscn", Vector3(0, 1.2, 40.0), "eaton", "The Eaton Centre")
	for i in 10:
		await get_tree().process_frame
	assert(main.get_node_or_null("Ahalo") == null, "Ahalo should be freed")
	var eaton: Node = main.get_node_or_null("Eaton")
	assert(eaton != null, "Eaton island should exist")
	assert(eaton.get_node_or_null("Geese") != null, "geese flock missing")
	assert(eaton.get_node_or_null("RobotVac") != null, "robot missing")
	assert(player.global_position.distance_to(Vector3(0, 1.2, 40.0)) < 3.0, "player should arrive at the dock")
	print("travel + island build: OK")

	# Walk into the mall: the robot confronts and Khione learns to hiss.
	assert(not GameState.knows_vocal("hiss"))
	player.global_position = Vector3(0, 1.0, 15.0)
	player.set("velocity", Vector3.ZERO)
	for i in 6:
		await get_tree().physics_frame
	await get_tree().create_timer(3.0).timeout
	assert(GameState.knows_vocal("hiss"), "confrontation should teach hiss")
	print("hiss learned: OK")

	GameState.vocal_used.emit("hiss")
	await get_tree().process_frame
	assert(GameState.get_flag("robot_repelled"), "hiss should repel the robot")
	print("robot repelled: OK")
	print("ALL TRAVEL TESTS PASSED")
	get_tree().quit()
