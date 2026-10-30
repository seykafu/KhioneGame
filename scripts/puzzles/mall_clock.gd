extends Node3D
## Island 2, Riddle 1 — The Wrong-Way Stairs.
## Every escalator pushes against the player. A stuck clock stands above the
## fountain; batting its hands advances the hour. The directory by the doors
## notes the flower kiosk is "watered daily at 3 o'clock". Set the clock to
## 3:00 and the mall believes it: sprinklers run, the kiosk blooms, and the
## stairs run kindly ever after. The clock stays ownable for later riddles.

const CLOCK_POS := Vector3(5.2, 0.38, 0.0)
const KIOSK_POS := Vector3(-6.5, 0.38, 2.5)
const DIRECTORY_POS := Vector3(3.2, 0.38, 11.0)
const ESCALATORS := [
	[Vector3(15.0, 0.38, 4.5), Vector3(19.5, 4.4, 0.0)],
	[Vector3(-15.0, 0.38, -4.5), Vector3(-19.5, 4.4, 0.0)],
]
const PUSH_SPEED := 1.9
const START_HOUR := 7

const WOOD := Color(0.55, 0.42, 0.3)
const FACE_WHITE := Color(0.96, 0.95, 0.9)
const INK := Color(0.2, 0.16, 0.1)

var clock_hour := START_HOUR
var _escalators_up := false
var _bloomed := false
var _hand_pivot: Node3D
var _conveyors: Array = []  # [{area, up_dir, down_dir}]
var _kiosk_flowers: Array[Node3D] = []
var _sprinkler: CPUParticles3D
var _materials := {}
var _ui_layer: CanvasLayer
var _directory_panel: PanelContainer
var _opened_frame := -1

class ClockPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Bat at the clock hands"

	func interact(_player: Node) -> void:
		owner_puzzle.advance_clock()

class DirectoryPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Read the directory"

	func interact(_player: Node) -> void:
		owner_puzzle.open_directory()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_clock()
	_build_conveyors()
	_build_kiosk()
	_build_directory()
	_build_ui()

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for c: Dictionary in _conveyors:
		if (c.area as Area3D).overlaps_body(player):
			var dir: Vector3 = c.up_dir if _escalators_up else c.down_dir
			player.global_position += dir * PUSH_SPEED * delta

# --- the clock ---

