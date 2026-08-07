extends Node
## Headless test for all five Winnipeg riddles plus Oreo travel persistence:
## godot --headless --path . res://tools/test_winnipeg_riddles.tscn

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
	for f in ["island1_complete", "island2_complete", "island3_complete",
			"meadow_open", "oreo_untangled", "oreo_fed", "oreo_friend", "oreo_joined"]:
		GameState.set_flag(f)
	main.travel_to("res://scenes/islands/winnipeg.tscn", Vector3(0, 1.2, 42.0), "winnipeg", "The Winnipeg Crescent")
	for i in 10:
		await get_tree().process_frame

	var isl: Node3D = main.get_node("Winnipeg")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	assert(oreo != null, "Oreo should travel with her")
	assert(oreo.get_parent() == main, "Oreo should belong to the manager, not the island")
	assert(oreo.following, "Oreo should be following on arrival")
	print("oreo persistence: OK")

	# --- The Drift Line (the dig duet) ---
	var drift: Node = isl.get_node("DriftLine")
	isl.force_squall(false)
	player.global_position = Vector3(-23.0, 1.0, 3.5)  # by the mitten mound
	GameState.vocal_used.emit("meow")
	await get_tree().create_timer(4.0).timeout
	assert(get_tree().get_nodes_in_group("pickup_frozen_mitten").size() == 1, "Oreo should dig up the mitten")
	print("duet dig: OK")
	# The rest of the wash, by hand for speed.
	for id in ["frozen_mitten", "frozen_scarf", "frozen_sock"]:
		if not Inventory.has_item(id):
			Inventory.add_item(id)
	for pin in ["red", "blue", "yellow"]:
		drift.try_hang(pin)
	assert(GameState.get_flag("drift_line_done"), "the full line should finish the riddle")
	assert(get_tree().get_nodes_in_group("pickup_cocoa_thermos").size() == 1, "cocoa should appear")
	print("drift line: OK")

	# --- The Backyard Rink ---
	var rink: Node = isl.get_node("RinkMaze")
	# Without the bumper: north then east ends on the boards, not the target.
	player.global_position = Vector3(-12.5, 1.0, -0.6)  # south of the puck: push north
	rink.bump_puck(player)
	await get_tree().create_timer(1.4).timeout
	player.global_position = Vector3(-13.2, 1.0, 4.05)  # west of the puck: push east
	rink.bump_puck(player)
	await get_tree().create_timer(1.4).timeout
	assert(not GameState.get_flag("rink_done"), "boards alone must not solve it")
	# Reset via west push, then use Oreo as the bumper.
	player.global_position = Vector3(-6.9, 1.0, 4.05)
	rink.bump_puck(player)  # push west, back to the west boards
	await get_tree().create_timer(1.4).timeout
	oreo.stay_at(Vector3(-6.85, 0.4, 4.05))
	await get_tree().create_timer(2.5).timeout
	player.global_position = Vector3(-13.2, 1.0, 4.05)
	rink.bump_puck(player)  # push east into the dog
	await get_tree().create_timer(1.6).timeout
	assert(GameState.get_flag("rink_done"), "the stay bumper should park the puck on the circle")
	assert(get_tree().get_nodes_in_group("pickup_runner_wax").size() == 1, "wax should surface")
	print("rink maze: OK")

	# --- The Mailbox Morse ---
	var mail: Node = isl.get_node("MailboxMorse")
	isl.force_squall(true)
	for i in 6:
		var want_up: bool = (mail.NUMBERS[i] % 2) == 1
		if mail._flags_up[i] != want_up:
			mail.toggle_flag(i)
	assert(not GameState.get_flag("mailbox_done"), "nothing counts in flying snow")
	isl.force_squall(false)
	for i in 6:
		var want_up: bool = (mail.NUMBERS[i] % 2) == 1
		if mail._flags_up[i] != want_up:
			mail.toggle_flag(i)
	if not GameState.get_flag("mailbox_done"):
		mail._check()
	assert(GameState.get_flag("mailbox_done"), "six right flags in stillness should open the truck")
	assert(get_tree().get_nodes_in_group("pickup_road_salt").size() == 1, "salt should appear")
	print("mailbox morse: OK")

	# --- The Swing Set Launch ---
	var swing: Node = isl.get_node("SwingLaunch")
	assert(get_tree().get_nodes_in_group("pickup_runner_bolts").size() == 1, "bolts wait on the near roof")
	swing.mount(player)
	swing._amp = 3
	swing._launch()
	await get_tree().create_timer(2.2).timeout
	assert(player.global_position.y > 3.0, "a full launch should reach a roof")
	assert(GameState.get_flag("swing_done"), "a roof landing should count")
	assert(GameState.get_flag("seen_run_line"), "the far roof shows the flag-line")
	print("swing launch: OK")

	# --- The Longest Slide ---
	var slide: Node = isl.get_node("LongestSlide")
	slide.ice_interact()
	assert(slide._ice_block != null, "no salt, no melt")
	Inventory.add_item("road_salt")
	slide.ice_interact()
	await get_tree().create_timer(2.5).timeout
	# Dig the toboggan and every gate directly (the duet is proven above).
	for d in get_tree().get_nodes_in_group("diggable"):
		d.dig_open()
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	assert(slide._gates_dug >= 6, "all six gates should be open")
	assert(slide._toboggan != null, "the toboggan should be dug free")
	slide.sled_interact()
	assert(not GameState.get_flag("sled_ready"), "no wax and bolts, no ride")
	Inventory.add_item("runner_wax")
	Inventory.add_item("runner_bolts")
	slide.sled_interact()
	assert(GameState.get_flag("sled_ready"), "wax and bolts should wake the sled")
	slide.sled_interact()
	await get_tree().create_timer(18.0).timeout
	assert(GameState.get_flag("letter_fragment_4"), "fragment 4 should be found")
	assert(GameState.get_flag("island4_complete"), "island 4 should complete")
	assert(Inventory.max_slots == 9, "satchel should grow to 9 pockets")
	assert(oreo.following, "Oreo should follow again after the ride")
	print("longest slide: OK")
	print("ALL WINNIPEG RIDDLE TESTS PASSED")
	get_tree().quit()
