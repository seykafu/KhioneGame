extends Node3D
## Island 3, Main Riddle — The Howl in the Off-Leash Meadow.
## A howl surfaces between breezes from the fenced meadow. The paw-marked
## key opens the gate. Inside, Oreo is tangled in his run-line around the
## great cottonwood, a bench, and the memorial stone: walk the line's path
## in reverse (stone, bench, tree) to unwind it. Free is not friends: share
## the cream, share the biscuits, and throw the ball once. Then he follows,
## forever. The canoe needs a shove only a dog can give; a scrap slips
## from under his collar on the way out.

const TREE := Vector3(0.0, 0.35, -27.0)
const BENCH := Vector3(-2.6, 0.35, -28.6)
const STONE := Vector3(1.8, 0.35, -27.6)
const OREO_HOME := Vector3(0.9, 0.35, -26.2)
const UNWIND_ORDER := ["stone", "bench", "tree"]

var _oreo: Node3D
var _ropes := {}          # leg name -> Array[MeshInstance3D]
var _pads := {}           # pad name -> MeshInstance3D
var _progress := 0
var _howl_player: AudioStreamPlayer3D
var _fed := false
var _throwing := false
var _departing := false
var _materials := {}

class GateLatch:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "A dog-proof gate latch"

	func interact(_player: Node) -> void:
		owner_puzzle.gate_interact()

class OreoPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "The tangled dog"

	func interact(player: Node) -> void:
		owner_puzzle.oreo_interact(player)

class CanoePlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "The beached canoe"

	func interact(_player: Node) -> void:
		owner_puzzle.canoe_interact()

func _ready() -> void:
	# Oreo, tangled by the tree.
	_oreo = Node3D.new()
	_oreo.name = "Oreo"
	_oreo.set_script(load("res://scripts/companions/oreo.gd"))
	get_parent().add_child.call_deferred(_oreo)
	_setup_oreo.call_deferred()
	# A meadow bench for the line to wrap.
	var island := get_parent()
	if island.has_method("_bench"):
		island._bench(BENCH, 0.55)
	_build_ropes()
	_build_pads()
	# The gate latch.
	var latch := GateLatch.new()
	latch.owner_puzzle = self
	latch.position = Vector3(0, 1.0, -22.4)
	_zone(latch, 1.9)
	add_child(latch)
	# The canoe shove point.
	var canoe_plate := CanoePlate.new()
	canoe_plate.owner_puzzle = self
	canoe_plate.position = Vector3(3.2, 0.6, 38.5)
	_zone(canoe_plate, 2.4)
	add_child(canoe_plate)
	# The howl, surfacing between breezes.
	_howl_player = AudioStreamPlayer3D.new()
	_howl_player.stream = load("res://assets/audio/howl.wav")
	_howl_player.position = TREE + Vector3(0, 0.8, 0)
	_howl_player.volume_db = -4.0
	_howl_player.max_distance = 60.0
	_howl_player.bus = "SFX"
	add_child(_howl_player)
	_howl_loop()

func _setup_oreo() -> void:
	_oreo.position = OREO_HOME
	_oreo.rotation.y = 2.6
	_oreo.set_ears_droop(true)
	var plate := OreoPlate.new()
	plate.owner_puzzle = self
	plate.position = Vector3(0, 0.6, 0)
	_zone(plate, 2.0)
	_oreo.add_child(plate)

func _zone(area: Area3D, radius: float) -> void:
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	cs.shape = sph
	area.add_child(cs)

func _howl_loop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var loop := func() -> void:
		while is_inside_tree():
			await get_tree().create_timer(rng.randf_range(16.0, 28.0)).timeout
			if not is_inside_tree() or GameState.get_flag("oreo_untangled"):
				return
			var breeze: Node = get_tree().get_first_node_in_group("bow_breeze")
			if breeze and not breeze.is_calm():
				continue
			_howl_player.pitch_scale = rng.randf_range(0.92, 1.05)
			_howl_player.play()
	loop.call()

# --- the run-line ---

