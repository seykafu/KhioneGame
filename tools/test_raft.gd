extends Node
## Headless test for Beats 4+5:
## godot --headless --path . res://tools/test_raft.tscn
## Verifies: frond knocks loose on touch, crab refuses empty paws then trades
## fish for rope, rigging consumes all three parts, and Set sail starts the
## departure sequence.

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

	var sundial: Node = main.get_node("Ahalo/SundialReef")
	var frond: Node3D = main.get_node("Ahalo/FrondPalm")
	var crab: Node = main.get_node("Ahalo/CrabVines")
	var rigging: Node = main.get_node("Ahalo/RaftDeparture")
	var player: Node3D = get_tree().get_first_node_in_group("player")

	# Beach the raft (Beat 3 shortcut).
	sundial._release_raft()
	await get_tree().create_timer(10.5).timeout
	assert(GameState.get_flag("raft_frame_beached"), "raft should beach")
	print("raft beached: OK")

	# Frond: jump-touch knocks it loose, then pick it up.
	player.global_position = frond.global_position + Vector3(0.3, 3.5, 0.3)
	player.set("velocity", Vector3.ZERO)
	for i in 6:
		await get_tree().physics_frame
	assert(frond._knocked, "frond should knock loose on touch")
	await get_tree().create_timer(1.5).timeout
	var frond_pickup := _find_pickup(frond, "palm_frond")
	assert(frond_pickup != null, "frond pickup should spawn")
	frond_pickup.interact(player)
	assert(Inventory.has_item("palm_frond"))
	print("dry frond: OK")

	# Crab: empty paws refused, fish trades for rope.
	crab.crab_interact()
	assert(not GameState.get_flag("vines_snipped"), "no trade without fish")
	Inventory.add_item("stranded_fish")
	crab.crab_interact()
	assert(GameState.get_flag("vines_snipped"), "fish should trade")
	assert(not Inventory.has_item("stranded_fish"), "fish consumed")
	await get_tree().create_timer(1.2).timeout
	var rope := _find_pickup(crab, "vine_rope")
	assert(rope != null, "rope pickup should spawn")
	rope.interact(player)
	assert(Inventory.has_item("vine_rope"))
	print("crab trade: OK")

	# Rigging: all three parts install and are consumed.
	Inventory.add_item("old_oar")
	var raft: Node3D = sundial.get_node("RaftFrame")
	rigging.raft_interact(raft)
	assert(rigging._complete(), "all parts should be installed")
	for id: String in ["old_oar", "palm_frond", "vine_rope"]:
		assert(not Inventory.has_item(id), "%s should be consumed" % id)
	print("rigging: OK")

	# Second interact: set sail.
	rigging.raft_interact(raft)
	await get_tree().process_frame
	assert(GameState.get_flag("set_sail_started"), "departure should start")
	print("set sail: OK")
	print("ALL RAFT TESTS PASSED")
	get_tree().quit()

func _find_pickup(root: Node, id: String) -> Area3D:
	for c in root.get_children():
		if c is Area3D and c.get("item_id") == id:
			return c
	return null
