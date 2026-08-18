extends Node
## Headless end-to-end test of every Island 5 riddle:
## godot --headless --path . res://tools/test_montreal_riddles.tscn
## Growl from the horse, the bagel oven and the toll, the Three Stars
## (wrong hoist buzzes, right order opens the box), the tam-tams and the
## lever handle, the linked staircase levers, and the finale: panes,
## twelve bagels, the summit duet, the lit cross, and the funicular ride.

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
	main.travel_to("res://scenes/islands/montreal.tscn", Vector3(0, 1.2, 42.0), "montreal", "Montréal")
	for i in 10:
		await get_tree().process_frame
	var isl: Node3D = main.get_node("Montreal")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	assert(oreo != null, "oreo must make the crossing")

	# --- the horse: growl learned, road opened ---
	assert(not GameState.knows_vocal("growl"), "growl must start unknown")
	var horse: Node = isl.get_node("CalecheHorse")
	player.global_position = isl.HORSE_POS + Vector3(0, 0.6, 4.0)
	GameState.vocal_used.emit("meow")
	GameState.vocal_used.emit("hiss")
	await get_tree().create_timer(2.0).timeout   # Oreo's demonstration
	player.vocal_unknown.emit("growl")
	await get_tree().create_timer(1.6).timeout
	assert(GameState.knows_vocal("growl"), "her first bark must come out a growl")
	assert(GameState.get_flag("horse_moved"), "the growl must move the horse")
	print("growl from the horse: OK")

	# --- the bagel standard + the toll ---
	var oven: Node = isl.get_node("BagelStandard")
	oven.oven_interact()                       # a bagel goes on
	await get_tree().create_timer(1.4).timeout # golden window
	oven.oven_interact()
	assert(Inventory.count_of("bagel") == 1, "a golden pull yields one bagel")
	oven.oven_interact()
	await get_tree().create_timer(0.3).timeout # too soon: dough
	oven.oven_interact()
	assert(Inventory.count_of("bagel") == 1, "an early pull is smoke, not bagel")
	var stairs: Node = isl.get_node("StaircaseShuffle")
	stairs.pay_toll()
	assert(GameState.get_flag("toll_paid") and Inventory.count_of("bagel") == 0, "the toll takes exactly one")
	print("bagel standard + toll: OK")

	# --- the three stars ---
	var stars: Node = isl.get_node("ThreeStars")
	var arena: Node3D = isl.arena
	player.global_position = arena.to_global(Vector3(0, 0.6, 1.0))
	GameState.vocal_used.emit("hiss")
	await get_tree().create_timer(0.3).timeout
	GameState.vocal_used.emit("growl")
	await get_tree().create_timer(0.3).timeout
	stars.hoist(9)
	stars.hoist(33)                            # wrong: buzzer, all drop
	await get_tree().create_timer(2.5).timeout
	assert(not GameState.get_flag("three_stars_done"), "a wrong star must not open the box")
	stars.hoist(9)
	stars.hoist(4)
	stars.hoist(10)
	await get_tree().create_timer(2.5).timeout
	assert(GameState.get_flag("three_stars_done"), "the three stars in order open the box")
	for i in 3:
		Inventory.add_item("arena_pane")
	print("three stars: OK")

	# --- the tam-tams: pattern with the echo gaps ---
	var tam: Node = isl.get_node("TamTamCircle")
	tam.strike("low")
	await get_tree().create_timer(0.2).timeout
	tam.strike("high")                         # too soon: swallowed by the echo
	assert(not GameState.get_flag("tamtam_done"), "hits inside the echo do not count")
	for kind: String in ["low", "high", "low", "mid"]:
		tam.strike(kind)
		await get_tree().create_timer(1.0).timeout
	assert(GameState.get_flag("tamtam_done"), "the pattern between echoes wins the circle")
	Inventory.add_item("lever_handle")
	print("tam-tam circle: OK")

	# --- the staircase: linked levers, solved from the bottom up ---
	stairs.pull(1)                             # seats the handle
	assert(GameState.get_flag("lever2_handled"), "the handle must seat first")
	for n in 3:
		stairs.pull(1)
		await get_tree().create_timer(1.6).timeout
	assert(stairs.flight_aligned(1), "three pulls of lever 2 align flight 2")
	stairs.pull(2)
	await get_tree().create_timer(1.6).timeout
	assert(stairs.flight_aligned(2), "flight 3 realigns")
	for n in 2:
		stairs.pull(3)
		await get_tree().create_timer(1.6).timeout
	assert(GameState.get_flag("stairs_fixed"), "all four flights true: fixed")
	print("staircase shuffle: OK")

	# --- the finale ---
	var finale: Node = isl.get_node("LightTheCross")
	finale.cross_interact()
	assert(GameState.get_flag("panes_fitted"), "three panes fit the three dark lanterns")
	finale.cross_interact()
	assert(not GameState.get_flag("bagels_placed"), "no bagels, no warmth")
	oven.force_bake(11)
	finale.cross_interact()
	assert(not GameState.get_flag("bagels_placed"), "eleven is not a dozen: à la douzaine")
	oven.force_bake(1)
	finale.cross_interact()
	assert(GameState.get_flag("bagels_placed"), "twelve bagels warm the twelve bases")
	assert(isl.is_dusk(), "the bagels bring the dusk")
	await get_tree().create_timer(3.5).timeout  # the swarm arrives
	for kind: String in ["low", "high", "low", "mid"]:
		finale.drum_hit(kind)
		await get_tree().create_timer(1.0).timeout
	assert(GameState.get_flag("cross_lit"), "the duet settles the swarm")
	await get_tree().create_timer(8.0).timeout   # tier by tier
	finale.board()
	await get_tree().create_timer(20.5).timeout
	assert(GameState.get_flag("letter_fragment_5"), "fragment 5 must be found")
	assert(GameState.get_flag("island5_complete"), "island 5 must complete")
	assert(bool(player.get("controls_enabled")), "controls return after the ride")
	assert(player.global_position.distance_to(isl.FUNICULAR_BOTTOM) < 6.0,
			"she steps off at the lower station (got %s)" % player.global_position)
	assert(bool(oreo.get("following")), "oreo follows again after the ride")
	print("light the cross: OK")
	print("ALL MONTREAL RIDDLE TESTS PASSED")
	get_tree().quit()