func _build_ropes() -> void:
	# The line's written path: tree, bench, stone, and home to the collar.
	_ropes["bench"] = _rope_run(TREE + Vector3(-0.3, 0.5, -0.3), BENCH + Vector3(0.2, 0.45, 0.1))
	_ropes["stone"] = _rope_run(BENCH + Vector3(0.3, 0.4, -0.25), STONE + Vector3(-0.2, 0.35, -0.3))
	_ropes["tree"] = _rope_run(STONE + Vector3(0.1, 0.35, 0.25), TREE + Vector3(0.4, 0.45, 0.2))
	_ropes["collar"] = _rope_run(TREE + Vector3(0.4, 0.5, 0.3), OREO_HOME + Vector3(0, 0.55, 0.2))

func _rope_run(from: Vector3, to: Vector3) -> Array:
	var segs: Array = []
	var mid := (from + to) / 2.0 - Vector3(0, 0.12, 0)  # a little sag
	var pts := [from, mid, to]
	for i in 2:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.025
		cyl.bottom_radius = 0.025
		cyl.height = a.distance_to(b)
		seg.mesh = cyl
		seg.material_override = _mat(Color(0.62, 0.5, 0.36))
		seg.position = (a + b) / 2.0
		var dir := (b - a).normalized()
		var axis := Vector3.UP.cross(dir)
		if axis.length() > 0.001:
			seg.rotate(axis.normalized(), Vector3.UP.angle_to(dir))
		add_child(seg)
		segs.append(seg)
	return segs

func _build_pads() -> void:
	for def: Array in [["stone", STONE + Vector3(0.0, 0.02, 0.9)],
			["bench", BENCH + Vector3(0.9, 0.02, 0.6)], ["tree", TREE + Vector3(-0.9, 0.02, 0.7)]]:
		var name: String = def[0]
		var pad := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.34
		disc.bottom_radius = 0.34
		disc.height = 0.03
		pad.mesh = disc
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.85, 0.45, 0.5)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(0.95, 0.8, 0.4)
		m.emission_energy_multiplier = 0.6
		pad.material_override = m
		pad.position = def[1]
		pad.visible = false
		add_child(pad)
		_pads[name] = pad
		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var cylsh := CylinderShape3D.new()
		cylsh.radius = 0.55
		cylsh.height = 1.2
		cs.shape = cylsh
		area.add_child(cs)
		area.position = (def[1] as Vector3) + Vector3(0, 0.5, 0)
		area.body_entered.connect(_on_pad.bind(name))
		add_child(area)

func gate_interact() -> void:
	if GameState.get_flag("meadow_open"):
		_flash("The gate stands open. The meadow holds its breath.", 2.5)
		return
	if not Inventory.has_item("paw_key"):
		Sfx.play("stone_slide", 0.7, 0.0, -16.0)
		_flash("The latch is dog-proof and stranger-proof both. It wants a key… one that knows about paws.", 4.0)
		return
	Inventory.remove_item("paw_key")
	GameState.set_flag("meadow_open")
	Sfx.play("pickup_chime", 1.0, 0.0, -10.0)
	Sfx.play("wood_creak", 1.0, 0.05, -8.0)
	var island := get_parent()
	var gate: Node3D = island.get_node_or_null("MeadowGate")
	if gate:
		var t := create_tween()
		t.tween_property(gate, "position", gate.position + Vector3(-1.5, 0, -0.5), 1.1) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(gate, "rotation:y", 1.2, 1.1)
	for pad_name: String in _pads:
		_pads[pad_name].visible = true
	_flash("The paw key turns. The gate swings wide… and the howler falls silent, watching her come.", 5.0)

func _on_pad(body: Node3D, pad_name: String) -> void:
	if not body.is_in_group("player") or GameState.get_flag("oreo_untangled") \
			or not GameState.get_flag("meadow_open"):
		return
	if pad_name == UNWIND_ORDER[_progress]:
		_progress += 1
		Sfx.play("pickup_chime", 0.75 + 0.15 * _progress, 0.0, -14.0)
		var leg: String = ["tree", "stone", "bench"][_progress - 1]
		for seg: MeshInstance3D in _ropes[leg]:
			var t := seg.create_tween()
			t.tween_property(seg, "scale", Vector3(0.05, 1.0, 0.05), 0.5)
			t.tween_callback(seg.queue_free)
		_ropes.erase(leg)
		_pads[pad_name].visible = false
		if _progress >= UNWIND_ORDER.size():
			_untangled()
		else:
			_flash("A loop lets go. The line hangs looser…", 2.5)
	else:
		_progress = 0
		Sfx.play("whimper", 1.0, 0.05, -8.0)
		_oreo.set_ears_droop(true)
		for pad_name2: String in _pads:
			_pads[pad_name2].visible = true
		_rebuild_missing_ropes()
		_flash("The line cinches tighter and his ears drop. Walk it backwards: the way it was wound, undone.", 4.0)

