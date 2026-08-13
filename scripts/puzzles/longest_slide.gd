extends Node3D
## Island 4, Main Riddle — The Longest Slide.
## The crescent's kids built a legendary toboggan run, ridge to shore, and
## three winters buried it. Salt melts the frozen start gate; under it the
## toboggan sleeps (Oreo digs); wax and bolts wake it. Then the duet at
## full gallop: whisker-mark each buried gate down the flag-line, Oreo digs
## on her mark, and when all six stand open: the ride. Through the final
## drift, into the storm cellar, where the fragment waits under a kite
## reel with no kite.

const GATE_COUNT := 6
const CELLAR := Vector3(-1.0, 0.2, 36.0)

var _path: Array[Vector2] = []       # the island's RUN_PATH
var _gates_dug := 0
var _ice_block: MeshInstance3D
var _toboggan: Node3D
var _sled_plate: Area3D
var _final_drift: MeshInstance3D
var _riding := false
var _materials := {}

class IcePlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "A gate frozen solid"

	func interact(_player: Node) -> void:
		owner_puzzle.ice_interact()

class SledPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "The sleeping toboggan"

	func interact(_player: Node) -> void:
		owner_puzzle.sled_interact()

func _ready() -> void:
	var island := get_parent()
	_path.assign(island.RUN_PATH)
	# Flag pairs mark every gate; the gates themselves sleep under mounds.
	for g in range(1, GATE_COUNT + 1):
		var p := _path[g]
		var prev := _path[g - 1]
		var next := _path[g + 1]
		var dir := (next - prev).normalized()
		var side := Vector2(-dir.y, dir.x)
		var h: float = island._terrain_height(p.x, p.y)
		for s: float in [-1.0, 1.0]:
			var fp := p + side * 1.3 * s
			var fh: float = island._terrain_height(fp.x, fp.y)
			_add_mesh(_cyl(0.03, 0.04, 1.2), Vector3(fp.x, fh + 0.6, fp.y), Color(0.45, 0.38, 0.3), false)
			var flag := _add_mesh(_box_mesh(Vector3(0.02, 0.16, 0.3)),
					Vector3(fp.x, fh + 1.1, fp.y + 0.16 * s), Color(0.85, 0.25, 0.2), false)
			flag.rotation.y = atan2(dir.x, dir.y)
		var mound := Diggable.new()
		mound.mound_radius = 1.0
		mound.position = Vector3(p.x, h, p.y)
		add_child(mound)
		mound.dug.connect(_on_gate_dug)
	# The frozen start gate at the top of the ridge.
	var start := _path[0]
	var sh: float = island._terrain_height(start.x, start.y)
	_ice_block = _add_mesh(_box_mesh(Vector3(1.5, 1.2, 1.1)), Vector3(start.x, sh + 0.6, start.y),
			Color(0.7, 0.84, 0.94, 0.75), false)
	var ice_plate := IcePlate.new()
	ice_plate.owner_puzzle = self
	ice_plate.position = _ice_block.position
	_zone(ice_plate, 2.0)
	add_child(ice_plate)
	# The final drift banked against the shore cellar.
	_final_drift = _add_mesh(_sphere_mesh(1.7, 1.3), CELLAR + Vector3(0, 0.4, -0.8),
			Color(0.93, 0.95, 0.99), false)
	_final_drift.scale = Vector3(1.5, 0.9, 1.0)
	# The cellar doorframe peeking from the bank.
	_add_mesh(_box_mesh(Vector3(1.7, 0.25, 0.3)), CELLAR + Vector3(0, 1.15, 0.2), Color(0.45, 0.38, 0.3), false)
	for s in [-0.8, 0.8]:
		_add_mesh(_box_mesh(Vector3(0.2, 1.2, 0.3)), CELLAR + Vector3(s, 0.55, 0.2), Color(0.45, 0.38, 0.3), false)

func ice_interact() -> void:
	if _ice_block == null:
		return
	if not Inventory.has_item("road_salt"):
		Sfx.play("stone_slide", 0.6, 0.0, -16.0)
		_flash("Solid ice, older than three winters. Salt would talk sense into it.", 3.5)
		return
	Inventory.remove_item("road_salt")
	Sfx.play("drain", 0.8, 0.0, -12.0)
	var block := _ice_block
	_ice_block = null
	var t := block.create_tween()
	t.tween_property(block, "scale", Vector3(1.1, 0.04, 1.1), 1.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func() -> void:
		block.queue_free()
		_reveal_toboggan()
		_flash("The salt gnaws the gate open… and under the ice, a long low lump of snow with two wooden tips poking out.", 5.0))

