extends Node3D
## Beat 1 — The Three Hollow Stones (Echo Cove, east beach).
## Three hollow stones hum at different pitches. A stone carving nearby shows
## three spirals, small to large. Meow at the stones in that order
## (small stone = highest pitch, first) to drain the tide pool and reveal
## what the sea buried. Wrong order resets gently. Wordless by design.

const STONE_DEFS := [
	{"size": 0.8, "hum": "res://assets/audio/hum_high.wav", "offset": Vector3(-3.2, 0, 0.4)},
	{"size": 1.25, "hum": "res://assets/audio/hum_mid.wav", "offset": Vector3(0.2, 0, -2.6)},
	{"size": 1.7, "hum": "res://assets/audio/hum_low.wav", "offset": Vector3(3.4, 0, 0.2)},
]
const STONE_TINT := Color(0.6, 0.66, 0.78)
const MEOW_RANGE := 4.0
const POOL_POS := Vector3(0.4, 0, 4.6)

var stones: Array[Node3D] = []
var _hum_players: Array[AudioStreamPlayer3D] = []
var _answer_players: Array[AudioStreamPlayer3D] = []
var _player_near: Array[bool] = [false, false, false]
var _progress := 0
var _solved := false
var _hinted := false

var _pool_water: MeshInstance3D
var _sfx: AudioStreamPlayer
var _ui_layer: CanvasLayer
var _carving_panel: PanelContainer
var _opened_frame := -1

class CarvingPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Study the carving"

	func interact(_player: Node) -> void:
		owner_puzzle.open_carving()

class SpiralArt:
	extends Control

	func _draw() -> void:
		var sizes := [0.55, 0.8, 1.1]
		var xs := [120.0, 320.0, 540.0]
		for i in 3:
			_spiral(Vector2(xs[i], 175.0), sizes[i])

	func _spiral(c: Vector2, s: float) -> void:
		var pts := PackedVector2Array()
		var steps := 120
		for k in steps + 1:
			var t := float(k) / steps
			var ang := t * 3.0 * TAU
			var r := (6.0 + 62.0 * t) * s
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
		draw_polyline(pts, Color(0.92, 0.88, 0.78), 3.5, true)

func _ready() -> void:
	# ALWAYS so the carving panel can un-pause itself; gameplay reactions
	# guard on get_tree().paused instead.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_build_stones()
	_build_carving()
	_build_pool()
	_build_hint_area()
	_build_ui()
	GameState.vocal_used.connect(_on_vocal)

# --- world building ---

func _build_stones() -> void:
	var rock_scene: PackedScene = load("res://assets/nature/rock_tallB.glb")
	for i in STONE_DEFS.size():
		var def: Dictionary = STONE_DEFS[i]
		var stone: Node3D = rock_scene.instantiate()
		stone.position = def.offset
		stone.scale = Vector3.ONE * (def.size as float)
		stone.rotation.y = i * 2.1
		add_child(stone)
		var mi := _first_mesh_instance(stone)
		if mi:
			mi.create_trimesh_collision()
			var mat := StandardMaterial3D.new()
			mat.albedo_color = STONE_TINT.darkened(i * 0.07)
			mat.roughness = 1.0
			mi.material_override = mat
		stones.append(stone)

		var audio_pos: Vector3 = def.offset + Vector3(0, 0.6 * (def.size as float), 0)
		var hum := AudioStreamPlayer3D.new()
		var loop_stream: AudioStreamWAV = load(def.hum).duplicate()
		loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop_stream.loop_begin = 0
		loop_stream.loop_end = loop_stream.data.size() / 2
		hum.stream = loop_stream
		hum.volume_db = -9.0
		hum.max_distance = 30.0
		hum.position = audio_pos
		add_child(hum)
		hum.play()
		_hum_players.append(hum)

		var ans := AudioStreamPlayer3D.new()
		ans.stream = load(def.hum)
		ans.volume_db = 5.0
		ans.max_distance = 60.0
		ans.position = audio_pos
		add_child(ans)
		_answer_players.append(ans)

		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = MEOW_RANGE
		cs.shape = sph
		area.add_child(cs)
		area.position = def.offset
		area.body_entered.connect(_on_stone_area.bind(i, true))
		area.body_exited.connect(_on_stone_area.bind(i, false))
		add_child(area)

func _build_carving() -> void:
	# A flat rock stood upright at the cove mouth, spirals etched into it.
	var slab: Node3D = load("res://assets/nature/rock_largeA.glb").instantiate()
	slab.position = Vector3(-0.6, 0.0, -5.6)
	slab.rotation = Vector3(PI / 2.2, 0.4, 0)
	slab.scale = Vector3(2.4, 2.4, 2.4)
	add_child(slab)
	var mi := _first_mesh_instance(slab)
	if mi:
		mi.create_trimesh_collision()

	var plate := CarvingPlate.new()
	plate.owner_puzzle = self
	plate.position = slab.position
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

