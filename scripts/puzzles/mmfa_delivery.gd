extends Node3D
## Island 5, Riddle 3 — The Fallen Star.
## The winning horn shakes a framed portrait of the Démon Blond (the
## last star called, number 10) out of the Bell Centre's rafters. Its
## plaque reads: Propriété du Musée des beaux-arts de Montréal, en prêt.
## On loan, and overdue. The museum's grand door says TIREZ, and cats
## cannot pull — but a certain dog can, given a rope and a reason. Hang
## the portrait on the empty easel and the museum lights up warm; the
## sculpture-garden squirrel returns the brass lever handle its cousins
## stole.

const MUSEUM_POS := Vector3(26.0, 0.35, 4.0)
const PORTRAIT_FALL_LOCAL := Vector3(2.0, 0.12, 1.5)   # on the arena ice

var _door: MeshInstance3D
var _door_open := false
var _easel_frame: Node3D
var _windows: Array[MeshInstance3D] = []

class DoorPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "The grand door (TIREZ)"

	func interact(_player: Node) -> void:
		owner_puzzle.door_interact()

class EaselPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "The empty easel"

	func interact(_player: Node) -> void:
		owner_puzzle.easel_interact()

func _ready() -> void:
	_build_museum()
	if GameState.get_flag("mmfa_delivered"):
		_open_door(true)
		_hang_portrait(true)
		_museum_glow()
	elif GameState.get_flag("three_stars_done") and not Inventory.has_item("lafleur_portrait"):
		# She left it on the ice (or reloaded): the portrait waits there.
		drop_portrait(false)

