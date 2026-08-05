extends Node3D
## Island 3, Riddle 1 — The Paper Regatta.
## Paper boats lie becalmed on the lagoon. Fold one and launch it while the
## breeze blows (the cottonwood fluff gives one beat of warning) and it
## sails west for the passage under the Peace Bridge — but the little weir
## across the narrows must be open, or the boat jams in the reeds. A clean
## run under the bridge flushes the west-rim nook: a small brass clapper,
## carried back soggy.

const PLANK_POS := Vector3(-6.2, 0.3, 3.6)
const LEVER_POS := Vector3(-10.0, 0.35, 5.2)
const WEIR_POS := Vector3(-11.0, 0.1, 1.4)
const CLAPPER_POS := Vector3(-16.0, 0.28, -1.6)
const ROUTE: Array[Vector3] = [
	Vector3(-7.4, -0.06, 2.6), Vector3(-9.0, -0.06, 1.0),
	Vector3(-11.0, -0.06, -0.2), Vector3(-13.4, -0.06, -1.0),
	Vector3(-15.2, -0.06, -1.4),
]

var _sluice_open := false
var _weir_board: MeshInstance3D
var _sailing := false
var _materials := {}

class FoldPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Fold a paper boat"

	func interact(_player: Node) -> void:
		owner_puzzle.launch_boat()

class SluiceLever:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "The little weir's lever"

	func interact(_player: Node) -> void:
		owner_puzzle.toggle_sluice()

func _ready() -> void:
	_build_plank()
	_build_weir()
	_scatter_becalmed_boats()

