extends Node
## Opening cinematic: establishing orbit of Ahalo, narrated premise, dolly to
## Khione, reveal of the message bottle, then hand control to the player
## facing the south beach. Skippable with Space / E / Esc.

const NARRATION_A1 := "Once upon a time, on a small and lonely island called Ahalo, there lived a small white Persian cat named Khione."
const NARRATION_A2 := "She knew no one, and no one knew her. She hunted fish, ate berries, and drank from the river that crossed the island."
const NARRATION_B1 := "She cured her boredom by chasing snails along the beach, and by leaping from branch to branch like a monkey."
const NARRATION_C1 := "But one morning, the tide brought something that had never come before…"
const NARRATION_D1 := "A bottle — with a letter inside."

var cam: Camera3D
var player: CharacterBody3D
var bottle: Node3D
var ui_layer: CanvasLayer
var fade_rect: ColorRect
var subtitle: Label
var skip_hint: Label
var bar_top: ColorRect
var bar_bottom: ColorRect

var _tween: Tween
var _skipped := false
var _finished := false

func _ready() -> void:
	_build_ui()
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	bottle = get_node("../Ahalo/MessageBottle")
	if player == null or bottle == null:
		_finish()
		return
	_run()

func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("jump") \
			or event.is_action_pressed("ui_cancel"):
		_skipped = true

func _run() -> void:
	player.controls_enabled = false
	player.rig.set_process_unhandled_input(false)
	get_node("../HUD").visible = false

	cam = Camera3D.new()
	add_child(cam)
	cam.current = true

	_orbit_step(0.0)
	_fade_screen(0.0, 1.8)

	# Shot A — slow orbit around the island.
	_shot_orbit(9.6)
	_narrate(NARRATION_A1)
	await _wait(4.8)
	_narrate(NARRATION_A2)
	await _wait(4.8)

	# Shot B — down on the beach with Khione, nibbling at nothing in particular.
	if not _skipped:
		var pp: Vector3 = player.global_position
		player._play_anim("Idle_Eating", 0.5)
		_move_cam(pp + Vector3(-4.5, 2.4, 4.5), pp + Vector3(2.2, 0.9, 3.4),
				pp + Vector3(0, 0.45, 0), 7.0)
		_narrate(NARRATION_B1)
		await _wait(7.0)

	# Shot C — the tide's gift: glide down the beach to the bottle.
	if not _skipped:
		var bp: Vector3 = bottle.global_position
		_move_cam(Vector3(0, 7.0, 27.5), bp + Vector3(2.0, 1.0, -2.6),
				bp + Vector3(0, 0.3, 0), 6.5)
		_narrate(NARRATION_C1)
		await _wait(6.5)

	# Shot D — Khione notices: she startles, over-shoulder toward the bottle.
	if not _skipped:
		var pp2: Vector3 = player.global_position
		var bp2: Vector3 = bottle.global_position
		var to_bottle := (bp2 - pp2).normalized()
		player.body_visual.rotation.y = atan2(to_bottle.x, to_bottle.z)
		player._play_anim("Jump_Start", 0.1)
		var eye := pp2 - to_bottle * 2.6 + Vector3(0, 1.5, 0)
		_move_cam(eye, eye + Vector3(0, -0.25, 0), bp2 + Vector3(0, 0.4, 0), 4.2)
		_narrate(NARRATION_D1)
		await _wait(0.8)
		if not _skipped:
			player._play_anim("Idle", 0.3)  # land from the startle instead of freezing
		await _wait(3.4)

	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_kill_tween()
	ui_layer.visible = false
	if is_instance_valid(player):
		var pcam: Camera3D = player.rig.get_node("SpringArm/Camera")
		pcam.current = true
		player.rig.rotation.y = PI  # face the south beach — the bottle is ahead
		player.rig.set_process_unhandled_input(true)
		player.controls_enabled = true
		player._play_anim("Idle")
	if is_instance_valid(cam):
		cam.queue_free()
	var hud := get_node("../HUD")
	hud.visible = true
	hud.flash_message("Reach the bottle on the south beach…", 6.0)
	GameState.set_flag("intro_done")

# --- shots ---

func _shot_orbit(dur: float) -> void:
	if _skipped:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(_orbit_step, 0.0, 1.0, dur)

func _orbit_step(t: float) -> void:
	var ang := deg_to_rad(lerpf(215.0, 318.0, t))
	var r := lerpf(72.0, 56.0, t)
	var h := lerpf(27.0, 17.0, t)
	cam.global_position = Vector3(cos(ang) * r, h, sin(ang) * r)
	cam.look_at(Vector3(0, 3, 0))

func _move_cam(p1: Vector3, p2: Vector3, target: Vector3, dur: float) -> void:
	if _skipped:
		return
	_kill_tween()
	_tween = create_tween()
	var step := func(t: float) -> void:
		cam.global_position = p1.lerp(p2, t)
		cam.look_at(target)
	_tween.tween_method(step, 0.0, 1.0, dur)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

# --- ui ---

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(fade_rect)

	bar_top = _make_bar(Control.PRESET_TOP_WIDE)
	bar_top.offset_bottom = 90.0
	bar_bottom = _make_bar(Control.PRESET_BOTTOM_WIDE)
	bar_bottom.offset_top = -90.0

	subtitle = Label.new()
	subtitle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_top = -190.0
	subtitle.offset_bottom = -104.0
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	subtitle.add_theme_constant_override("outline_size", 10)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(subtitle)

	skip_hint = Label.new()
	skip_hint.text = "Space — skip"
	skip_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_hint.offset_left = -220.0
	skip_hint.offset_top = 30.0
	skip_hint.offset_bottom = 62.0
	skip_hint.offset_right = -24.0
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_hint.modulate = Color(1, 1, 1, 0.45)
	skip_hint.add_theme_font_size_override("font_size", 16)
	skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(skip_hint)

func _make_bar(preset: int) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.set_anchors_preset(preset)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(bar)
	return bar

func _narrate(text: String) -> void:
	if _skipped:
		return
	subtitle.text = text
	subtitle.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(subtitle, "modulate:a", 1.0, 0.45)

func _fade_screen(to: float, dur: float) -> void:
	var t := create_tween()
	t.tween_property(fade_rect, "color:a", to, dur)

func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not _skipped:
		await get_tree().process_frame
		t += get_process_delta_time()