func _build_museum() -> void:
	var m := Node3D.new()
	m.name = "Museum"
	m.position = MUSEUM_POS
	add_child(m)
	# The hall: stone walls (piecewise, walk-in), west-facing portico.
	var stone := Color(0.85, 0.82, 0.76)
	_child_box(m, Vector3(0.4, 4.0, 7.0), Vector3(3.8, 2.0, 0), stone)          # east (back) wall
	_child_box(m, Vector3(7.0, 4.0, 0.4), Vector3(0, 2.0, 3.5), stone)          # north wall
	_child_box(m, Vector3(7.0, 4.0, 0.4), Vector3(0, 2.0, -3.5), stone)         # south wall
	_child_box(m, Vector3(0.4, 4.0, 2.3), Vector3(-3.4, 2.0, 2.35), stone)      # west wall, north of door
	_child_box(m, Vector3(0.4, 4.0, 2.3), Vector3(-3.4, 2.0, -2.35), stone)     # west wall, south of door
	_child_box(m, Vector3(0.4, 1.4, 2.5), Vector3(-3.4, 3.3, 0), stone)         # lintel
	_child_box(m, Vector3(7.6, 0.4, 7.6), Vector3(0, 4.2, 0), Color(0.55, 0.57, 0.6))  # roof slab
	var pediment := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(8.2, 1.6, 1.2)
	pediment.mesh = prism
	pediment.material_override = _mat(stone)
	pediment.position = Vector3(-3.6, 5.0, 0)
	pediment.rotation.y = PI / 2.0
	m.add_child(pediment)
	pediment.create_convex_collision()
	# Columns and steps down to the lawn.
	for cz: float in [-2.6, -0.9, 0.9, 2.6]:
		_child_mesh(m, _cyl(0.28, 0.32, 3.8), Vector3(-4.6, 1.9, cz), Color(0.92, 0.9, 0.85))
	for s in 3:
		_child_box(m, Vector3(1.0, 0.18, 7.0), Vector3(-5.2 - s * 0.9, 0.09 - s * 0.18, 0), Color(0.75, 0.73, 0.68))
	# Banner: MBAM.
	var banner := _child_box(m, Vector3(0.1, 2.2, 1.0), Vector3(-4.7, 2.6, 3.1), Color(0.2, 0.3, 0.55), false)
	var _k := banner
	var sign := Label3D.new()
	sign.text = "M\nB\nA\nM"
	sign.font_size = 30
	sign.pixel_size = 0.01
	sign.modulate = Color(0.95, 0.94, 0.9)
	sign.position = Vector3(-4.78, 2.6, 3.1)
	sign.rotation.y = -PI / 2.0
	m.add_child(sign)
	# The grand door: dark wood, a rope handle, and the fateful word.
	_door = _child_box(m, Vector3(0.16, 3.2, 2.4), Vector3(-3.42, 1.6, 0), Color(0.3, 0.22, 0.16))
	var word := Label3D.new()
	word.text = "TIREZ"
	word.font_size = 36
	word.pixel_size = 0.008
	word.modulate = Color(0.85, 0.8, 0.7)
	word.position = Vector3(-3.52, 2.4, 0)
	word.rotation.y = -PI / 2.0
	m.add_child(word)
	var rope := _child_mesh(m, _cyl(0.05, 0.07, 0.7), Vector3(-3.6, 1.4, -0.8), Color(0.7, 0.6, 0.4), false)
	var _k2 := rope
	var door_plate := DoorPlate.new()
	door_plate.owner_puzzle = self
	door_plate.position = Vector3(-4.2, 1.0, 0)
	_zone(door_plate, 2.2)
	m.add_child(door_plate)
	# Inside: the empty easel under its sign, and two loaned pieces.
	_easel_frame = Node3D.new()
	_easel_frame.name = "Easel"
	_easel_frame.position = Vector3(2.4, 0, 0)
	_easel_frame.rotation.y = -PI / 2.0 - 0.15
	m.add_child(_easel_frame)
	for s: float in [-0.4, 0.4]:
		var leg := _child_mesh(_easel_frame, _cyl(0.04, 0.05, 1.9), Vector3(s, 0.9, -0.12 * absf(s) * 2.5), Color(0.45, 0.34, 0.24), false)
		leg.rotation.x = 0.18
	var leg3 := _child_mesh(_easel_frame, _cyl(0.04, 0.05, 1.8), Vector3(0, 0.85, 0.3), Color(0.45, 0.34, 0.24), false)
	leg3.rotation.x = -0.35
	_child_box(_easel_frame, Vector3(1.1, 0.08, 0.12), Vector3(0, 0.85, -0.08), Color(0.45, 0.34, 0.24), false)
	var missing := Label3D.new()
	missing.name = "MissingSign"
	missing.text = "pièce manquante"
	missing.font_size = 24
	missing.pixel_size = 0.006
	missing.modulate = Color(0.5, 0.4, 0.3)
	missing.position = Vector3(0, 1.9, 0)
	_easel_frame.add_child(missing)
	var easel_plate := EaselPlate.new()
	easel_plate.owner_puzzle = self
	easel_plate.position = Vector3(0, 1.0, -0.6)
	_zone(easel_plate, 1.8)
	_easel_frame.add_child(easel_plate)
	for def: Array in [[Vector3(0.5, 2.0, 2.0), Color(0.75, 0.3, 0.3)], [Vector3(0.5, 2.0, -2.0), Color(0.3, 0.4, 0.65)]]:
		var art := _child_box(m, Vector3(0.06, 1.0, 0.8), (def[0] as Vector3) + Vector3(3.5, 0, 0), Color(0.8, 0.68, 0.3), false)
		var canvas := _child_box(m, Vector3(0.04, 0.84, 0.64), (def[0] as Vector3) + Vector3(3.46, 0, 0), def[1], false)
		var _k3 := [art, canvas]
	# Warm sconces, dark until the delivery.
	for wz: float in [-2.2, 2.2]:
		var glow := MeshInstance3D.new()
		glow.mesh = _cyl(0.12, 0.16, 0.3)
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.5, 0.44, 0.35)
		glow.material_override = gm
		glow.position = Vector3(3.6, 2.6, wz)
		m.add_child(glow)
		_windows.append(glow)
	# The sculpture-garden squirrel, waiting on the north steps.
	var squirrel := Node3D.new()
	squirrel.name = "GardenSquirrel"
	squirrel.position = Vector3(-5.4, 0.15, 1.6)
	m.add_child(squirrel)
	var sb := MeshInstance3D.new()
	var sbm := CapsuleMesh.new()
	sbm.radius = 0.09
	sbm.height = 0.34
	sb.mesh = sbm
	sb.material_override = _mat(Color(0.45, 0.42, 0.4))
	sb.position = Vector3(0, 0.17, 0)
	squirrel.add_child(sb)
	var st := MeshInstance3D.new()
	var stm := CapsuleMesh.new()
	stm.radius = 0.06
	stm.height = 0.36
	st.mesh = stm
	st.material_override = _mat(Color(0.5, 0.46, 0.44))
	st.position = Vector3(0, 0.3, -0.16)
	st.rotation.x = -0.6
	squirrel.add_child(st)

## The portrait leaves the rafters: animated on the win, quietly on a
## revisit where it was never picked up.
func drop_portrait(animated: bool) -> void:
	var island := get_parent()
	var target: Vector3 = (island.arena as Node3D).to_global(PORTRAIT_FALL_LOCAL)
	var a := Area3D.new()
	a.set_script(load("res://scripts/interaction/item_pickup.gd"))
	a.set("item_id", "lafleur_portrait")
	a.set("display_name", "Portrait of the Démon Blond")
	# Position via local coords (the puzzle sits at the island origin);
	# global transforms are only valid once the node is in the tree.
	a.position = target + (Vector3(0, 4.8, 0) if animated else Vector3.ZERO)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.4
	cs.shape = sph
	a.add_child(cs)
	a.add_to_group("pickup_lafleur_portrait")
	# The piece itself: gilded frame, jersey-red canvas, the number 10.
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(1.0, 0.08, 1.3)
	frame.mesh = fb
	frame.material_override = _mat(Color(0.8, 0.68, 0.3))
	frame.position = Vector3(0, 0.06, 0)
	a.add_child(frame)
	var canvas := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.84, 0.06, 1.14)
	canvas.mesh = cb
	canvas.material_override = _mat(Color(0.72, 0.16, 0.2))
	canvas.position = Vector3(0, 0.1, 0)
	a.add_child(canvas)
	var num := Label3D.new()
	num.text = "10"
	num.font_size = 72
	num.pixel_size = 0.008
	num.modulate = Color(0.95, 0.94, 0.9)
	num.position = Vector3(0, 0.15, 0)
	num.rotation.x = -PI / 2.0
	a.add_child(num)
	add_child(a)
	if animated:
		var t := create_tween()
		t.tween_property(a, "position", target, 0.9) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void:
			Sfx.play("coconut_thunk", 0.7, 0.0, -6.0)
			Sfx.play("crowd_groan", 1.2, 0.0, -14.0)
			_flash("Something shakes loose from the rafters and lands FLAT on the ice: a framed portrait, number 10. The plaque: Propriété du Musée des beaux-arts, en prêt.", 6.5))

