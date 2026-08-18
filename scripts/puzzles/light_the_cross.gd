extends Node3D
## Island 5, Main riddle — Light the Cross.
## Phase 1: fit the three arena panes so every lantern can hold light.
## Phase 2: warm bagels in the twelve lantern bases (à la douzaine): the
## sky goes to dusk, the city lights come on, and the fireflies come
## upslope to circle the cross. They will not settle.
## Phase 3: on the summit drum, Khione plays the tam-tam pattern and Oreo
## barks the echoes: the swarm pulses in sync and pours into the
## lanterns tier by tier, and the cross lights like a slow vertical
## sunrise. Its shadow finds the funicular gate; ride down through the
## glowing woods to the river, where fragment 5 waits under the bench.

const BROKEN := [2, 7, 10]
const PATTERN: Array[String] = ["low", "high", "low", "mid"]
const GAP_MIN := 0.7
const GAP_MAX := 1.7
const DRUM_SFX := {"low": "drum_low", "mid": "drum_mid", "high": "drum_high"}

var _fireflies: Array[Node3D] = []
var _swarm_t := 0.0
var _swarming := false
var _settled := false
var _progress := 0
var _last_hit := -10.0
var _riding := false

class CrossPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "The dark lanterns"

	func interact(_player: Node) -> void:
		owner_puzzle.cross_interact()

class SummitDrumPlate:
	extends Interactable
	var owner_puzzle: Node
	var kind := ""

	func interact(_player: Node) -> void:
		owner_puzzle.drum_hit(kind)

class FunicularPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Board the funicular"

	func interact(_player: Node) -> void:
		owner_puzzle.board()

func _ready() -> void:
	var island := get_parent()
	var cross: Node3D = island.cross
	var plate := CrossPlate.new()
	plate.owner_puzzle = self
	plate.position = Vector3(0, 1.2, 1.2)
	_zone(plate, 2.6)
	cross.add_child(plate)
	# The summit drum answers three ways: the pattern is played on ONE
	# drum here by striking its three chalk marks (low/mid/high zones).
	var drum: Node3D = cross.get_node("SummitDrum")
	for def: Array in [["low", Vector3(0, 0.75, 0.3)], ["mid", Vector3(0.3, 0.75, -0.2)], ["high", Vector3(-0.3, 0.75, -0.2)]]:
		var dp := SummitDrumPlate.new()
		dp.owner_puzzle = self
		dp.kind = def[0]
		dp.prompt = "Strike the %s mark" % def[0]
		dp.position = def[1]
		_zone(dp, 0.9)
		drum.add_child(dp)
		var mark := MeshInstance3D.new()
		var mm := SphereMesh.new()
		mm.radius = 0.06 if def[0] == "high" else (0.1 if def[0] == "mid" else 0.14)
		mm.height = mm.radius * 2.0
		mark.mesh = mm
		var mmat := StandardMaterial3D.new()
		mmat.albedo_color = Color(0.95, 0.95, 0.9)
		mark.material_override = mmat
		mark.position = (def[1] as Vector3) - Vector3(0, 0.02, 0)
		mark.scale = Vector3(1, 0.2, 1)
		drum.add_child(mark)
	var fp := FunicularPlate.new()
	fp.owner_puzzle = self
	fp.position = Vector3(0, 0.8, 0)
	_zone(fp, 2.0)
	(island.funicular_car as Node3D).add_child(fp)
	if GameState.get_flag("island5_complete"):
		_light_all_instant()

# --- Phases 1 & 2: panes and bagels ---

func cross_interact() -> void:
	var island := get_parent()
	if not GameState.get_flag("panes_fitted"):
		if Inventory.count_of("arena_pane") >= 3:
			for i in 3:
				Inventory.remove_item("arena_pane")
			GameState.set_flag("panes_fitted")
			Sfx.play("pickup_chime", 1.1, 0.0, -10.0)
			for i: int in BROKEN:
				var glass := (island.cross as Node3D).get_node("Lantern%d/Glass" % i)
				glass.visible = true
			_flash("Three panes of arena glass, exactly lantern-sized. Every lantern on the cross can hold light now. If light could be found.", 5.0)
			return
		_flash("A lattice of dark lanterns, twelve bases up the post and along the arms. Three have no glass at all. Nothing up here holds a light yet.", 5.0)
		return
	if not GameState.get_flag("bagels_placed"):
		var n := Inventory.count_of("bagel")
		if n >= 12:
			for i in 12:
				Inventory.remove_item("bagel")
			GameState.set_flag("bagels_placed")
			Sfx.play("oven_pop", 0.9, 0.0, -10.0)
			for i in 12:
				var lantern := (island.cross as Node3D).get_node("Lantern%d" % i)
				var bagel := MeshInstance3D.new()
				var bm := TorusMesh.new()
				bm.inner_radius = 0.06
				bm.outer_radius = 0.14
				bagel.mesh = bm
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.85, 0.6, 0.3)
				bagel.material_override = mat
				bagel.position = Vector3(0, -0.2, 0)
				bagel.rotation.x = PI / 2.0
				lantern.add_child(bagel)
			island.set_dusk()
			_flash("Twelve warm bagels in twelve bases. The sky leans to dusk, the city lights come on below… and up the slope, one blink. Then hundreds.", 6.0)
			get_tree().create_timer(3.0).timeout.connect(_summon_swarm)
			return
		if n > 0:
			_flash("Twelve bases; %d bagel%s. The sign at the oven said à la douzaine, and this mountain counts." % [n, "" if n == 1 else "s"], 4.5)
		else:
			_flash("Twelve lantern bases, cold. Fireflies love warmth. Something on this mountain bakes it by the dozen.", 4.5)
		return
	if not _settled:
		_flash("The swarm circles and circles. They will not settle for warmth alone. Fireflies blink in rhythm; the drum by the cross remembers one.", 4.5)
		return
	_flash("The cross burns warm over the city. Its shadow points down the west slope: the funicular gate stands open.", 4.0)

