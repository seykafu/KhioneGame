extends Node
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
	main.travel_to("res://scenes/islands/winnipeg.tscn", Vector3(0, 1.2, 42.0), "winnipeg", "The Winnipeg Crescent")
	for t in 8:
		await get_tree().create_timer(1.0).timeout
		var found := false
		for c in main.get_children():
			if c is CanvasLayer and c.layer == 12:
				for r in c.get_children():
					if r is ColorRect:
						print("t=", t + 1, " fade alpha=%.2f" % r.color.a)
						found = true
		if not found:
			print("t=", t + 1, " fade gone")
	get_tree().quit()
