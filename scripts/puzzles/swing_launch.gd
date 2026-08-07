extends Node3D
## Island 4, Riddle 4 — The Swing Set Launch.
## Hop on, pump in rhythm (Space at the right beat), and launch with E.
## One good pump flops you on the lawn; two reach the near roof (runner
## bolts); three reach the far roof, where an old loonie glints and the
## whole buried toboggan run reveals its line of little flags. Launching
## into a squall carries a whole tier farther.

const SEAT := Vector3(12.2, 1.15, 4.0)
const TIER_TARGETS := [
	Vector3(16.0, 0.55, 9.0),      # the lawn, with dignity intact
	Vector3(21.2, 4.55, -3.7),     # near roof: runner bolts
	Vector3(13.9, 4.55, -16.4),    # far roof: the loonie, and the view
]

var _riding := false
var _amp := 0
var _last_pump := -10.0
var _materials := {}

class SwingPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Hop on the swing"

	func interact(player: Node) -> void:
		owner_puzzle.mount(player)

func _ready() -> void:
	var plate := SwingPlate.new()
	plate.owner_puzzle = self
	plate.position = SEAT
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)
	# The rooftop finds wait from the start; the swing is just the ladder.
	var island := get_parent()
	if island.has_method("_add_pickup"):
		island._add_pickup(TIER_TARGETS[1] + Vector3(0, -0.1, 0.5), "runner_bolts",
				"Runner Bolts", Color(0.6, 0.62, 0.68))
		island._add_pickup(TIER_TARGETS[2] + Vector3(0, -0.1, 0.5), "old_loonie",
				"Old Loonie", Color(0.85, 0.72, 0.3))

func mount(player: Node) -> void:
	if _riding:
		return
	_riding = true
	_amp = 0
	var p := player as Node3D
	p.set("controls_enabled", false)
	p.set_physics_process(false)
	p.global_position = SEAT
	set_process_unhandled_input(true)
	_flash("She settles on the swing. Space pumps, in rhythm… E lets go.", 4.5)

func _unhandled_input(event: InputEvent) -> void:
	if not _riding:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		_pump()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_launch()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_dismount()
		get_viewport().set_input_as_handled()

func _pump() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var gap := now - _last_pump
	_last_pump = now
	if gap > 0.35 and gap < 1.2:
		_amp = mini(_amp + 1, 3)
	else:
		_amp = 1
	Sfx.play("jump_whoosh", 0.8 + 0.15 * _amp, 0.05, -14.0)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		var kick := create_tween()
		kick.tween_property(player, "global_position:y", SEAT.y + 0.12 * _amp, 0.25) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		kick.tween_property(player, "global_position:y", SEAT.y, 0.3) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _amp == 3:
		_flash("The swing sings at the top of its arc. E, whenever she dares.", 3.0)

func _dismount() -> void:
	_riding = false
	set_process_unhandled_input(false)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(true)
		player.set("controls_enabled", true)

func _launch() -> void:
	if _amp < 1:
		_flash("No height yet. Pump first, with the rhythm.", 2.5)
		return
	var tier := _amp
	var island := get_parent()
	if island.has_method("is_squalling") and island.is_squalling() and tier < 3:
		tier += 1
		_flash("The squall catches her mid-air and CARRIES her.", 3.0)
	var target: Vector3 = TIER_TARGETS[tier - 1]
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		_dismount()
		return
	_riding = false
	set_process_unhandled_input(false)
	Sfx.play("jump_whoosh", 1.3, 0.05, -8.0)
	var from := player.global_position
	var peak := maxf(from.y, target.y) + 2.6
	var arc := create_tween()
	var step := func(t: float) -> void:
		var pos := from.lerp(target, t)
		pos.y = lerpf(from.y, target.y, t) + sin(t * PI) * (peak - maxf(from.y, target.y))
		player.global_position = pos
	arc.tween_method(step, 0.0, 1.0, 1.5).set_trans(Tween.TRANS_LINEAR)
	arc.tween_callback(func() -> void:
		player.set_physics_process(true)
		player.set("controls_enabled", true)
		Sfx.play("land", 1.0, 0.05, -10.0)
		if tier >= 2:
			GameState.set_flag("swing_done")
		if tier >= 3 and not GameState.get_flag("seen_run_line"):
			GameState.set_flag("seen_run_line")
			_flash("From up here she sees it: a line of little red flags, poking from the drifts, running from the ridge all the way down to the shore.", 6.0))

# --- helpers ---

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)