func _build_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var rocks := [
		"res://assets/nature/rock_smallA.glb",
		"res://assets/nature/rock_smallB.glb",
		"res://assets/nature/rock_smallC.glb",
	]
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf_range(-0.2, 0.2)
		var rock: Node3D = load(rocks[i % rocks.size()]).instantiate()
		rock.position = POOL_POS + Vector3(cos(a) * 1.7, 0, sin(a) * 1.7)
		rock.rotation.y = rng.randf_range(0.0, TAU)
		rock.scale = Vector3.ONE * rng.randf_range(1.1, 1.6)
		add_child(rock)

	var disc := CylinderMesh.new()
	disc.top_radius = 1.5
	disc.bottom_radius = 1.5
	disc.height = 0.12
	_pool_water = MeshInstance3D.new()
	_pool_water.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.45, 0.6, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	_pool_water.material_override = mat
	_pool_water.position = POOL_POS + Vector3(0, 0.08, 0)
	add_child(_pool_water)

func _build_hint_area() -> void:
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 10.0
	cs.shape = sph
	area.add_child(cs)
	area.body_entered.connect(_on_hint_area)
	add_child(area)

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 6
	add_child(_ui_layer)
	_carving_panel = PanelContainer.new()
	_carving_panel.visible = false
	_carving_panel.set_anchors_preset(Control.PRESET_CENTER)
	_carving_panel.offset_left = -350.0
	_carving_panel.offset_top = -220.0
	_carving_panel.offset_right = 350.0
	_carving_panel.offset_bottom = 220.0
	_ui_layer.add_child(_carving_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	_carving_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	var art := SpiralArt.new()
	art.custom_minimum_size = Vector2(660, 340)
	vbox.add_child(art)
	var hint := Label.new()
	hint.text = "— E —"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(hint)

# --- carving panel ---

func open_carving() -> void:
	_carving_panel.visible = true
	_opened_frame = Engine.get_process_frames()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent) -> void:
	if _carving_panel == null or not _carving_panel.visible:
		return
	if Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		_carving_panel.visible = false
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()

# --- puzzle logic ---

func _on_stone_area(body: Node3D, idx: int, entering: bool) -> void:
	if body.is_in_group("player"):
		_player_near[idx] = entering

func _on_hint_area(body: Node3D) -> void:
	if _hinted or _solved or not body.is_in_group("player"):
		return
	_hinted = true
	_hud().flash_message("The stones are humming…  (M — meow)", 4.0)

func _on_vocal(kind: String) -> void:
	if kind != "meow" or _solved or get_tree().paused:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var idx := -1
	var best := INF
	for i in stones.size():
		if not _player_near[i]:
			continue
		var d := player.global_position.distance_to(stones[i].global_position)
		if d < best:
			best = d
			idx = i
	if idx == -1:
		return
	_answer_players[idx].play()
	_pulse(stones[idx])
	if idx == _progress:
		_progress += 1
		if _progress >= stones.size():
			_solve()
	else:
		_progress = 0
		_fail()

func _pulse(s: Node3D) -> void:
	var base := s.scale
	var t := create_tween()
	t.tween_property(s, "scale", base * 1.09, 0.12)
	t.tween_property(s, "scale", base, 0.25)

func _fail() -> void:
	_sfx.stream = load("res://assets/audio/fail.wav")
	_sfx.play()
	for s in stones:
		var orig := s.position
		var t := create_tween()
		t.tween_property(s, "position", orig + Vector3(0.06, 0, 0), 0.05)
		t.tween_property(s, "position", orig - Vector3(0.06, 0, 0), 0.08)
		t.tween_property(s, "position", orig, 0.05)
	_hud().flash_message("The stones fall silent…", 2.0)

func _solve() -> void:
	_solved = true
	GameState.set_flag("echo_stones_solved")
	_sfx.stream = load("res://assets/audio/success.wav")
	_sfx.play()
	for p in _hum_players:
		var t := create_tween()
		t.tween_property(p, "volume_db", -40.0, 2.0)
	var t2 := create_tween()
	t2.tween_property(_pool_water, "position:y", _pool_water.position.y - 0.55, 2.2)
	t2.parallel().tween_property(_pool_water, "transparency", 1.0, 2.2)
	t2.tween_callback(_reveal_cache)
	_hud().flash_message("Nearby, the tide pool drains with a groan…", 4.0)
	await get_tree().create_timer(0.9).timeout
	_sfx.stream = load("res://assets/audio/drain.wav")
	_sfx.play()

func _reveal_cache() -> void:
	_add_pickup(POOL_POS + Vector3(-0.5, 0.02, 0.2), "rusty_locket", "Rusty Locket", Color(0.55, 0.45, 0.3))
	_add_pickup(POOL_POS + Vector3(0.6, 0.02, -0.3), "stranded_fish", "Stranded Fish", Color(0.7, 0.8, 0.9))

# --- helpers ---

func _hud() -> Node:
	return get_node("../../HUD")

func _first_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _first_mesh_instance(c)
		if r:
			return r
	return null

func _add_pickup(pos: Vector3, id: String, disp: String, color: Color) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/interaction/item_pickup.gd"))
	a.set("item_id", id)
	a.set("display_name", disp)
	a.position = pos
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.2
	cs.shape = sph
	a.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mi.material_override = mat
	mi.position = Vector3(0, 0.2, 0)
	a.add_child(mi)
	add_child(a)