func _reveal_toboggan() -> void:
	var island := get_parent()
	var start := _path[0]
	var sh: float = island._terrain_height(start.x, start.y)
	var mound := Diggable.new()
	mound.mound_radius = 0.9
	mound.position = Vector3(start.x, sh, start.y)
	add_child(mound)
	mound.dug.connect(func() -> void:
		_build_toboggan(Vector3(start.x, sh, start.y))
		_flash("The toboggan! Cedar planks, curled nose, fifty years of stories. It wants wax, and its runner bolts back.", 5.0))

func _build_toboggan(pos: Vector3) -> void:
	_toboggan = Node3D.new()
	_toboggan.position = pos
	add_child(_toboggan)
	for i in 3:
		var plank := _add_mesh(_box_mesh(Vector3(0.22, 0.05, 2.0)), Vector3.ZERO, Color(0.62, 0.48, 0.32), false)
		plank.position = Vector3(-0.24 + i * 0.24, 0.18, 0)
		plank.reparent(_toboggan)
		plank.position = Vector3(-0.24 + i * 0.24, 0.18, 0)
		var curl := _add_mesh(_cyl(0.11, 0.11, 0.24), Vector3.ZERO, Color(0.62, 0.48, 0.32), false)
		curl.reparent(_toboggan)
		curl.position = Vector3(-0.24 + i * 0.24, 0.3, 1.0)
		curl.rotation.z = PI / 2.0
	_sled_plate = SledPlate.new()
	_sled_plate.owner_puzzle = self
	_sled_plate.position = Vector3(0, 0.5, 0)
	_zone(_sled_plate, 2.0)
	_toboggan.add_child(_sled_plate)

func _on_gate_dug() -> void:
	_gates_dug += 1
	if _gates_dug >= GATE_COUNT:
		_flash("Every gate on the flag-line stands open, ridge to shore. The run is ALIVE again.", 4.5)
	else:
		_flash("Gate open. %d more on the flag-line." % (GATE_COUNT - _gates_dug), 2.5)

func sled_interact() -> void:
	if _riding:
		return
	if not GameState.get_flag("sled_ready"):
		if Inventory.has_item("runner_wax") and Inventory.has_item("runner_bolts"):
			Inventory.remove_item("runner_wax")
			Inventory.remove_item("runner_bolts")
			GameState.set_flag("sled_ready")
			Sfx.play("pickup_chime", 1.1, 0.0, -10.0)
			_flash("Bolts seated, runners waxed to a wicked shine. The toboggan remembers exactly what it is.", 4.5)
			return
		_flash("It needs its runner bolts back, and a proper wax. The rink and the rooftops keep such things.", 4.0)
		return
	if _gates_dug < GATE_COUNT:
		_flash("The run is still buried in %d places. Walk the flag-line: she marks, he digs." % (GATE_COUNT - _gates_dug), 4.0)
		return
	_the_ride()