func _summon_swarm() -> void:
	var island := get_parent()
	Sfx.play("firefly_hum", 1.0, 0.0, -10.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in 48:
		var f := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		f.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 1.0, 0.5)
		m.emission_enabled = true
		m.emission = Color(0.8, 1.0, 0.4)
		m.emission_energy_multiplier = 1.8
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		f.material_override = m
		f.set_meta("phase", rng.randf_range(0.0, TAU))
		f.set_meta("r", rng.randf_range(2.5, 5.0))
		f.set_meta("h", rng.randf_range(1.0, 9.0))
		f.set_meta("spd", rng.randf_range(0.5, 1.1))
		f.position = (island.cross as Node3D).position + Vector3(0, 4.0, 0)
		add_child(f)
		_fireflies.append(f)
	_swarming = true

func _process(delta: float) -> void:
	if not _swarming or _settled:
		return
	_swarm_t += delta
	var island := get_parent()
	var c: Vector3 = (island.cross as Node3D).position
	for f in _fireflies:
		var ph: float = f.get_meta("phase") + _swarm_t * float(f.get_meta("spd"))
		var r: float = f.get_meta("r")
		f.position = c + Vector3(cos(ph) * r, float(f.get_meta("h")) + sin(ph * 2.3) * 0.5, sin(ph) * r * 0.6 + 1.0)
		var m := f.material_override as StandardMaterial3D
		m.emission_energy_multiplier = 0.6 + 1.6 * maxf(0.0, sin(ph * 4.0 + float(f.get_meta("phase"))))

# --- Phase 3: the summit duet ---

func drum_hit(kind: String) -> void:
	Sfx.play(DRUM_SFX[kind], 1.0, 0.02, -6.0)
	if _settled or not _swarming:
		if not _swarming:
			_flash("The drum booms over an empty summit. Warmth first; the fireflies are not here yet.", 3.0)
		return
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	# Oreo barks the echo: the duet's other half.
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		Sfx.play("bark", 1.0 if kind == "low" else 1.15, 0.02, -10.0)
		if oreo and oreo.has_method("hop"):
			oreo.hop())
	var now := Time.get_ticks_msec() / 1000.0
	var gap := now - _last_hit
	_last_hit = now
	if _progress > 0 and (gap < GAP_MIN or gap > GAP_MAX):
		_progress = 0
	if kind == PATTERN[_progress]:
		_progress += 1
		# The swarm pulses tighter with every true beat.
		for f in _fireflies:
			f.set_meta("r", maxf(1.2, float(f.get_meta("r")) * 0.85))
		if _progress >= PATTERN.size():
			_settle()
	else:
		_progress = 1 if kind == PATTERN[0] else 0
		for f in _fireflies:
			f.set_meta("r", minf(5.0, float(f.get_meta("r")) * 1.2))

func _settle() -> void:
	_settled = true
	GameState.set_flag("cross_lit")
	Sfx.play("firefly_hum", 1.2, 0.0, -6.0)
	var island := get_parent()
	var cross: Node3D = island.cross
	# Tier by tier, bottom to top, the swarm pours into the lanterns.
	var order: Array[int] = [0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 5]
	for i in order.size():
		var li: int = order[i]
		var lantern: Node3D = cross.get_node("Lantern%d" % li)
		get_tree().create_timer(0.55 * i).timeout.connect(func() -> void:
			_light_lantern(lantern)
			# Four fireflies per lantern fly home.
			for k in 4:
				var idx := i * 4 + k
				if idx < _fireflies.size():
					var f := _fireflies[idx]
					var t := f.create_tween()
					t.tween_property(f, "global_position", lantern.global_position, 0.5) \
							.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
					t.tween_callback(f.queue_free))
	get_tree().create_timer(0.55 * order.size() + 0.6).timeout.connect(func() -> void:
		_fireflies.clear()
		_swarming = false
		Sfx.play("pickup_chime", 1.3, 0.0, -6.0)
		_open_gate()
		_flash("Tier by tier the swarm pours in and the CROSS LIGHTS, a slow vertical sunrise over the whole city. Its shadow falls down the west slope… onto a gate.", 6.5))

