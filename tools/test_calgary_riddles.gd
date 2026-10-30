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

	# --- the opened gate's opening stays open ---
	# The paw key swung the gate aside earlier; nothing solid may sit in
	# the frame she and Oreo walk through.
	var space := player.get_world_3d().direct_space_state
	var gate_probe := PhysicsShapeQueryParameters3D.new()
	var gate_sph := SphereShape3D.new()
	gate_sph.radius = 0.3
	gate_probe.shape = gate_sph
	var gate_excludes: Array[RID] = []
	if player is CollisionObject3D:
		gate_excludes.append((player as CollisionObject3D).get_rid())
	if oreo is CollisionObject3D:
		gate_excludes.append((oreo as CollisionObject3D).get_rid())
	gate_probe.exclude = gate_excludes
	# Heights clear of the lawn itself (terrain sits at 0.35 here) but
	# square in the frame a walking cat and a bounding dog pass through.
	for gy: float in [0.8, 1.5]:
		gate_probe.transform = Transform3D(Basis(), Vector3(0.0, gy, -23.0))
		assert(space.intersect_shape(gate_probe).is_empty(),
				"the opened meadow gate must leave its frame clear (y=%s)" % gy)
	print("opened gate clearance: OK")

	# --- cinematic corridor: the paddle-out is prop-free ---
	# _set_sail/_paddle_out tween PLAYER + OREO (and the camera) along
	# this route over the Bow, so any solid body inside the corridor would
	# be visibly clipped through. Exempt: terrain (the only concave
	# collider, identified by its ConcavePolygonShape3D) and the canoe
	# itself, whose hull collider rides the route with them. The same
	# route serves the first sail and every revisit ferry to Winnipeg.
	var offenders: Array[String] = []
	var corr := PhysicsShapeQueryParameters3D.new()
	var csph := SphereShape3D.new()
	csph.radius = 0.3
	corr.shape = csph
	corr.exclude = gate_excludes
	var canoe_node: Node3D = isl.get_node_or_null("Canoe")
	assert(canoe_node != null, "the beached canoe should exist")
	var is_exempt := func(collider: Object) -> bool:
		for c in (collider as Node).get_children():
			if c is CollisionShape3D and c.shape is ConcavePolygonShape3D:
				return true  # terrain heightfield
		var walker: Node = collider as Node
		while walker != null:
			if walker == canoe_node:
				return true  # the canoe sails the corridor itself
			walker = walker.get_parent()
		return false
	var sweep := func(pos: Vector3, label: String) -> void:
		corr.transform = Transform3D(Basis(), pos)
		for hit in space.intersect_shape(corr):
			var col: Object = hit.collider
			if not is_exempt.call(col):
				offenders.append("%s: %s at %s" % [label, (col as Node).name, pos])
	# The paddle route from offleash_howl._paddle_out: the shove-off point
	# (2.8, WATER_LINE + 0.12, 42.0), then three waypoints east.
	var route: Array[Vector3] = [
		Vector3(2.8, -0.28, 42.0), Vector3(3.5, -0.28, 52.0),
		Vector3(6.0, -0.28, 64.0), Vector3(11.0, -0.28, 78.0),
	]
	for i in route.size() - 1:
		for k in 13:
			var t: float = k / 12.0
			var p: Vector3 = route[i].lerp(route[i + 1], t)
			sweep.call(p + Vector3(0, 0.2, 0), "canoe deck")
			sweep.call(p + Vector3(0, 0.75, 0), "rider height")
	for o in offenders:
		print("CORRIDOR OFFENDER — ", o)
	assert(offenders.is_empty(), "the paddle-out corridor must be free of props")
	print("cinematic corridor: OK")

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
