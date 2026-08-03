extends Node3D
## Island 2, Riddle 4 — The Pigeon Parliament.
## Four pigeons have claimed a 4x4 patch of tiles on the west floor. Meows
## amuse them. A hiss scatters them one tile, always AWAY from Khione, like
## a sliding puzzle with feathers. Herd all four onto the corner vent tiles
## and their wingbeat spins the fans: across the atrium, a maintenance
## panel blasts off the elevator's flank, dropping the Elevator Fuse.

const GRID_ORIGIN := Vector3(-13.0, 0.38, -9.0)  # cell (0,0) world center
const CELL_STEP := 2.0
const GRID_N := 4
const VENTS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 3), Vector2i(3, 0), Vector2i(3, 3)]
const START_CELLS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]
const HISS_RADIUS := 6.5

const GREY := Color(0.55, 0.56, 0.6)
const VENT_DARK := Color(0.22, 0.23, 0.26)
const VENT_SLAT := Color(0.42, 0.44, 0.5)

var _pigeons: Array = []  # [{node, cell}]
var _fans: Array[Node3D] = []
var _solved := false
var _meow_teased := false
var _materials := {}

func _ready() -> void:
	_build_vents()
	_build_pigeons()
	GameState.vocal_used.connect(_on_vocal)

# --- construction ---

func _build_vents() -> void:
	for v in VENTS:
		var base := _add_box(Vector3(1.8, 0.06, 1.8), _cell_world(v) + Vector3(0, 0.03, 0), VENT_DARK)
		base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in 3:
			_add_box(Vector3(1.6, 0.03, 0.18),
					_cell_world(v) + Vector3(0, 0.07, -0.5 + i * 0.5), VENT_SLAT, false)
		var fan := Node3D.new()
		fan.position = _cell_world(v) + Vector3(0, 0.1, 0)
		for rot in [0.0, PI / 2.0]:
			var blade := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(1.1, 0.03, 0.12)
			blade.mesh = bb
			blade.material_override = _mat(VENT_SLAT.darkened(0.2))
			blade.rotation.y = rot
			fan.add_child(blade)
		add_child(fan)
		_fans.append(fan)

func _build_pigeons() -> void:
	for i in START_CELLS.size():
		var p := _make_pigeon()
		p.position = _cell_world(START_CELLS[i]) + Vector3(0, 0.12, 0)
		p.rotation.y = randf_range(0.0, TAU)
		add_child(p)
		_pigeons.append({"node": p, "cell": START_CELLS[i]})
		var bob := p.create_tween().set_loops()
		bob.tween_property(p, "rotation:x", 0.1, 0.4 + i * 0.07)
		bob.tween_property(p, "rotation:x", -0.05, 0.4 + i * 0.07)

func _make_pigeon() -> Node3D:
	var p := Node3D.new()
	var body := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.13
	bs.height = 0.2
	body.mesh = bs
	body.scale = Vector3(1.0, 1.0, 1.45)
	body.material_override = _mat(GREY)
	p.add_child(body)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.07
	hs.height = 0.13
	head.mesh = hs
	head.material_override = _mat(GREY.darkened(0.18))
	head.position = Vector3(0, 0.12, 0.12)
	p.add_child(head)
	var beak := MeshInstance3D.new()
	var bk := CylinderMesh.new()
	bk.top_radius = 0.0
	bk.bottom_radius = 0.022
	bk.height = 0.055
	beak.mesh = bk
	beak.material_override = _mat(Color(0.9, 0.65, 0.3))
	beak.rotation.x = PI / 2.0
	beak.position = Vector3(0, 0.12, 0.19)
	p.add_child(beak)
	return p

# --- herding ---

func _on_vocal(kind: String) -> void:
	if _solved:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if kind == "meow":
		if not _meow_teased and _near_grid(player.global_position):
			_meow_teased = true
			Sfx.play("gull", 0.5, 0.05, -12.0)
			_flash("The pigeons coo, deeply unimpressed by meows.", 3.5)
		return
	if kind != "hiss":
		return
	_hiss_from(player.global_position)

func _near_grid(pos: Vector3) -> bool:
	var center := GRID_ORIGIN + Vector3(3.0, 0, 3.0)
	return pos.distance_to(center) < 9.0