func advance_clock() -> void:
	clock_hour = clock_hour % 12 + 1
	Sfx.play("coconut_thunk", 1.6, 0.05, -12.0)
	var t := create_tween()
	t.tween_property(_hand_pivot, "rotation:z", -TAU * clock_hour / 12.0, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	GameState.set_flag("clock_at_6", clock_hour == 6)
	if clock_hour == 3:
		GameState.set_flag("mall_time_3")
		_time_is_three()
	elif clock_hour == 6 and GameState.get_flag("skylight_open"):
		pass  # the finale speaks for this hour
	else:
		_flash("Clunk. The hands settle on %d o'clock. Nothing happens." % clock_hour, 2.5)

func _time_is_three() -> void:
	if _bloomed:
		_flash("3 o'clock. The kiosk drinks happily.", 2.5)
		return
	_bloomed = true
	Sfx.play("pickup_chime", 1.1, 0.0, -6.0)
	_flash("Somewhere, water is running. The mall believes it is 3 o'clock.", 4.5)
	_sprinkler.emitting = true
	for i in 3:
		var t := create_tween()
		t.tween_interval(0.5 + i * 0.7)
		t.tween_callback(Sfx.play.bind("splash", 1.3 + i * 0.15, 0.05, -14.0))
	for f: Node3D in _kiosk_flowers:
		var grow := f.create_tween()
		grow.tween_interval(randf_range(0.4, 1.2))
		grow.tween_property(f, "scale", f.scale * 1.8, 1.6) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_escalators_up = true
	var late := create_tween()
	late.tween_interval(3.5)
	late.tween_callback(_flash.bind("The stairs run kindly now. The clock is hers.", 4.0))
	var stop := create_tween()
	stop.tween_interval(7.0)
	stop.tween_callback(func() -> void: _sprinkler.emitting = false)

func _build_clock() -> void:
	var pole := MeshInstance3D.new()
	pole.mesh = _cyl(0.09, 0.11, 5.2)
	pole.material_override = _mat(Color(0.35, 0.37, 0.4))
	pole.position = CLOCK_POS + Vector3(0, 2.6, 0)
	add_child(pole)
	pole.create_convex_collision()

	var face := MeshInstance3D.new()
	face.mesh = _cyl(0.95, 0.95, 0.08)
	face.material_override = _mat(FACE_WHITE)
	face.position = CLOCK_POS + Vector3(0, 5.3, 0)
	face.rotation.x = PI / 2.0
	add_child(face)
	var rim := MeshInstance3D.new()
	rim.mesh = _cyl(1.02, 1.02, 0.06)
	rim.material_override = _mat(Color(0.35, 0.37, 0.4))
	rim.position = CLOCK_POS + Vector3(0, 5.3, -0.02)
	rim.rotation.x = PI / 2.0
	add_child(rim)
	for h in 12:
		var ang := TAU * h / 12.0
		var tick := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.05, 0.16, 0.03) if h % 3 == 0 else Vector3(0.035, 0.1, 0.03)
		tick.mesh = tb
		tick.material_override = _mat(INK)
		tick.position = CLOCK_POS + Vector3(sin(ang) * 0.78, 5.3 + cos(ang) * 0.78, 0.06)
		tick.rotation.z = -ang
		add_child(tick)
	# Fixed minute hand at 12, hour hand on a pivot.
	var minute := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(0.06, 0.8, 0.025)
	minute.mesh = mb
	minute.material_override = _mat(INK)
	minute.position = CLOCK_POS + Vector3(0, 5.3 + 0.36, 0.09)
	add_child(minute)
	_hand_pivot = Node3D.new()
	_hand_pivot.position = CLOCK_POS + Vector3(0, 5.3, 0.11)
	_hand_pivot.rotation.z = -TAU * clock_hour / 12.0
	add_child(_hand_pivot)
	var hand := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.09, 0.58, 0.03)
	hand.mesh = hb
	hand.material_override = _mat(Color(0.6, 0.2, 0.15))
	hand.position = Vector3(0, 0.26, 0)
	_hand_pivot.add_child(hand)

	var plate := ClockPlate.new()
	plate.owner_puzzle = self
	plate.position = CLOCK_POS + Vector3(0, 1.0, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

func _build_conveyors() -> void:
	for e: Array in ESCALATORS:
		var from: Vector3 = e[0]
		var to: Vector3 = e[1]
		var span := to - from
		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.4, 1.8, span.length())
		cs.shape = box
		area.add_child(cs)
		area.position = (from + to) / 2.0 + Vector3(0, 0.8, 0)
		area.rotation.y = atan2(span.x, span.z)
		area.rotation.x = -atan(span.y / Vector2(span.x, span.z).length())
		add_child(area)
		_conveyors.append({
			"area": area,
			"up_dir": span.normalized(),
			"down_dir": (-span).normalized(),
		})

