extends Node3D
## Island 3, Riddle 3 — The Gopher Semaphore.
## A crayon map under the picnic table numbers six burrows. Meow beside
## them in the map's order (Whisker Sense is the pulse) and the whole
## town surfaces to look at her — and the eldest pushes up a tennis ball,
## chewed soft, one blue thread snagged in the felt.

const TABLE_POS := Vector3(13.0, 0.35, 6.5)
const PULSE_RANGE := 2.2

var _order: Array[int] = []       # mound indices, in map order
var _progress := 0
var _mounds: Array[Vector3] = []
var _map_ui: CanvasLayer
var _materials := {}

class MapPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Peek under the picnic table"

	func interact(_player: Node) -> void:
		owner_puzzle.show_map()

func _ready() -> void:
	var island := get_parent()
	_mounds = island.get("_gopher_mounds")
	# Map order: a fixed shuffle that stays honest between sessions.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8181
	var idx := range(_mounds.size())
	for i in idx.size():
		var j := rng.randi_range(0, idx.size() - 1)
		var tmp: int = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	for i in idx:
		_order.append(i)
	# The crayon map, taped under the table.
	var paper := _box(Vector3(0.5, 0.02, 0.36), TABLE_POS + Vector3(0.2, 0.68, 0.1), Color(0.96, 0.93, 0.85))
	paper.rotation.z = 0.06
	var plate := MapPlate.new()
	plate.owner_puzzle = self
	plate.position = TABLE_POS + Vector3(0, 0.5, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.9
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)
	GameState.vocal_used.connect(_on_vocal)

func show_map() -> void:
	GameState.set_flag("gopher_map_seen")
	if _map_ui:
		_map_ui.queue_free()
	_map_ui = CanvasLayer.new()
	_map_ui.layer = 6
	add_child(_map_ui)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
			preload("res://scripts/ui/hud.gd").parchment_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -190.0
	panel.offset_top = -170.0
	panel.offset_right = 190.0
	panel.offset_bottom = 170.0
	_map_ui.add_child(panel)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(360, 300)
	panel.add_child(holder)
	var caption := Label.new()
	caption.text = "gofer town — secret nock order!!"
	caption.position = Vector2(40, 14)
	caption.add_theme_font_size_override("font_size", 17)
	caption.add_theme_color_override("font_color", Color(0.7, 0.3, 0.25))
	holder.add_child(caption)
	# The mound field, drawn to scale in crayon.
	var min_x := 999.0
	var max_x := -999.0
	var min_z := 999.0
	var max_z := -999.0
	for m in _mounds:
		min_x = minf(min_x, m.x)
		max_x = maxf(max_x, m.x)
		min_z = minf(min_z, m.z)
		max_z = maxf(max_z, m.z)
	for rank in _order.size():
		var m := _mounds[_order[rank]]
		var px := 50.0 + 260.0 * (m.x - min_x) / maxf(max_x - min_x, 0.01)
		var py := 60.0 + 200.0 * (m.z - min_z) / maxf(max_z - min_z, 0.01)
		var dot := ColorRect.new()
		dot.color = Color(0.55, 0.42, 0.28)
		dot.position = Vector2(px - 7, py - 7)
		dot.size = Vector2(14, 14)
		holder.add_child(dot)
		var num := Label.new()
		num.text = str(rank + 1)
		num.position = Vector2(px + 6, py - 16)
		num.add_theme_font_size_override("font_size", 20)
		num.add_theme_color_override("font_color", Color(0.25, 0.35, 0.6))
		holder.add_child(num)
	var hint := Label.new()
	hint.text = "(the paper smells of grass and crayons — E to fold it back)"
	hint.position = Vector2(28, 268)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.42, 0.3))
	holder.add_child(hint)
	var close := func(event: InputEvent) -> void:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			if _map_ui:
				_map_ui.queue_free()
				_map_ui = null
	panel.gui_input.connect(close)
	# Also close from anywhere (the panel may never grab focus).
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	_map_ui.add_child(timer)
	timer.timeout.connect(func() -> void:
		if _map_ui and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_cancel")):
			_map_ui.queue_free()
			_map_ui = null)

func _on_vocal(kind: String) -> void:
	if kind != "meow" or GameState.get_flag("gopher_semaphore_done"):
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	# Which mound did she pulse, if any?
	var nearest := -1
	var nearest_d := PULSE_RANGE
	for i in _mounds.size():
		var d := Vector2(player.global_position.x - _mounds[i].x,
				player.global_position.z - _mounds[i].z).length()
		if d < nearest_d:
			nearest_d = d
			nearest = i
	if nearest == -1:
		return
	if nearest == _order[_progress]:
		_progress += 1
		Sfx.play("pickup_chime", 0.8 + 0.12 * _progress, 0.0, -14.0)
		_gopher_peek(_mounds[nearest], true)
		if _progress >= _order.size():
			_semaphore_won()
	else:
		if _progress > 0:
			_flash("A gopher pops up, chirps something extremely rude, and the order is lost.", 3.0)
		_gopher_peek(_mounds[nearest], false)
		_progress = 0
		if nearest == _order[0]:
			# A wrong pulse that happens to be the first mound still counts.
			_progress = 1
			_gopher_peek(_mounds[nearest], true)

func _gopher_peek(mound: Vector3, happy: bool) -> void:
	var gopher := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.09
	cap.height = 0.34
	gopher.mesh = cap
	gopher.material_override = _mat(Color(0.55, 0.42, 0.28) if happy else Color(0.5, 0.36, 0.24))
	gopher.position = mound + Vector3(0, -0.12, 0)
	add_child(gopher)
	var t := gopher.create_tween()
	t.tween_property(gopher, "position:y", mound.y + 0.24, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.5 if happy else 1.0)
	t.tween_property(gopher, "position:y", mound.y - 0.14, 0.18)
	t.tween_callback(gopher.queue_free)

func _semaphore_won() -> void:
	GameState.set_flag("gopher_semaphore_done")
	# The whole town surfaces at once to stare at the strange pale gopher.
	for m in _mounds:
		_gopher_peek(m, true)
	Sfx.play("crab_snip", 0.8, 0.1, -14.0)
	var eldest := _mounds[_order[_order.size() - 1]]
	var island := get_parent()
	if island and island.has_method("_add_pickup"):
		island._add_pickup(eldest + Vector3(0.5, 0, 0.3), "tennis_ball",
				"Chewed Tennis Ball", Color(0.8, 0.9, 0.3))
	_flash("Fifty gophers surface at once and stare. The eldest pushes up a tennis ball, chewed soft, one blue thread in the felt.", 5.5)

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
