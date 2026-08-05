extends Node
## Every Sfx.play(...) name used anywhere in the scripts must resolve to a
## real audio file — no more silent bells.

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	# Names collected from all Sfx.play call sites.
	var used := ["paw_sand", "paw_grass", "splash", "swim_stroke", "jump_whoosh",
		"land", "pickup_chime", "paper_open", "paper_close", "stone_slide", "gull",
		"coconut_thunk", "wood_creak", "gate_open", "whisker_shimmer", "crab_snip",
		"hiss", "robot_whir", "robot_flee", "bell_ding", "howl", "bark", "whimper",
		"drain", "fail"]
	for name in used:
		var path: String = Sfx.SOUNDS.get(name, "res://assets/audio/%s.wav" % name)
		assert(ResourceLoader.exists(path), "missing sound: " + name)
		Sfx.play(name, 1.0, 0.0, -60.0)
	var any_playing := false
	for p in Sfx._pool:
		if p.stream != null:
			any_playing = true
	assert(any_playing, "the pool should have taken streams")
	print("ALL SFX NAMES RESOLVE: OK")
	get_tree().quit()
