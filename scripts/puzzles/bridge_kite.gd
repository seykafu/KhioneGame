extends Node3D
## Island 3, Riddle 4 — The Bridge and the Kite.
## A kite is snagged at the top of the Peace Bridge arch, thrashing in
## every gust. Grab it only in the lull, when the fluff hangs still. Its
## string runs down into the lagoon shallows, tied to a cream jug some
## picnicker left cooling in the glacier water.

const KITE_POS := Vector3(-11.0, 3.1, -1.0)
const JUG_POS := Vector3(-12.2, 0.05, 3.9)

var _kite: Node3D
var _string: MeshInstance3D
var _materials := {}

class KitePlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Grab for the kite"

	func interact(_player: Node) -> void:
		owner_puzzle.grab_kite()

func _ready() -> void:
	_build_kite()
	_build_string()
	var plate := KitePlate.new()
	plate.owner_puzzle = self
	plate.position = KITE_POS + Vector3(0, -0.8, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.2
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

func _build_kite() -> void:
	_kite = Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.5, 0.2)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for def: Array in [[Vector2(0.5, 0.34), 0.0], [Vector2(0.34, 0.5), 0.0]]:
		var quad := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = def[0]
		quad.mesh = q
		quad.material_override = mat
		_kite.add_child(quad)
	# A rag tail.
	for i in 3:
		var bow := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.12, 0.03, 0.02)
		bow.mesh = bb
		bow.material_override = _mat([Color(0.9, 0.8, 0.3), Color(0.4, 0.6, 0.8), Color(0.85, 0.4, 0.5)][i])
		bow.position = Vector3(0, -0.35 - i * 0.22, 0.05 * (i % 2))
		_kite.add_child(bow)
	_kite.position = KITE_POS
	add_child(_kite)
	# It never stops moving; it thrashes harder in gusts (visual only).
	var t := _kite.create_tween().set_loops()
	t.tween_property(_kite, "rotation:z", 0.35, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_kite, "rotation:z", -0.3, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_kite, "position:y", KITE_POS.y + 0.25, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(_kite, "position:y", KITE_POS.y, 0.5).set_trans(Tween.TRANS_SINE)

func _build_string() -> void:
	# The string, taut from the arch down into the shallows.
	var from := KITE_POS + Vector3(0, -0.4, 0)
	var to := JUG_POS + Vector3(0, 0.15, 0)
	var mid := (from + to) / 2.0
	var length := from.distance_to(to)
	_string = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = length
	_string.mesh = cyl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.9, 0.88, 0.8)
	_string.material_override = sm
	_string.position = mid
	# Point the cylinder's Y axis along the run of the string.
	var dir := (to - from).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.001:
		_string.rotate(axis.normalized(), Vector3.UP.angle_to(dir))
	add_child(_string)

func grab_kite() -> void:
	if GameState.get_flag("kite_freed"):
		_flash("Only the chalk arrows remain. The kite is halfway to Okotoks by now.", 3.0)
		return
	var breeze: Node = get_tree().get_first_node_in_group("bow_breeze")
	if breeze and breeze.is_gusting():
		Sfx.play("whisker_shimmer", 1.2, 0.05, -12.0)
		var t := create_tween()
		t.tween_property(_kite, "position", KITE_POS + Vector3(0.6, 0.5, -0.4), 0.25)
		t.tween_property(_kite, "position", KITE_POS, 0.4)
		_flash("The kite whips away from her paws! It only rests when the fluff rests.", 3.5)
		return
	GameState.set_flag("kite_freed")
	Sfx.play("pickup_chime", 1.2, 0.0, -10.0)
	# The kite comes loose, hangs one beat, then climbs away south.
	var t := create_tween()
	t.tween_property(_kite, "position", KITE_POS + Vector3(0, 0.8, 0), 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_kite, "position", KITE_POS + Vector3(8.0, 14.0, 30.0), 5.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_kite.queue_free)
	# The string falls slack toward the jug in the shallows.
	var st := create_tween()
	st.tween_property(_string, "position:y", _string.position.y - 1.2, 1.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	st.tween_callback(func() -> void:
		var island := get_parent()
		if island and island.has_method("_add_pickup"):
			island._add_pickup(JUG_POS, "cream_jug", "Cream Jug", Color(0.93, 0.9, 0.82))
		)
	_flash("The kite lifts free and sails for the mountains. Its string splashes down by the south shallows… tied to something.", 5.0)

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