func _light_lantern(lantern: Node3D) -> void:
	var glass := lantern.get_node("Glass") as MeshInstance3D
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.92, 0.7, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.5)
	m.emission_energy_multiplier = 2.2
	glass.material_override = m
	glass.visible = true

func _light_all_instant() -> void:
	_settled = true
	var island := get_parent()
	for i in 12:
		var lantern: Node3D = (island.cross as Node3D).get_node("Lantern%d" % i)
		_light_lantern(lantern)
	_open_gate(true)

func _open_gate(instant := false) -> void:
	var island := get_parent()
	var gate: Node3D = island.get_node("UpperStation/Gate")
	if gate == null:
		return
	if instant:
		gate.rotation.y = 1.5
		return
	Sfx.play("gate_open", 1.0, 0.0, -8.0)
	var t := create_tween()
	t.tween_property(gate, "rotation:y", 1.5, 1.0).set_trans(Tween.TRANS_BOUNCE)

# --- Phase 4: the ride down ---

func board() -> void:
	if _riding:
		return
	if not GameState.get_flag("cross_lit"):
		_flash("The old funicular waits behind a shut gate. Nothing has told it to move in a hundred years.", 3.5)
		return
	if GameState.get_flag("island5_complete"):
		_flash("The car rides at the summit again, patient as the mountain. She has taken this ride; the fragment is hers.", 3.5)
		return
	_riding = true
	_ride()

func _ride() -> void:
	var island := get_parent()
	var car: Node3D = island.funicular_car
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	if player == null:
		_riding = false
		return
	player.set("controls_enabled", false)
	player.set_physics_process(false)
	if oreo:
		oreo.set("following", false)
		oreo.set("scripted", true)
	Sfx.play("funicular_bell", 1.0, 0.0, -6.0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var pts: Array = island.FUNICULAR_ROUTE
	var ride := create_tween()
	var step := func(u: float) -> void:
		var f := u * (pts.size() - 1)
		var i := clampi(int(f), 0, pts.size() - 2)
		var pos := (pts[i] as Vector3).lerp(pts[i + 1], f - i)
		var nxt: Vector3 = pts[mini(i + 2, pts.size() - 1)]
		var dir := (nxt - pos)
		var flat := Vector3(dir.x, 0, dir.z).normalized()
		car.global_position = pos
		car.rotation.y = atan2(flat.x, flat.z)
		var pitch := clampf(atan2(-dir.y, Vector2(dir.x, dir.z).length()), -0.6, 0.6)
		car.rotation.x = pitch * 0.5
		if player:
			player.global_position = car.to_global(Vector3(-0.35, 0.55, 0.2))
			player.rotation.y = car.rotation.y
		if oreo:
			oreo.global_position = car.to_global(Vector3(0.4, 0.5, -0.4))
			oreo.rotation.y = car.rotation.y
		cam.global_position = pos + Vector3(-flat.x, 0, -flat.z) * 6.0 + Vector3(0, 3.2, 0)
		cam.look_at(pos + flat * 3.0 + Vector3(0, 0.6, 0))
	ride.tween_method(step, 0.0, 1.0, 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ride.tween_callback(func() -> void:
		_finish(player, oreo, cam))

func _finish(player: Node3D, oreo: Node3D, cam: Camera3D) -> void:
	Sfx.play("funicular_bell", 0.95, 0.0, -6.0)
	var island := get_parent()
	var beat := create_tween()
	beat.tween_interval(0.8)
	beat.tween_callback(func() -> void:
		_show_fragment()
		GameState.set_flag("letter_fragment_5")
		GameState.set_flag("island5_complete"))
	beat.tween_interval(5.8)
	beat.tween_callback(func() -> void:
		var bottom: Vector3 = island.FUNICULAR_BOTTOM
		player.global_position = bottom + Vector3(2.4, 0.4, 0.0)
		player.rotation = Vector3(0, PI / 2.0, 0)
		player.set_physics_process(true)
		player.set("controls_enabled", true)
		var pcam: Camera3D = player.get("rig").get_node("SpringArm/Camera")
		pcam.current = true
		cam.queue_free()
		if oreo:
			oreo.set("scripted", false)
			oreo.set("following", true)
			oreo.global_position = bottom + Vector3(3.6, 0.4, 1.0)
		_riding = false
		_flash("The cross burns warm over the whole city, and the mountain hums under a hundred lit windows. West, a bay full of blossom wind is waiting. (Island 6 coming soon)", 6.5))

func _show_fragment() -> void:
	Sfx.play("paper_open", 1.0, 0.05, -6.0)
	var ui := CanvasLayer.new()
	ui.layer = 15
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
	caption.text = "Tucked under the funicular's bench, folded small, in a hand that pressed too hard on the pencil:"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(0.4, 0.3, 0.18))
	vbox.add_child(caption)
	var fragment := Label.new()
	fragment.text = "“… adventure.”"
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

## Test hooks.
func force_swarm() -> void:
	if not _swarming:
		_summon_swarm()

func force_duet() -> void:
	_progress = 0
	_last_hit = -10.0
	if not _swarming:
		_summon_swarm()
	_settle()

func _zone(area: Area3D, radius: float) -> void:
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	cs.shape = sph
	area.add_child(cs)

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)
