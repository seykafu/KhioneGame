extends Node
## Headless test for Make the Flock Fly (Island 2 finale):
## godot --headless --path . res://tools/test_finale.tscn
## Verifies every gate in order: crank opens the skylight, clock-at-6 with
## open sky triggers sunset + shadow flock, fused elevator rides to the
## roof, and the banner glide completes the island with fragment 2.

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
	GameState.set_flag("island1_complete")  # as real travel would have set
	main.travel_to("res://scenes/islands/eaton.tscn", Vector3(0, 1.2, 40.0), "eaton", "The Eaton Centre")
	for i in 10:
		await get_tree().process_frame

	var clock: Node = main.get_node("Eaton/MallClock")
	var finale: Node = main.get_node("Eaton/FlockFinale")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	assert(finale != null, "finale missing")

	# Crank gate.
	finale.use_crank()
	assert(not GameState.get_flag("skylight_open"), "no crank, no sky")
	Inventory.add_item("skylight_crank")
	finale.use_crank()
	assert(GameState.get_flag("skylight_open"), "crank should open the shutters")
	assert(not Inventory.has_item("skylight_crank"), "crank installed")
	print("skylight opens: OK")

	# Sunset gate: turn the clock to 6.
	while clock.clock_hour != 6:
		clock.advance_clock()
	for i in 5:
		await get_tree().process_frame
	assert(GameState.get_flag("mall_sunset"), "6 o'clock under open sky should lean the light")
	print("sunset + shadow flock: OK")

	# Elevator gate.
	finale.elevator_interact()
	assert(not GameState.get_flag("elevator_powered"), "no fuse, no ride")
	Inventory.add_item("elevator_fuse")
	finale.elevator_interact()
	assert(GameState.get_flag("elevator_powered"), "fuse should wake the elevator")
	# The doors open; the player steps aboard herself (simulated here) and
	# the cab carries her up on its physical floor.
	await get_tree().create_timer(2.0).timeout
	player.global_position = finale.ELEVATOR_POS + Vector3(0, 1.2, 0)
	await get_tree().create_timer(10.5).timeout
	assert(player.global_position.y > 9.0, "the ride should end on the roof")
	print("elevator ride: OK")

	# The glide.
	finale.start_glide()
	await get_tree().create_timer(20.0).timeout
	assert(GameState.get_flag("letter_fragment_2"), "fragment 2 should be found")
	assert(GameState.get_flag("island2_complete"), "island 2 should complete")
	assert(Inventory.max_slots == 7, "satchel should grow to 7 pockets")
	print("banner glide + completion: OK")

	# The elevator stays in service: call it from the ground, step in, and
	# ride again.
	finale.elevator_interact()
	await get_tree().create_timer(6.0).timeout
	player.global_position = finale.ELEVATOR_POS + Vector3(0, 1.2, 0)
	await get_tree().create_timer(10.5).timeout
	assert(player.global_position.y > 9.0, "elevator should be reusable after the finale")
	print("elevator reusable: OK")
	print("ALL FINALE TESTS PASSED")
	get_tree().quit()
