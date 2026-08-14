extends Node3D
## Beat 4b — The Crab and the Vines (kindness over confrontation).
## Vines hang from a tall rock near Echo Cove, guarded by a big crab.
## Offer it the Stranded Fish from the tide pool and it snips a length of
## vine rope for the raft. Empty paws get a pointed look.

const CRAB_RED := Color(0.85, 0.4, 0.3)
const VINE_GREEN := Color(0.36, 0.52, 0.28)

var _crab: Node3D
var _vines: Array[Node3D] = []
var _snipped := false
var _plate: Interactable
var _materials := {}

class CrabPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "A crab guards the vines"

	func interact(_player: Node) -> void:
		owner_puzzle.crab_interact()

func _ready() -> void:
	var rock: Node3D = load("res://assets/nature/rock_tallA.glb").instantiate()
	rock.position = Vector3(0, 0, -1.5)
	rock.scale = Vector3.ONE * 2.8
	add_child(rock)
	var mi := _fmi(rock)
	if mi:
		mi.create_convex_collision()  # solid vine rock, not a hollow shell

	for i in 3:
		var vine := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.03
		cyl.height = 1.6
		vine.mesh = cyl
		vine.material_override = _mat(VINE_GREEN)
		vine.position = Vector3(-0.5 + i * 0.5, 1.6, -0.15)
		vine.rotation.z = 0.06 - i * 0.05
		add_child(vine)
		_vines.append(vine)

	_build_crab()

	_plate = CrabPlate.new()
	_plate.owner_puzzle = self
	_plate.position = Vector3(0.4, 0.4, 1.2)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	cs.shape = sph
	_plate.add_child(cs)
	add_child(_plate)

func _process(_delta: float) -> void:
	if _plate == null or _snipped:
		return
	if Inventory.has_item("stranded_fish"):
		_plate.prompt = "Offer the Stranded Fish"
	else:
		_plate.prompt = "A crab guards the vines"

func _build_crab() -> void:
	_crab = Node3D.new()
	_crab.position = Vector3(0.4, 0.0, 1.2)
	var body := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.32
	bs.height = 0.42
	body.mesh = bs
	body.material_override = _mat(CRAB_RED)
	body.position = Vector3(0, 0.22, 0)
	_crab.add_child(body)
	for side in [-1.0, 1.0]:
		var claw := MeshInstance3D.new()
		var cls := SphereMesh.new()
		cls.radius = 0.14
		cls.height = 0.24
		claw.mesh = cls
		claw.material_override = _mat(CRAB_RED.darkened(0.12))
		claw.position = Vector3(0.3 * side, 0.18, 0.28)
		_crab.add_child(claw)
		var stalk := MeshInstance3D.new()
		var st := CylinderMesh.new()
		st.top_radius = 0.018
		st.bottom_radius = 0.018
		st.height = 0.14
		stalk.mesh = st
		stalk.material_override = _mat(CRAB_RED.darkened(0.2))
		stalk.position = Vector3(0.09 * side, 0.48, 0.12)
		_crab.add_child(stalk)
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.04
		es.height = 0.08
		eye.mesh = es
		eye.material_override = _mat(Color(0.1, 0.08, 0.08))
		eye.position = Vector3(0.09 * side, 0.56, 0.12)
		_crab.add_child(eye)
	add_child(_crab)
	var shuffle := _crab.create_tween().set_loops()
	shuffle.tween_property(_crab, "position:x", 0.9, 1.6).set_trans(Tween.TRANS_SINE)
	shuffle.tween_property(_crab, "position:x", -0.1, 1.6).set_trans(Tween.TRANS_SINE)

func crab_interact() -> void:
	if _snipped:
		return
	if not Inventory.has_item("stranded_fish"):
		Sfx.play("crab_snip", 1.0, 0.1, -8.0)
		_flash("The crab snaps its claws and eyes Khione's empty paws. It looks hungry.", 3.5)
		return
	Inventory.remove_item("stranded_fish")
	_snipped = true
	GameState.set_flag("vines_snipped")
	Sfx.play("crab_snip", 1.0, 0.05, -4.0)
	var again := create_tween()
	again.tween_interval(0.35)
	again.tween_callback(Sfx.play.bind("crab_snip", 1.15, 0.05, -6.0))
	var hop := create_tween()
	hop.tween_property(_crab, "position:y", 0.35, 0.18)
	hop.tween_property(_crab, "position:y", 0.0, 0.18)
	hop.tween_property(_crab, "position:y", 0.3, 0.16)
	hop.tween_property(_crab, "position:y", 0.0, 0.16)
	for v in _vines:
		var t := v.create_tween().set_parallel(true)
		t.tween_property(v, "position:y", 0.1, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(v, "transparency", 1.0, 0.9)
		t.chain().tween_callback(v.queue_free)
	_vines = []
	_spawn_rope()
	_flash("Snip, snip. A fair trade. The crab cuts you a length of vine.", 4.0)

func _spawn_rope() -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/interaction/item_pickup.gd"))
	a.set("item_id", "vine_rope")
	a.set("display_name", "Vine Rope")
	a.position = Vector3(0, 0.08, -0.1)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.2
	cs.shape = sph
	a.add_child(cs)
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.12
	torus.outer_radius = 0.2
	mi.mesh = torus
	mi.material_override = _mat(VINE_GREEN.darkened(0.1))
	mi.position = Vector3(0, 0.05, 0)
	a.add_child(mi)
	add_child(a)

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

func _fmi(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _fmi(c)
		if r:
			return r
	return null
