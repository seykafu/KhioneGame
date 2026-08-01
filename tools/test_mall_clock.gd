extends Node
## Headless test for the Wrong-Way Stairs (Island 2, riddle 1):
## godot --headless --path . res://tools/test_mall_clock.tscn
## Verifies: clock starts stuck, wrong hours do nothing, 3 o'clock blooms
## the kiosk / flips the escalators / sets the flag, and the flag is sticky.

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
	main.travel_to("res://scenes/islands/eaton.tscn", Vector3(0, 1.2, 40.0), "eaton", "The Eaton Centre")
	for i in 10:
		await get_tree().process_frame

	var clock: Node = main.get_node("Eaton/MallClock")
	assert(clock != null, "mall clock missing")
	assert(clock.clock_hour == 7, "clock should start stuck at 7")
	assert(not clock._escalators_up, "escalators should start running against the player")

	# Advance to 8: nothing should happen.
	clock.advance_clock()
	assert(clock.clock_hour == 8)
	assert(not GameState.get_flag("mall_time_3"), "8 o'clock is not the answer")

	# Advance around the dial to 3.
	while clock.clock_hour != 3:
		clock.advance_clock()
	assert(GameState.get_flag("mall_time_3"), "3 o'clock should convince the mall")
	assert(clock._escalators_up, "escalators should run kindly at 3")
	assert(clock._bloomed, "the kiosk should bloom")
	print("clock riddle solves at 3: OK")

	# Ownership is sticky: moving the hands afterwards keeps the win.
	clock.advance_clock()
	assert(clock.clock_hour == 4)
	assert(GameState.get_flag("mall_time_3"), "the win should not un-happen")
	assert(clock._escalators_up, "stairs stay kind")
	print("clock ownership sticky: OK")

	print("ALL MALL CLOCK TESTS PASSED")
	get_tree().quit()