func _build_kiosk() -> void:
	var cart := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(1.9, 0.9, 1.3)
	cart.mesh = cb
	cart.material_override = _mat(WOOD)
	cart.position = KIOSK_POS + Vector3(0, 0.45, 0)
	add_child(cart)
	cart.create_convex_collision()
	var flower_paths := [
		"res://assets/nature/flower_redA.glb",
		"res://assets/nature/flower_yellowA.glb",
		"res://assets/nature/flower_purpleA.glb",
	]
	for i in 3:
		var f: Node3D = load(flower_paths[i]).instantiate()
		f.position = KIOSK_POS + Vector3(-0.55 + i * 0.55, 0.92, 0)
		f.scale = Vector3.ONE * 1.3
		add_child(f)
		_kiosk_flowers.append(f)
	# Sprinkler arm over the cart.
	var arm := MeshInstance3D.new()
	arm.mesh = _cyl(0.05, 0.05, 2.6)
	arm.material_override = _mat(Color(0.35, 0.37, 0.4))
	arm.position = KIOSK_POS + Vector3(-1.1, 1.3, 0)
	add_child(arm)
	var head := MeshInstance3D.new()
	head.mesh = _cyl(0.12, 0.05, 0.12)
	head.material_override = _mat(Color(0.35, 0.37, 0.4))
	head.position = KIOSK_POS + Vector3(0, 2.62, 0)
	add_child(head)
	var horiz := MeshInstance3D.new()
	horiz.mesh = _cyl(0.04, 0.04, 1.15)
	horiz.material_override = _mat(Color(0.35, 0.37, 0.4))
	horiz.position = KIOSK_POS + Vector3(-0.55, 2.6, 0)
	horiz.rotation.z = PI / 2.0
	add_child(horiz)

	_sprinkler = CPUParticles3D.new()
	_sprinkler.emitting = false
	_sprinkler.amount = 90
	_sprinkler.lifetime = 0.9
	_sprinkler.position = KIOSK_POS + Vector3(0, 2.55, 0)
	_sprinkler.direction = Vector3(0, -1, 0)
	_sprinkler.spread = 28.0
	_sprinkler.initial_velocity_min = 1.6
	_sprinkler.initial_velocity_max = 2.6
	_sprinkler.gravity = Vector3(0, -6, 0)
	var drop := SphereMesh.new()
	drop.radius = 0.02
	drop.height = 0.05
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.7, 0.85, 0.95, 0.7)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dm
	_sprinkler.mesh = drop
	add_child(_sprinkler)

func _build_directory() -> void:
	var stand := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(1.4, 2.0, 0.14)
	stand.mesh = sb
	stand.material_override = _mat(Color(0.25, 0.4, 0.42))
	stand.position = DIRECTORY_POS + Vector3(0, 1.3, 0)
	add_child(stand)
	stand.create_convex_collision()
	var legs := MeshInstance3D.new()
	legs.mesh = _cyl(0.07, 0.09, 0.6)
	legs.material_override = _mat(Color(0.35, 0.37, 0.4))
	legs.position = DIRECTORY_POS + Vector3(0, 0.3, 0)
	add_child(legs)
	var plate := DirectoryPlate.new()
	plate.owner_puzzle = self
	plate.position = DIRECTORY_POS + Vector3(0, 1.0, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.2
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

# --- directory panel ---

func open_directory() -> void:
	_directory_panel.visible = true
	_opened_frame = Engine.get_process_frames()
	get_tree().paused = true
	Sfx.play("paper_open", 1.0, 0.05, -6.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent) -> void:
	if _directory_panel == null or not _directory_panel.visible:
		return
	if Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		_directory_panel.visible = false
		get_tree().paused = false
		Sfx.play("paper_close", 1.0, 0.05, -8.0)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 6
	add_child(_ui_layer)
	_directory_panel = PanelContainer.new()
	_directory_panel.add_theme_stylebox_override("panel",
			preload("res://scripts/ui/hud.gd").parchment_style())
	_directory_panel.visible = false
	_directory_panel.set_anchors_preset(Control.PRESET_CENTER)
	_directory_panel.offset_left = -290.0
	_directory_panel.offset_top = -210.0
	_directory_panel.offset_right = 290.0
	_directory_panel.offset_bottom = 210.0
	_ui_layer.add_child(_directory_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	_directory_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "EATON CENTRE  ·  DIRECTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.28, 0.2, 0.12))
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	for line: String in [
		"Pet Shop  ……  by appointment only",
		"Home Goods  ……  closed for inventory",
		"Flower Kiosk  ……  watered daily at 3 o'clock",
		"Food Court  ……  gone for lunch",
		"Glass Elevator  ……  out of service",
	]:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color", Color(0.35, 0.27, 0.16))
		vbox.add_child(lbl)
	vbox.add_child(HSeparator.new())
	var note := Label.new()
	note.text = "The clock above the fountain hasn't moved in years."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.5, 0.4, 0.28))
	vbox.add_child(note)
	var hint := Label.new()
	hint.text = "E closes"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(hint)

# --- helpers ---

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		_materials[color] = m
	return _materials[color]

func _cyl(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c
