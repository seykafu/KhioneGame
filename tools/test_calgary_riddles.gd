extends Node
## Headless test for all five Prince's Island riddles:
## godot --headless --path . res://tools/test_calgary_riddles.tscn
## Drives the breeze directly, runs each riddle's fail and success paths,
## and finishes with Oreo joining and the canoe departure.

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
	GameState.set_flag("island1_complete")
	GameState.set_flag("island2_complete")
	main.travel_to("res://scenes/islands/calgary.tscn", Vector3(0, 1.2, 42.0), "calgary", "Prince's Island")
	for i in 10:
		await get_tree().process_frame

	var isl: Node3D = main.get_node("Calgary")
	var breeze: Node = isl.get_node("BowBreeze")
	var regatta: Node = isl.get_node("PaperRegatta")
	var cart: Node = isl.get_node("IceCreamRound")
	var gophers: Node = isl.get_node("GopherSemaphore")
	var kite: Node = isl.get_node("BridgeKite")
	var howl: Node = isl.get_node("OffleashHowl")
	var player: Node3D = get_tree().get_first_node_in_group("player")

	# --- Paper Regatta ---
	breeze.force_phase(0)  # CALM
	regatta.launch_boat()
	await get_tree().create_timer(0.2).timeout
	assert(not GameState.get_flag("regatta_done"), "becalmed boat must not win")
	breeze.force_phase(2)  # GUST
	regatta.launch_boat()  # sluice closed: jams
	await get_tree().create_timer(5.5).timeout
	assert(not GameState.get_flag("regatta_done"), "closed weir must jam the boat")
	regatta.toggle_sluice()
	regatta.launch_boat()
	await get_tree().create_timer(8.0).timeout
	assert(GameState.get_flag("regatta_done"), "gust + open weir should win the regatta")
	assert(get_tree().get_nodes_in_group("pickup_brass_clapper").size() == 1, "clapper should wash loose")
	print("paper regatta: OK")

	# --- Ice Cream Round ---
	cart.bell_interact()
	assert(not GameState.get_flag("bell_fixed"), "no clapper, no voice")
	Inventory.add_item("brass_clapper")
	cart.bell_interact()
	assert(GameState.get_flag("bell_fixed"), "clapper should seat")
	for i in 3:  # wrong round: 3 rings
		cart.bell_interact()
	await get_tree().create_timer(6.5).timeout
	assert(not GameState.get_flag("ice_cream_done"), "three rings is not the round")
	for i in 4:  # the vendor's round
		cart.bell_interact()
	await get_tree().create_timer(6.5).timeout
	assert(GameState.get_flag("ice_cream_done"), "four rings should open the hatch")
	assert(get_tree().get_nodes_in_group("pickup_dog_biscuits").size() == 1, "biscuits should appear")
	assert(get_tree().get_nodes_in_group("pickup_paw_key").size() == 1, "paw key should appear")
	print("ice cream round: OK")

	# --- Bridge and the Kite ---
	breeze.force_phase(2)  # GUST: it thrashes away
	kite.grab_kite()
	assert(not GameState.get_flag("kite_freed"), "gust must foil the grab")
	breeze.force_phase(0)  # CALM
	kite.grab_kite()
	assert(GameState.get_flag("kite_freed"), "the lull should free the kite")
	await get_tree().create_timer(1.5).timeout
	assert(get_tree().get_nodes_in_group("pickup_cream_jug").size() == 1, "cream jug should surface")
	print("bridge and kite: OK")

	# --- Gopher Semaphore ---
	var order: Array = gophers._order
	var mounds: Array = gophers._mounds
	# A wrong pulse first (second mound in the order, out of turn).
	player.global_position = mounds[order[1]] + Vector3(0, 0.8, 0)
	GameState.vocal_used.emit("meow")
	await get_tree().process_frame
	assert(not GameState.get_flag("gopher_semaphore_done"))
	for idx in order:
		player.global_position = mounds[idx] + Vector3(0, 0.8, 0)
		GameState.vocal_used.emit("meow")
		await get_tree().create_timer(0.1).timeout
	assert(GameState.get_flag("gopher_semaphore_done"), "the full order should win the town over")
	assert(get_tree().get_nodes_in_group("pickup_tennis_ball").size() == 1, "the eldest should surface the ball")
	print("gopher semaphore: OK")

	# --- The Howl ---
	howl.gate_interact()
	assert(not GameState.get_flag("meadow_open"), "no key, no meadow")
	Inventory.add_item("paw_key")
	howl.gate_interact()
	assert(GameState.get_flag("meadow_open"), "paw key should open the gate")
	# A wrong pad resets; then the reverse walk unwinds the line.
	var pads := {"stone": howl.STONE + Vector3(0, 0.02, 0.9),
			"bench": howl.BENCH + Vector3(0.9, 0.02, 0.6), "tree": howl.TREE + Vector3(-0.9, 0.02, 0.7)}
	player.global_position = pads["bench"] + Vector3(0, 0.6, 0)
	await get_tree().create_timer(0.4).timeout
	assert(not GameState.get_flag("oreo_untangled"))
	for pad_name: String in ["stone", "bench", "tree"]:
		player.global_position = pads[pad_name] + Vector3(0, 0.6, 0)
		await get_tree().create_timer(0.4).timeout
	assert(GameState.get_flag("oreo_untangled"), "the reverse walk should free him")
	print("run-line untangled: OK")

	# Feeding, and the throw.
	howl.oreo_interact(player)
	assert(not GameState.get_flag("oreo_fed"), "no food, no friendship yet")
	Inventory.add_item("cream_jug")
	Inventory.add_item("dog_biscuits")
	howl.oreo_interact(player)
	assert(GameState.get_flag("oreo_fed"), "cream and biscuits should be shared")
	Inventory.add_item("tennis_ball")
	howl.oreo_interact(player)
	await get_tree().create_timer(6.0).timeout
	assert(GameState.get_flag("oreo_joined"), "the throw should seal it")
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	assert(oreo != null and oreo.following, "Oreo should follow")
	# He follows: teleport away and wait.
	player.global_position = Vector3(10, 1.0, 10)
	await get_tree().create_timer(4.0).timeout
	assert(oreo.global_position.distance_to(player.global_position) < 8.0, "Oreo should catch up")
	print("oreo joins + follows: OK")

	# He swims: follow her offshore and he settles INTO the water, dog
	# paddling — never hovering above it at y=0 (the old clamp bug).
	player.global_position = Vector3(10, -0.1, 60)
	await get_tree().create_timer(5.0).timeout
	assert(oreo.global_position.y < -0.05 and oreo.global_position.y > -0.45,
			"Oreo should swim at the waterline, not float above it (y=%.2f)" % oreo.global_position.y)
	print("oreo swims: OK")
	player.global_position = Vector3(2, 1.0, 38)
	await get_tree().create_timer(3.0).timeout

	# The shove-off: they board, the fragment slips loose, and then the two
	# of them actually sail east and land on the Winnipeg dock.
	howl.canoe_interact()
	await get_tree().create_timer(8.0).timeout
	assert(GameState.get_flag("letter_fragment_3"), "fragment 3 should slip loose")
	assert(GameState.get_flag("island3_complete"), "island 3 should complete")
	assert(Inventory.max_slots == 8, "satchel should grow to 8 pockets")
	print("canoe departure: OK")
	await get_tree().create_timer(9.0).timeout
	assert(main.current_island != null and main.current_island.name == "Winnipeg",
			"the sail should land them on island 4")
	var oreo_after: Node3D = get_tree().get_first_node_in_group("oreo")
	assert(oreo_after != null and oreo_after.following, "Oreo should arrive following")
	assert(player.global_position.distance_to(Vector3(0, 1.2, 42.0)) < 4.0,
			"the player should stand on the Winnipeg dock")
	print("sail to Winnipeg: OK")
	print("ALL CALGARY RIDDLE TESTS PASSED")
	get_tree().quit()
