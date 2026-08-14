extends Node
## Headless end-to-end test of every Island 5 riddle:
## godot --headless --path . res://tools/test_pirate_riddles.tscn
## Growl learning, the bore ride, the Cannonball Nine (wrong volley then
## true), the whistle summon, the sea cave key, and the full finale:
## flood, storm gate, boarding, capstan duet, and the sailed exit.

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
	for f: String in ["island1_complete", "island2_complete", "island3_complete",
			"island4_complete", "oreo_joined"]:
		GameState.set_flag(f)
	main.travel_to("res://scenes/islands/pirate.tscn", Vector3(0, 1.2, 42.0), "pirate", "The Pirate Ship")
	for i in 10:
		await get_tree().process_frame
	var isl: Node3D = main.get_node("Pirate")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	assert(oreo != null, "oreo must make the crossing")

	# --- growl learning ---
	assert(not GameState.knows_vocal("growl"), "growl must start unknown")
	isl.get_node("ParrotGame").force_respect()
	assert(GameState.knows_vocal("growl"), "the parrot lesson must teach growl")
	print("growl learned: OK")

	# --- the wave clock: tide phases and the bore ride ---
	isl.force_tide(2.0)
	assert(not isl.is_bore(), "no bore mid-swell")
	isl.force_tide(14.0)
	assert(isl.is_bore(), "the last quarter is the bore")
	var wave_clock: Node = isl.get_node("WaveClock")
	wave_clock.force_ride()
	await get_tree().create_timer(2.8).timeout
	assert(GameState.get_flag("rode_the_bore"), "riding the bore must register")
	assert(player.global_position.distance_to(Vector3(-3.5, 3.8, 30.6)) < 2.5,
			"the bore beaches her on the net loft (got %s)" % player.global_position)
	print("bore ride to loft: OK")

	# --- the cannonball nine ---
	Inventory.add_item("golf_balls")
	var nine: Node = isl.get_node("CannonballNine")
	nine.putt(0)
	nine.putt(4)   # teal: a wrong gun in the battery
	nine.fire()
	assert(not GameState.get_flag("broadside_done"), "confetti is not a broadside")
	for i: int in isl.ROGER_HOLES:
		nine.putt(i)
	nine.fire()
	assert(GameState.get_flag("broadside_done"), "the true four must crack the rust")
	print("cannonball nine: OK")

	# --- the captain's whistle summon ---
	Inventory.add_item("captains_whistle")
	player.global_position = Vector3(-30.0, 1.6, -10.0)
	oreo.global_position = Vector3(30.0, 0.5, 40.0)
	GameState.vocal_used.emit("meow")
	await get_tree().process_frame
	assert(player.global_position.distance_to(oreo.global_position) < 5.0,
			"the whistle must fetch Oreo from across the island")
	print("whistle summon: OK")

	# --- the sea cave key ---
	var cave: Node = isl.get_node("SeaCaveKey")
	cave.try_grate()
	assert(not Inventory.has_item("spigot_wheel"), "the grate keeps its secret until the fish leads")
	cave.force_led()
	cave.try_grate()
	assert(Inventory.has_item("spigot_wheel"), "the led grate must yield the wheel")
	print("sea cave key: OK")

	# --- the finale: flood, storm gate, boarding, capstan, helm ---
	var finale: Node = isl.get_node("FloatSantaMaria")
	finale.try_spigot()
	await get_tree().create_timer(5.6).timeout
	assert(GameState.get_flag("ship_afloat"), "the flood must float her")
	assert(absf((isl.ship as Node3D).rotation.z) < 0.02, "she must roll upright")
	player.global_position = Vector3(-12.0, 1.0, 33.0)
	GameState.vocal_used.emit("growl")
	await get_tree().process_frame
	assert(GameState.get_flag("storm_gate_open"), "a growl by the boathouse opens the gate")
	assert(isl.is_storm(), "the island must run its storm tide")
	player.global_position = Vector3(12.0, 0.0, 28.0)
	wave_clock.force_ride()
	await get_tree().create_timer(2.8).timeout
	assert(GameState.get_flag("boarded_ship"), "the storm bore must land her on deck")
	finale.try_capstan()
	await get_tree().create_timer(6.5).timeout
	assert(GameState.get_flag("anchor_up"), "the duet must raise the anchor")
	finale.try_helm()
	await get_tree().create_timer(20.0).timeout
	assert(GameState.get_flag("letter_fragment_5"), "fragment 5 must be found")
	assert(GameState.get_flag("island5_complete"), "island 5 must complete")
	assert(bool(player.get("controls_enabled")), "controls must return after the sail")
	assert(player.global_position.distance_to(Vector3(0, 0.7, 40.0)) < 4.0,
			"she watches from the wharf after")
	assert(bool(oreo.get("following")), "oreo follows again after the sail")
	print("float the santa maria: OK")
	print("ALL PIRATE RIDDLE TESTS PASSED")
	get_tree().quit()
