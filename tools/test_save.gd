extends Node
## Headless test for the save system:
## godot --headless --path . res://tools/test_save.tscn
## Round-trips flags, vocals, satchel, and island through a scratch save
## file, and proves tools never autosave.

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

	# debug_fast_start must have disarmed autosave for tools.
	assert(not GameState.autosave_enabled, "tools must not autosave")
	GameState.save_path = "user://test_save_scratch.cfg"
	GameState.clear_save()
	GameState.set_flag("island1_complete")
	assert(not GameState.has_save(), "autosave off means no file")
	print("tool guard: OK")

	# Build a mid-game state and save it deliberately.
	GameState.autosave_enabled = true
	for f in ["island2_complete", "island3_complete", "oreo_joined",
			"letter_read", "letter_fragment_3"]:
		GameState.set_flag(f)
	GameState.learn_vocal("hiss")
	Inventory.add_item("coconut")
	Inventory.add_item("coconut")
	Inventory.add_item("road_salt")
	GameState.record_island("winnipeg")
	assert(GameState.has_save(), "a save file should exist now")
	print("save written: OK")

	# Wipe everything, then load: the world must come back exactly.
	GameState.autosave_enabled = false
	GameState.reset()
	Inventory.reset()
	assert(not GameState.get_flag("oreo_joined"))
	GameState.autosave_enabled = true
	var track := GameState.load_save()
	assert(track == "winnipeg", "saved island should come back")
	assert(GameState.get_flag("island3_complete"), "flags should come back")
	assert(GameState.get_flag("oreo_joined"), "oreo should still be hers")
	assert(GameState.knows_vocal("hiss"), "vocals should come back")
	assert(Inventory.has_item("road_salt"), "satchel contents should come back")
	assert(Inventory.max_slots == 8, "pocket count should rebuild from flags")
	var coconuts := 0
	for s in Inventory.stacks:
		if s.id == "coconut":
			coconuts = s.count
	assert(coconuts == 2, "stacks should keep their counts")
	print("load round-trip: OK")

	# Clear works, and loading nothing reports nothing.
	GameState.clear_save()
	assert(not GameState.has_save(), "clear should remove the file")
	GameState.reset()
	Inventory.reset()
	assert(GameState.load_save() == "", "no save means empty track")
	print("clear + empty load: OK")

	# A drifted save (flags say islands finished, verbs missing — the old
	# pause-travel grant gap) heals itself on load: finished islands imply
	# their verbs were learned.
	GameState.reset()
	Inventory.reset()
	GameState.autosave_enabled = true
	GameState.set_flag("island2_complete")
	GameState.set_flag("horse_moved")
	GameState.known_vocals = ["meow"]
	GameState.save_now()
	# Hand-break the vocals in the file the way real drifted saves look.
	GameState.reset()
	GameState.load_save()
	assert(GameState.knows_vocal("hiss"), "island2_complete must imply hiss on load")
	assert(GameState.knows_vocal("growl"), "horse_moved must imply growl on load")
	GameState.clear_save()
	GameState.autosave_enabled = false
	print("verb-ladder repair: OK")
	print("ALL SAVE TESTS PASSED")
	get_tree().quit()