func _rebuild_missing_ropes() -> void:
	for leg: String in ["bench", "stone", "tree"]:
		if not _ropes.has(leg):
			match leg:
				"bench":
					_ropes["bench"] = _rope_run(TREE + Vector3(-0.3, 0.5, -0.3), BENCH + Vector3(0.2, 0.45, 0.1))
				"stone":
					_ropes["stone"] = _rope_run(BENCH + Vector3(0.3, 0.4, -0.25), STONE + Vector3(-0.2, 0.35, -0.3))
				"tree":
					_ropes["tree"] = _rope_run(STONE + Vector3(0.1, 0.35, 0.25), TREE + Vector3(0.4, 0.45, 0.2))

func _untangled() -> void:
	GameState.set_flag("oreo_untangled")
	for seg: MeshInstance3D in _ropes.get("collar", []):
		var t := seg.create_tween()
		t.tween_property(seg, "scale", Vector3(0.05, 1.0, 0.05), 0.5)
		t.tween_callback(seg.queue_free)
	_ropes.erase("collar")
	for pad_name: String in _pads:
		_pads[pad_name].visible = false
	_oreo.shake_free()
	Sfx.play("bark", 1.0, 0.0, -8.0)
	_flash("The last loop slides free. He shakes from nose to tail… and sits, watching her. Free is not the same as friends.", 5.5)

# --- cream, biscuits, and the ball ---

func oreo_interact(_player: Node) -> void:
	if GameState.get_flag("oreo_joined"):
		Sfx.play("bark", 1.05, 0.03, -8.0)
		_oreo.hop()
		_flash("Tail like a metronome in a hurricane.", 2.5)
		return
	if not GameState.get_flag("oreo_untangled"):
		Sfx.play("whimper", 0.95, 0.05, -10.0)
		_flash("He goes very still, tangled to the tree. The line loops tree, bench, stone… wound in that order.", 4.5)
		return
	if not _fed:
		if Inventory.has_item("cream_jug") and Inventory.has_item("dog_biscuits"):
			Inventory.remove_item("cream_jug")
			Inventory.remove_item("dog_biscuits")
			_fed = true
			GameState.set_flag("oreo_fed")
			_box(Vector3(0.3, 0.05, 0.3), OREO_HOME + Vector3(-0.5, 0.03, 0.3), Color(0.95, 0.93, 0.86))
			_box(Vector3(0.24, 0.06, 0.16), OREO_HOME + Vector3(0.5, 0.03, 0.4), Color(0.72, 0.55, 0.3))
			Sfx.play("pickup_chime", 0.9, 0.0, -12.0)
			var t := create_tween()
			t.tween_property(_oreo, "rotation:y", 3.4, 0.5)
			_flash("Cream, and biscuits, laid in the grass. He eats like it is a ceremony. Then he looks up… expecting one more thing.", 5.5)
			return
		var missing := []
		if not Inventory.has_item("cream_jug"):
			missing.append("cream")
		if not Inventory.has_item("dog_biscuits"):
			missing.append("biscuits")
		_flash("He will not follow a stranger. A friend shares food… she still needs %s." % " and ".join(missing), 4.0)
		return
	# Fed. Now the handshake: one thrown ball.
	if not Inventory.has_item("tennis_ball"):
		_flash("He nudges her paw, then stares at the grass, then at her, then at the grass. He wants something thrown.", 4.0)
		return
	if _throwing:
		return
	_throwing = true
	Inventory.remove_item("tennis_ball")
	_throw_ball()