func door_interact() -> void:
	if _door_open:
		_flash("The grand door stands open, very pleased with itself.", 2.5)
		return
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	if oreo == null or oreo.global_position.distance_to(_door.global_position) > 12.0:
		_flash("TIREZ: pull. She pushes anyway. Nothing. Cats push; this door wants the other thing, and a mouth that can grip a rope.", 4.5)
		return
	_open_door(false)
	Sfx.play("bark", 1.0, 0.03, -8.0)
	Sfx.play("wood_creak", 0.8, 0.0, -8.0)
	if oreo.has_method("hop"):
		oreo.hop()
	_flash("Oreo takes the rope handle and LEANS. The grand door swings wide, as doors do for those who can pull.", 4.5)

func _open_door(instant: bool) -> void:
	_door_open = true
	for c in _door.get_children():
		if c is StaticBody3D:
			for cc in c.get_children():
				if cc is CollisionShape3D:
					(cc as CollisionShape3D).disabled = true
	if instant:
		_door.rotation.y = 1.8
		_door.position += Vector3(0.1, 0, 1.1)
	else:
		var t := create_tween()
		t.tween_property(_door, "rotation:y", 1.8, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(_door, "position", _door.position + Vector3(0.1, 0, 1.1), 0.8)

func easel_interact() -> void:
	if GameState.get_flag("mmfa_delivered"):
		_flash("The Démon Blond hangs where he belongs, lit warm. The easel sign is gone; nothing is missing anymore.", 4.0)
		return
	if not Inventory.has_item("lafleur_portrait"):
		_flash("An empty easel under a small sign: pièce manquante. Something is missing, and the museum knows exactly what.", 4.0)
		return
	Inventory.remove_item("lafleur_portrait")
	GameState.set_flag("mmfa_delivered")
	_hang_portrait(false)
	_museum_glow()
	Sfx.play("pickup_chime", 1.2, 0.0, -8.0)
	Sfx.play("crowd_cheer", 0.8, 0.0, -16.0)
	var island := get_parent()
	if island.has_method("_add_pickup"):
		island._add_pickup(MUSEUM_POS + Vector3(-5.6, 0.0, 0.6), "lever_handle",
				"Brass Lever Handle", Color(0.85, 0.7, 0.3))
	Sfx.play("squirrel_chitter", 1.0, 0.0, -10.0)
	_flash("The portrait settles onto the easel and the whole museum lights up warm. On the steps, the sculpture-garden squirrel sets down something brass, with ceremony.", 6.0)

func _hang_portrait(instant: bool) -> void:
	var sign := _easel_frame.get_node_or_null("MissingSign")
	if sign:
		sign.queue_free()
	var frame := _child_box(_easel_frame, Vector3(1.0, 1.3, 0.08), Vector3(0, 1.25, -0.14), Color(0.8, 0.68, 0.3), false)
	frame.rotation.x = 0.18
	var canvas := _child_box(_easel_frame, Vector3(0.84, 1.14, 0.06), Vector3(0, 1.25, -0.16), Color(0.72, 0.16, 0.2), false)
	canvas.rotation.x = 0.18
	var num := Label3D.new()
	num.text = "10"
	num.font_size = 72
	num.pixel_size = 0.008
	num.modulate = Color(0.95, 0.94, 0.9)
	num.position = Vector3(0, 1.25, -0.21)
	num.rotation.x = 0.18
	_easel_frame.add_child(num)
	if not instant:
		frame.scale = Vector3(0.1, 0.1, 0.1)
		canvas.scale = Vector3(0.1, 0.1, 0.1)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(frame, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(canvas, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _museum_glow() -> void:
	for glow in _windows:
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(1.0, 0.85, 0.55)
		gm.emission_enabled = true
		gm.emission = Color(1.0, 0.82, 0.5)
		gm.emission_energy_multiplier = 1.4
		glow.material_override = gm

# --- helpers ---

func _zone(area: Area3D, radius: float) -> void:
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	cs.shape = sph
	area.add_child(cs)

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m

func _cyl(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c

func _child_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	if with_collision:
		mi.create_convex_collision()
	return mi

func _child_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _child_mesh(parent, box, pos, color, with_collision)

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)
