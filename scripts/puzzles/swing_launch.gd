extends Node3D
## Island 4, Riddle 4 — The Swing Set Launch.
## Hop on, pump in rhythm (Space at the right beat), and launch with E.
## The swing is a real pendulum rig: Khione visibly arcs higher with
## every good pump, ghost-flakes trace exactly where she will fly, and
## the launch is flown nose-first with a sparkle trail. One good pump
## flops her on the lawn; two reach the near roof (runner bolts); three
## the far roof (the loonie). A squall carries her a whole tier farther.

const SEAT := Vector3(12.2, 1.15, 4.0)
const PIVOT := Vector3(12.2, 2.8, 4.0)   # the crossbar the swing hangs from
const ROPE := 1.65
const TIER_TARGETS := [
	# All targets sit NORTH of the swing so every launch flies forward,
	# the way a swing actually throws you. The lawn spot is open snow
	# (tools/test_winnipeg.gd probes it, and sweeps all three arcs).
	Vector3(15.5, 0.55, -1.5),     # the lawn, with dignity intact
	Vector3(21.2, 4.55, -3.7),     # near roof: runner bolts
	Vector3(13.9, 4.55, -16.4),    # far roof: the loonie, and the view
]

var _riding := false
var _amp := 0
var _last_pump := -10.0
var _phase := 0.0
var _cur_amp := 0.0
var _idle_t := 0.0
var _rig: Node3D
var _preview: Array[Node3D] = []
var _preview_tier := 0

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
	_build_rig()
	# The rooftop finds wait from the start; the swing is just the ladder.
	var island := get_parent()
	if island.has_method("_add_pickup"):
		island._add_pickup(TIER_TARGETS[1] + Vector3(0, -0.1, 0.5), "runner_bolts",
				"Runner Bolts", Color(0.6, 0.62, 0.68))
		island._add_pickup(TIER_TARGETS[2] + Vector3(0, -0.1, 0.5), "old_loonie",
				"Old Loonie", Color(0.85, 0.72, 0.3))

## Khione's swing hangs from a pivot at the crossbar so chains, seat and
## rider all really swing. (The island builds only the right, static one.)
func _build_rig() -> void:
	_rig = Node3D.new()
	_rig.position = PIVOT
	add_child(_rig)
	for cz in [-0.18, 0.18]:
		var chain := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(0.03, 1.6, 0.03)
		chain.mesh = cb
		chain.material_override = _mat(Color(0.35, 0.35, 0.38))
		chain.position = Vector3(0, -0.8, cz)
		_rig.add_child(chain)
	var seat := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.5, 0.06, 0.24)
	seat.mesh = sb
	seat.material_override = _mat(Color(0.2, 0.2, 0.24))
	seat.position = Vector3(0, -ROPE, 0)
	_rig.add_child(seat)

func _process(delta: float) -> void:
	if not _riding:
		# Empty swings sway a little in the prairie air.
		_idle_t += delta
		if _rig:
			_rig.rotation.x = 0.05 * sin(_idle_t * 1.2)
		return
	_phase += delta * 3.0
	var target_amp := 0.05 + 0.3 * _amp
	_cur_amp = lerpf(_cur_amp, target_amp, minf(2.5 * delta, 1.0))
	var a := _cur_amp * sin(_phase)
	_rig.rotation.x = a
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = PIVOT + Vector3(0, -cos(a), -sin(a)) * ROPE \
				+ Vector3(0, 0.35, 0)
		player.rotation.y = PI  # facing the crescent, where every launch goes
		player.rotation.x = -a * 0.7
	# The squall can change where a launch lands; keep the preview honest.
	if _amp >= 1 and _launch_tier() != _preview_tier:
		_update_preview()

func mount(player: Node) -> void:
	if _riding:
		return
	_riding = true
	_amp = 0
	_phase = 0.0
	_cur_amp = 0.05
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
	_update_preview()
	if _amp == 3:
		_flash("The swing sings at the top of its arc. E, whenever she dares.", 3.0)

## Which tier a launch right now would reach (squall carries one extra).
func _launch_tier() -> int:
	var tier := _amp
	var island := get_parent()
	if island.has_method("is_squalling") and island.is_squalling() and tier < 3:
		tier += 1
	return tier

# --- the aim preview: ghost flakes along the exact flight arc ---

func _clear_preview() -> void:
	for d in _preview:
		if is_instance_valid(d):
			d.queue_free()
	_preview.clear()
	_preview_tier = 0