func _throw_ball() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var from := player.global_position + Vector3(0, 0.5, 0) if player else OREO_HOME
	var land := Vector3(-4.2, 0.4, -25.6)
	var ball := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.09
	bs.height = 0.18
	ball.mesh = bs
	ball.material_override = _mat(Color(0.8, 0.9, 0.3))
	ball.position = from
	add_child(ball)
	Sfx.play("whisker_shimmer", 1.3, 0.0, -14.0)
	var arc := create_tween()
	var step := func(t: float) -> void:
		var pos := from.lerp(land, t)
		pos.y += 1.6 * sin(t * PI)
		ball.position = pos
	arc.tween_method(step, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_LINEAR)
	arc.tween_callback(func() -> void:
		_oreo.move_to(land)
		Sfx.play("bark", 1.1, 0.0, -10.0)
		var chase := create_tween()
		chase.tween_interval(1.2)
		chase.tween_callback(func() -> void:
			ball.reparent(_oreo)
			ball.position = Vector3(0, 0.58, 0.62)  # carried in the mouth
			var back_to := player.global_position if player else OREO_HOME
			_oreo.move_to(back_to + Vector3(0.6, 0, 0.6))
			var drop := create_tween()
			drop.tween_interval(1.6)
			drop.tween_callback(func() -> void:
				ball.reparent(self)
				var pp := player.global_position if player else OREO_HOME
				ball.position = pp + Vector3(0.3, -0.25, 0.3)
				_oreo.hop()
				Sfx.play("bark", 1.0, 0.0, -8.0)
				Sfx.play("bark", 1.15, 0.0, -10.0)
				_join())))

func _join() -> void:
	_throwing = false
	GameState.set_flag("oreo_friend")
	GameState.set_flag("oreo_joined")
	_oreo.following = true
	_oreo.set_ears_droop(false)
	_flash("He drops the ball at her paws. That is the whole handshake. From here on, Oreo follows.", 5.5)
	var late := create_tween()
	late.tween_interval(6.0)
	late.tween_callback(func() -> void:
		_flash("The canoe on the gravel bar is heavy… but she is not alone anymore.", 4.5))

# --- the shove-off ---

func canoe_interact() -> void:
	if _departing or GameState.get_flag("island3_complete"):
		return
	if not GameState.get_flag("oreo_joined"):
		_flash("Beached hard on the gravel. Far too heavy for one small cat.", 3.5)
		return
	_departing = true
	var island := get_parent()
	var canoe: Node3D = island.get_node_or_null("Canoe")
	_oreo.move_to(Vector3(3.2, 0.35, 37.2))
	var seq := create_tween()
	seq.tween_interval(1.6)
	seq.tween_callback(func() -> void:
		Sfx.play("bark", 1.0, 0.0, -10.0)
		if canoe:
			var shove := create_tween()
			shove.tween_property(canoe, "position", canoe.position + Vector3(-0.6, -0.35, 4.5), 1.4) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		Sfx.play("splash", 1.0, 0.05, -8.0))
	seq.tween_interval(1.8)
	seq.tween_callback(func() -> void:
		_show_fragment()
		GameState.set_flag("letter_fragment_3")
		GameState.set_flag("island3_complete"))
	seq.tween_interval(5.5)
	seq.tween_callback(func() -> void:
		_departing = false
		_flash("Prince's Island hums with summer behind them. Vancouver waits beyond the horizon. (Island 4 coming soon)", 6.0))

func _show_fragment() -> void:
	Sfx.play("paper_open", 1.0, 0.05, -6.0)
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
			preload("res://scripts/ui/hud.gd").parchment_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_top = -110.0
	panel.offset_right = 280.0
	panel.offset_bottom = 110.0
	ui.add_child(panel)
	var margin := MarginContainer.new()
	for m_side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(m_side, 22)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)
	var caption := Label.new()
	caption.text = "As he settles into the bow, a scrap slips from under his collar:"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(0.4, 0.3, 0.18))
	vbox.add_child(caption)
	var fragment := Label.new()
	fragment.text = "“Could I …”"
	fragment.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fragment.add_theme_font_size_override("font_size", 34)
	fragment.add_theme_color_override("font_color", Color(0.28, 0.2, 0.12))
	vbox.add_child(fragment)
	panel.modulate.a = 0.0
	var t := panel.create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.7)
	t.tween_interval(4.2)
	t.tween_property(panel, "modulate:a", 0.0, 0.7)
	t.tween_callback(ui.queue_free)

# --- helpers ---

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		_materials[color] = m
	return _materials[color]

func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
	return mi