func _build_plank() -> void:
	var plank := _box(Vector3(1.6, 0.1, 0.9), PLANK_POS, Color(0.6, 0.5, 0.4))
	plank.create_trimesh_collision()
	# A stack of waiting paper, and the kids' chalk clue: fluff, arrow, gate.
	_box(Vector3(0.4, 0.12, 0.5), PLANK_POS + Vector3(-0.4, 0.12, 0.1), Color(0.95, 0.95, 0.92))
	_box(Vector3(0.1, 0.02, 0.1), PLANK_POS + Vector3(0.3, 0.07, -0.2), Color(0.98, 0.98, 0.96))
	for i in 3:  # chalk fluff puffs
		_box(Vector3(0.07, 0.015, 0.07), PLANK_POS + Vector3(-0.1 + i * 0.14, 0.065, 0.32),
				Color(0.95, 0.95, 0.98))
	_box(Vector3(0.3, 0.015, 0.05), PLANK_POS + Vector3(0.45, 0.065, 0.32), Color(0.95, 0.95, 0.98))
	_box(Vector3(0.06, 0.015, 0.12), PLANK_POS + Vector3(0.62, 0.065, 0.32), Color(0.95, 0.95, 0.98))
	var plate := FoldPlate.new()
	plate.owner_puzzle = self
	plate.position = PLANK_POS + Vector3(0, 0.4, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.8
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

func _build_weir() -> void:
	# Two posts in the narrows and a board between them that lifts.
	for s in [-1.0, 1.0]:
		var post := _box(Vector3(0.1, 0.8, 0.1), WEIR_POS + Vector3(s * 0.9, 0.3, 0), Color(0.45, 0.38, 0.3))
		post.create_trimesh_collision()
	_weir_board = _box(Vector3(1.7, 0.45, 0.08), WEIR_POS + Vector3(0, 0.12, 0), Color(0.55, 0.46, 0.36))
	# The lever on the shore.
	var base := _box(Vector3(0.3, 0.5, 0.3), LEVER_POS + Vector3(0, 0.25, 0), Color(0.45, 0.38, 0.3))
	base.create_trimesh_collision()
	var arm := _box(Vector3(0.07, 0.7, 0.07), LEVER_POS + Vector3(0.1, 0.75, 0), Color(0.7, 0.3, 0.25))
	arm.rotation.z = -0.5
	arm.name = "LeverArm"
	var plate := SluiceLever.new()
	plate.owner_puzzle = self
	plate.position = LEVER_POS + Vector3(0, 0.8, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.7
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

func _scatter_becalmed_boats() -> void:
	for pos: Vector3 in [Vector3(-8.5, -0.06, -3.2), Vector3(-13.5, -0.06, 2.0), Vector3(-11.8, -0.06, -4.0)]:
		var boat := _paper_boat()
		boat.position = pos
		boat.rotation.y = randf_range(0.0, TAU)
		add_child(boat)
		var bob := boat.create_tween().set_loops()
		bob.tween_property(boat, "position:y", pos.y + 0.03, randf_range(1.6, 2.4)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(boat, "position:y", pos.y - 0.01, randf_range(1.6, 2.4)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _paper_boat() -> Node3D:
	var boat := Node3D.new()
	var hull := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.34, 0.14, 0.2)
	hull.mesh = prism
	hull.material_override = _mat(Color(0.97, 0.96, 0.92))
	hull.rotation.x = PI  # upturned hull, paper-boat style
	hull.position.y = 0.1
	boat.add_child(hull)
	var sail := MeshInstance3D.new()
	var sp := PrismMesh.new()
	sp.size = Vector3(0.16, 0.16, 0.02)
	sail.mesh = sp
	sail.material_override = _mat(Color(0.97, 0.96, 0.92))
	sail.position.y = 0.2
	boat.add_child(sail)
	return boat

func toggle_sluice() -> void:
	_sluice_open = not _sluice_open
	Sfx.play("wood_creak", 1.1, 0.05, -10.0)
	var t := create_tween()
	t.tween_property(_weir_board, "position:y",
			WEIR_POS.y + (0.55 if _sluice_open else 0.12), 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var arm := get_node_or_null("LeverArm")
	if arm:
		var t2 := create_tween()
		t2.tween_property(arm, "rotation:z", 0.5 if _sluice_open else -0.5, 0.5)
	_flash("The weir board %s." % ("lifts clear of the water" if _sluice_open else "drops back into the narrows"), 2.5)

func launch_boat() -> void:
	if GameState.get_flag("regatta_done"):
		_flash("The regatta is won. The lagoon keeps the paper fleet as a monument.", 3.0)
		return
	if _sailing:
		_flash("Her boat is still out there, doing its best.", 2.5)
		return
	var breeze: Node = get_tree().get_first_node_in_group("bow_breeze")
	var boat := _paper_boat()
	boat.position = ROUTE[0]
	add_child(boat)
	Sfx.play("paper_open", 1.2, 0.05, -10.0)
	if breeze == null or not breeze.is_gusting():
		# Becalmed: the boat bobs, drifts nowhere, and gives up politely.
		var t := create_tween()
		t.tween_property(boat, "position", ROUTE[0] + Vector3(0.3, 0, 0.2), 2.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(boat, "position", ROUTE[0], 2.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_callback(boat.queue_free)
		_flash("The boat bobs and goes nowhere. The fluff hangs dead still in the air.", 3.5)
		return
	_sailing = true
	if not _sluice_open:
		# It sails, and jams at the closed weir.
		var t := create_tween()
		t.tween_property(boat, "position", ROUTE[1], 2.0).set_trans(Tween.TRANS_SINE)
		t.tween_property(boat, "position", WEIR_POS + Vector3(0.5, -0.16, 0.4), 1.6) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(boat, "rotation:y", 1.4, 1.0)
		t.tween_callback(func() -> void:
			_sailing = false
			boat.queue_free()
			_flash("The boat rides the breeze… straight into the weir board, and sulks in the reeds.", 3.5))
		return
	# The clean run: under the bridge and into the west nook.
	var t := create_tween()
	for wp in ROUTE.slice(1):
		t.tween_property(boat, "position", wp, 1.5).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void:
		_sailing = false
		boat.queue_free()
		GameState.set_flag("regatta_done")
		Sfx.play("pickup_chime", 1.1, 0.0, -8.0)
		_spawn_clapper()
		_flash("Under the red bridge and gone! The west reeds stir… something small and brass washes loose.", 4.5))

func _spawn_clapper() -> void:
	var island := get_parent()
	if island and island.has_method("_add_pickup"):
		island._add_pickup(CLAPPER_POS, "brass_clapper", "Brass Clapper", Color(0.78, 0.62, 0.26))

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