func _update_preview() -> void:
	_clear_preview()
	if _amp < 1:
		return
	var tier := _launch_tier()
	_preview_tier = tier
	var target: Vector3 = TIER_TARGETS[tier - 1]
	var from := SEAT + Vector3(0, 0.35, 0)
	var peak := maxf(from.y, target.y) + 2.6
	# Rooftop arcs glow gold; the lawn flop stays snow-white.
	var col := Color(1.0, 0.85, 0.4, 0.8) if tier >= 2 else Color(0.85, 0.95, 1.0, 0.7)
	for k in range(1, 14):
		var t := k / 14.0
		var pos := from.lerp(target, t)
		pos.y = lerpf(from.y, target.y, t) + sin(t * PI) * (peak - maxf(from.y, target.y))
		var dot := MeshInstance3D.new()
		var ms := SphereMesh.new()
		ms.radius = 0.07
		ms.height = 0.14
		dot.mesh = ms
		var dm := StandardMaterial3D.new()
		dm.albedo_color = col
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dot.material_override = dm
		dot.position = pos
		add_child(dot)
		_preview.append(dot)

func _dismount() -> void:
	_riding = false
	_clear_preview()
	set_process_unhandled_input(false)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		player.rotation.x = 0.0
		player.set_physics_process(true)
		player.set("controls_enabled", true)

func _launch() -> void:
	if _amp < 1:
		_flash("No height yet. Pump first, with the rhythm.", 2.5)
		return
	var tier := _launch_tier()
	var target: Vector3 = TIER_TARGETS[tier - 1]
	if tier > _amp:
		_flash("The squall catches her mid-air and CARRIES her.", 3.0)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		_dismount()
		return
	_riding = false
	_clear_preview()
	set_process_unhandled_input(false)
	Sfx.play("jump_whoosh", 1.3, 0.05, -8.0)
	var from := player.global_position
	var fwd := (target - from).normalized()
	var yaw := atan2(fwd.x, fwd.z)
	var peak := maxf(from.y, target.y) + 2.6
	var dur := clampf(from.distance_to(target) / 9.0, 1.1, 1.9)
	var trail := _make_trail()
	var arc := create_tween()
	var step := func(t: float) -> void:
		var pos := from.lerp(target, t)
		pos.y = lerpf(from.y, target.y, t) + sin(t * PI) * (peak - maxf(from.y, target.y))
		player.global_position = pos
		# Nose-first: she stretches up through the rise, tips into the fall.
		player.rotation.y = yaw
		player.rotation.x = lerpf(-0.55, 0.35, t)
		trail.global_position = pos + Vector3(0, -0.15, 0)
	arc.tween_method(step, 0.0, 1.0, dur).set_trans(Tween.TRANS_LINEAR)
	arc.tween_callback(func() -> void:
		player.rotation.x = 0.0
		trail.set("emitting", false)
		get_tree().create_timer(0.8).timeout.connect(trail.queue_free)
		_land_puff(target)
		player.set_physics_process(true)
		player.set("controls_enabled", true)
		Sfx.play("land", 1.0, 0.05, -10.0)
		if tier >= 2:
			GameState.set_flag("swing_done")
		if tier >= 3 and not GameState.get_flag("seen_run_line"):
			GameState.set_flag("seen_run_line")
			_flash("From up here she sees it: a line of little red flags, poking from the drifts, running from the ridge all the way down to the shore.", 6.0))

# --- flight dressing ---

func _make_trail() -> Node3D:
	var trail := CPUParticles3D.new()
	trail.amount = 26
	trail.lifetime = 0.5
	trail.direction = Vector3(0, -1, 0)
	trail.spread = 35.0
	trail.gravity = Vector3(0, -5, 0)
	trail.initial_velocity_min = 0.6
	trail.initial_velocity_max = 1.4
	var flake := SphereMesh.new()
	flake.radius = 0.045
	flake.height = 0.09
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.95, 0.97, 1.0)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = fm
	trail.mesh = flake
	add_child(trail)
	return trail

func _land_puff(at: Vector3) -> void:
	var puff := CPUParticles3D.new()
	puff.amount = 30
	puff.lifetime = 0.6
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.direction = Vector3(0, 1, 0)
	puff.spread = 70.0
	puff.gravity = Vector3(0, -7, 0)
	puff.initial_velocity_min = 1.5
	puff.initial_velocity_max = 3.0
	var flake := SphereMesh.new()
	flake.radius = 0.05
	flake.height = 0.1
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.95, 0.97, 1.0)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = fm
	puff.mesh = flake
	puff.position = at
	puff.emitting = true
	add_child(puff)
	get_tree().create_timer(1.2).timeout.connect(puff.queue_free)

# --- helpers ---

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)