func _the_ride() -> void:
	_riding = true
	var island := get_parent()
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
	# Densify the run into a smooth ride curve.
	var pts: Array[Vector2] = []
	for i in _path.size() - 1:
		var p0 := _path[maxi(i - 1, 0)]
		var p3 := _path[mini(i + 2, _path.size() - 1)]
		for k in 8:
			var t := k / 8.0
			var t2 := t * t
			var t3 := t2 * t
			pts.append(0.5 * ((2.0 * _path[i]) + (-p0 + _path[i + 1]) * t
					+ (2.0 * p0 - 5.0 * _path[i] + 4.0 * _path[i + 1] - p3) * t2
					+ (-p0 + 3.0 * _path[i] - 3.0 * _path[i + 1] + p3) * t3))
	pts.append(_path[-1])
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	Sfx.play("jump_whoosh", 0.7, 0.0, -8.0)
	var spray := _spray()
	var ride := create_tween()
	var step := func(u: float) -> void:
		var f := u * (pts.size() - 1)
		var i := clampi(int(f), 0, pts.size() - 2)
		var p := pts[i].lerp(pts[i + 1], f - i)
		var nxt := pts[mini(i + 2, pts.size() - 1)]
		var dir3 := Vector3(nxt.x - p.x, 0, nxt.y - p.y).normalized()
		var h: float = island._terrain_height(p.x, p.y)
		var pos := Vector3(p.x, maxf(h, 0.1) + 0.45, p.y)
		player.global_position = pos
		player.rotation.y = atan2(dir3.x, dir3.z)
		if _toboggan:
			_toboggan.global_position = pos + Vector3(0, -0.25, 0)
			_toboggan.rotation.y = player.rotation.y
		if oreo:
			oreo.global_position = pos - dir3 * 1.0 + Vector3(0, 0.05, 0)
			oreo.rotation.y = player.rotation.y
		spray.global_position = pos + Vector3(0, -0.1, 0)
		cam.global_position = pos - dir3 * 5.0 + Vector3(0, 2.4, 0)
		cam.look_at(pos + dir3 * 2.0)
	ride.tween_method(step, 0.0, 1.0, 9.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	ride.tween_callback(func() -> void:
		_burst_cellar(player, oreo, cam, spray))

func _spray() -> Node3D:
	var spray := CPUParticles3D.new()
	spray.amount = 40
	spray.lifetime = 0.6
	spray.direction = Vector3(0, 1, -1)
	spray.spread = 40.0
	spray.gravity = Vector3(0, -8, 0)
	spray.initial_velocity_min = 2.0
	spray.initial_velocity_max = 4.0
	var flake := SphereMesh.new()
	flake.radius = 0.05
	flake.height = 0.1
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.95, 0.97, 1.0)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = fm
	spray.mesh = flake
	add_child(spray)
	return spray

func _burst_cellar(player: Node3D, oreo: Node3D, cam: Camera3D, spray: Node3D) -> void:
	Sfx.play("land", 0.8, 0.0, -4.0)
	Sfx.play("splash", 0.7, 0.0, -10.0)
	if _final_drift:
		var boom := CPUParticles3D.new()
		boom.amount = 60
		boom.lifetime = 0.9
		boom.one_shot = true
		boom.explosiveness = 1.0
		boom.direction = Vector3(0, 1, 0)
		boom.spread = 70.0
		boom.gravity = Vector3(0, -7, 0)
		boom.initial_velocity_min = 3.0
		boom.initial_velocity_max = 6.0
		var flake := SphereMesh.new()
		flake.radius = 0.07
		flake.height = 0.14
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.95, 0.97, 1.0)
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flake.material = fm
		boom.mesh = flake
		boom.position = _final_drift.position
		boom.emitting = true
		add_child(boom)
		_final_drift.queue_free()
		_final_drift = null
	spray.queue_free()
	var beat := create_tween()
	beat.tween_interval(1.2)
	beat.tween_callback(func() -> void:
		_show_fragment()
		GameState.set_flag("letter_fragment_4")
		GameState.set_flag("island4_complete"))
	beat.tween_interval(5.6)
	beat.tween_callback(func() -> void:
		player.global_position = Vector3(0.5, 0.6, 38.0)
		player.set_physics_process(true)
		player.set("controls_enabled", true)
		var pcam: Camera3D = player.get("rig").get_node("SpringArm/Camera")
		pcam.current = true
		cam.queue_free()
		if oreo:
			oreo.set("scripted", false)
			oreo.set("following", true)
		_riding = false
		_flash("The crescent sleeps under brand-new tracks. Somewhere warm, an indoor sea is waiting. (Island 5 coming soon)", 6.0))

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
	caption.text = "In the storm cellar, among boxed summer things, pinned under a kite reel with no kite:"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(0.4, 0.3, 0.18))
	vbox.add_child(caption)
	var fragment := Label.new()
	fragment.text = "“… meet you?”"
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

func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _sphere_mesh(radius: float, height: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = height
	return s

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[color] = m
	return _materials[color]

func _cyl(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c

func _add_mesh(mesh: Mesh, pos: Vector3, color: Color, with_collision := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
	if with_collision:
		# Convex, never trimesh: trimesh shells are hollow and trap the cat.
		mi.create_convex_collision()
	return mi