func _hiss_from(player_pos: Vector3) -> void:
	var any_moved := false
	for p: Dictionary in _pigeons:
		var node: Node3D = p.node
		if player_pos.distance_to(node.global_position) > HISS_RADIUS:
			continue
		var delta := node.global_position - player_pos
		var dx := 1 if delta.x >= 0.0 else -1
		var dz := 1 if delta.z >= 0.0 else -1
		var options: Array[Vector2i] = []
		if absf(delta.x) >= absf(delta.z):
			options = [Vector2i(dx, 0), Vector2i(0, dz)]
		else:
			options = [Vector2i(0, dz), Vector2i(dx, 0)]
		var done := false
		for step in options:
			var target: Vector2i = (p.cell as Vector2i) + step
			if _cell_free(target):
				p.cell = target
				_hop(p, step)
				done = true
				any_moved = true
				break
		if not done:
			_flutter(node)
	if any_moved:
		Sfx.play("gull", 0.55, 0.1, -14.0)
		_check_win()

func _cell_free(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= GRID_N or cell.y < 0 or cell.y >= GRID_N:
		return false
	for p: Dictionary in _pigeons:
		if p.cell == cell:
			return false
	return true

func _hop(p: Dictionary, step: Vector2i) -> void:
	var node: Node3D = p.node
	var target := _cell_world(p.cell) + Vector3(0, 0.12, 0)
	node.rotation.y = atan2(float(step.x), float(step.y))
	var mid := (node.position + target) / 2.0 + Vector3(0, 0.5, 0)
	var t := node.create_tween()
	t.tween_property(node, "position", mid, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", target, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var flap := node.create_tween()
	flap.tween_property(node, "scale:x", 0.6, 0.08)
	flap.tween_property(node, "scale:x", 1.0, 0.08)
	flap.tween_property(node, "scale:x", 0.6, 0.08)
	flap.tween_property(node, "scale:x", 1.0, 0.08)

func _flutter(node: Node3D) -> void:
	var t := node.create_tween()
	t.tween_property(node, "position:y", node.position.y + 0.25, 0.12)
	t.tween_property(node, "position:y", node.position.y, 0.12)

func _check_win() -> void:
	for p: Dictionary in _pigeons:
		if not VENTS.has(p.cell as Vector2i):
			return
	_solve()

func _solve() -> void:
	_solved = true
	GameState.set_flag("pigeon_parliament_solved")
	Sfx.play("robot_whir", 0.6, 0.0, -8.0)
	Sfx.play("jump_whoosh", 0.7, 0.0, -4.0)
	_flash("Four wingbeats over four vents. The fans below wake with a howl.", 4.0)
	for fan in _fans:
		var t := fan.create_tween()
		t.tween_property(fan, "rotation:y", fan.rotation.y + TAU * 7.0, 2.8) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The blast pops a maintenance panel off the elevator's flank.
	var late := create_tween()
	late.tween_interval(2.0)
	late.tween_callback(_pop_panel)

func _pop_panel() -> void:
	Sfx.play("coconut_thunk", 0.8, 0.0, -4.0)
	_flash("Across the atrium, a panel clatters off the elevator. Something glassy rolls free.", 4.5)
	var panel := _add_box(Vector3(0.08, 0.7, 0.7), Vector3(12.2, 1.1, -7.6), VENT_SLAT, false)
	var t := panel.create_tween().set_parallel(true)
	t.tween_property(panel, "position", panel.position + Vector3(-1.2, -0.7, 0.6), 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(panel, "rotation:z", 1.4, 0.7)
	_spawn_fuse(Vector3(10.8, 0.5, -7.0))

func _spawn_fuse(pos: Vector3) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/interaction/item_pickup.gd"))
	a.set("item_id", "elevator_fuse")
	a.set("display_name", "Elevator Fuse")
	a.position = pos
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.3
	cs.shape = sph
	a.add_child(cs)
	var glass := MeshInstance3D.new()
	var gc := CylinderMesh.new()
	gc.top_radius = 0.07
	gc.bottom_radius = 0.07
	gc.height = 0.3
	glass.mesh = gc
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.85, 0.75, 0.5, 0.8)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.2
	glass.material_override = gm
	glass.rotation.z = PI / 2.0
	glass.position = Vector3(0, 0.08, 0)
	a.add_child(glass)
	for side in [-1.0, 1.0]:
		var cap := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 0.075
		cc.bottom_radius = 0.075
		cc.height = 0.06
		cap.mesh = cc
		cap.material_override = _mat(Color(0.6, 0.6, 0.65))
		cap.rotation.z = PI / 2.0
		cap.position = Vector3(side * 0.17, 0.08, 0)
		a.add_child(cap)
	add_child(a)

# --- helpers ---

func _cell_world(cell: Vector2i) -> Vector3:
	return GRID_ORIGIN + Vector3(cell.x * CELL_STEP, 0, cell.y * CELL_STEP)

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)

func _add_box(size: Vector3, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
	if with_collision:
		mi.create_trimesh_collision()
	return mi

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_materials[color] = m
	return _materials[color]
