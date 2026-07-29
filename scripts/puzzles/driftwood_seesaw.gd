extends Node3D
## Beat 2 — The Driftwood Seesaw (west hillside).
## A driftwood plank balances on a wedge rock; its far end is lashed to a
## woven-vine gate over a low den dug into the hillside. Palms drop coconuts —
## carry them (one inventory slot each) and load the basket end. Three
## coconuts tip the plank and hoist the gate. Inside: an Old Oar, and scratch
## marks far too low on the walls. Teaches inventory weight; Oreo foreshadow #2.

const COCONUTS_NEEDED := 3
const TILTS := [0.18, 0.1, 0.0, -0.18]
const DRIFTWOOD := Color(0.72, 0.65, 0.55)
const VINE := Color(0.42, 0.5, 0.3)
const FRAME := Color(0.45, 0.32, 0.2)
const DARK := Color(0.1, 0.09, 0.09)
const ROCK := Color(0.55, 0.55, 0.58)

var _pivot: Node3D
var _gate_root: Node3D
var _placed := 0
var _open := false
var _materials := {}

class BasketPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Place a coconut"

	func interact(_player: Node) -> void:
		owner_puzzle.place_coconut()

class ScratchMarks:
	extends Interactable

	func _init() -> void:
		prompt = "Look at the scratch marks"

	func interact(_player: Node) -> void:
		GameState.set_flag("seen_scratches")
		get_node("/root/Main/HUD").flash_message("Low scratch marks line the den walls… something dug here, long ago.", 4.0)

func _ready() -> void:
	_build_seesaw()
	_build_den()
	_build_gate()
	_place_oar()

# --- puzzle logic ---

func place_coconut() -> void:
	if _open:
		return
	if not Inventory.has_item("coconut"):
		get_node("../../HUD").flash_message("Khione's paws are empty… the palms drop coconuts.", 3.0)
		return
	Inventory.remove_item("coconut")
	_placed += 1
	Sfx.play("coconut_thunk", 1.0, 0.08, -4.0)
	var coco := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.3
	coco.mesh = mesh
	coco.material_override = _mat(Color(0.4, 0.28, 0.16))
	var spots := [Vector3(1.3, 0.25, -0.12), Vector3(1.58, 0.25, 0.12), Vector3(1.44, 0.5, 0.0)]
	coco.position = spots[mini(_placed - 1, spots.size() - 1)]
	_pivot.add_child(coco)
	Sfx.play("wood_creak", 1.0, 0.1, -8.0)
	var t := create_tween()
	t.tween_property(_pivot, "rotation:z", TILTS[mini(_placed, TILTS.size() - 1)], 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _placed >= COCONUTS_NEEDED:
		_open_gate()

func _open_gate() -> void:
	_open = true
	GameState.set_flag("seesaw_gate_open")
	await get_tree().create_timer(0.8).timeout
	Sfx.play("gate_open", 1.0, 0.0, -4.0)
	var t := create_tween()
	t.tween_property(_gate_root, "position:y", _gate_root.position.y + 1.5, 1.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	get_node("../../HUD").flash_message("The vine gate groans upward… the den lies open.", 4.0)

# --- world building (local +Z faces away from the hillside) ---

func _build_seesaw() -> void:
	var wedge := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.0, 0.55, 0.7)
	wedge.mesh = prism
	wedge.material_override = _mat(ROCK)
	wedge.position = Vector3(0, 0.28, 2.8)
	add_child(wedge)
	wedge.create_trimesh_collision()

	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 0.58, 2.8)
	_pivot.rotation.z = TILTS[0]
	add_child(_pivot)

	var plank := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.6, 0.12, 0.6)
	plank.mesh = box
	plank.material_override = _mat(DRIFTWOOD)
	_pivot.add_child(plank)

	var pad := MeshInstance3D.new()
	var pad_box := BoxMesh.new()
	pad_box.size = Vector3(0.75, 0.1, 0.7)
	pad.mesh = pad_box
	pad.material_override = _mat(VINE)
	pad.position = Vector3(1.45, 0.1, 0)
	_pivot.add_child(pad)

	var basket := BasketPlate.new()
	basket.owner_puzzle = self
	basket.position = Vector3(1.9, 0.5, 2.8)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.0
	cs.shape = sph
	basket.add_child(cs)
	add_child(basket)

func _build_den() -> void:
	var sides := [
		["res://assets/nature/rock_largeB.glb", Vector3(-1.05, 0, -0.4), 2.2],
		["res://assets/nature/rock_largeC.glb", Vector3(1.05, 0, -0.4), 2.2],
		["res://assets/nature/rock_largeA.glb", Vector3(0, 1.3, -0.5), 2.4],
	]
	for def: Array in sides:
		var rock: Node3D = load(def[0]).instantiate()
		rock.position = def[1]
		rock.scale = Vector3.ONE * (def[2] as float)
		add_child(rock)
		var mi := _first_mesh_instance(rock)
		if mi:
			mi.create_trimesh_collision()

	var back := MeshInstance3D.new()
	var back_box := BoxMesh.new()
	back_box.size = Vector3(1.8, 1.7, 0.15)
	back.mesh = back_box
	back.material_override = _mat(DARK)
	back.position = Vector3(0, 0.85, -1.9)
	add_child(back)
	back.create_trimesh_collision()

	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(1.7, 0.05, 2.0)
	floor_mesh.mesh = floor_box
	floor_mesh.material_override = _mat(Color(0.35, 0.3, 0.26))
	floor_mesh.position = Vector3(0, 0.03, -0.95)
	add_child(floor_mesh)

	# The marks: shallow, parallel, and far too low for anything with hands.
	for i in 4:
		var mark := MeshInstance3D.new()
		var mark_box := BoxMesh.new()
		mark_box.size = Vector3(0.03, 0.3, 0.03)
		mark.mesh = mark_box
		mark.material_override = _mat(Color(0.05, 0.045, 0.04))
		mark.position = Vector3(-0.35 + i * 0.22, 0.42, -1.81)
		mark.rotation.z = 0.12 - i * 0.05
		add_child(mark)

	var marks := ScratchMarks.new()
	marks.position = Vector3(0, 0.5, -1.5)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.3
	cs.shape = sph
	marks.add_child(cs)
	add_child(marks)

func _build_gate() -> void:
	_gate_root = Node3D.new()
	_gate_root.position = Vector3(0, 0, 0.55)
	add_child(_gate_root)

	for x in [-0.75, 0.75]:
		_gate_bar(Vector3(x, 0.75, 0), Vector3(0.09, 1.5, 0.09), FRAME)
	for x in [-0.38, 0.0, 0.38]:
		_gate_bar(Vector3(x, 0.75, 0.03), Vector3(0.06, 1.5, 0.06), VINE)
	for y in [0.42, 1.05]:
		_gate_bar(Vector3(0, y, -0.03), Vector3(1.6, 0.07, 0.07), VINE)

	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.7, 1.5, 0.14)
	cs.shape = box
	cs.position = Vector3(0, 0.75, 0)
	body.add_child(cs)
	_gate_root.add_child(body)

func _gate_bar(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _mat(color)
	mi.position = pos
	_gate_root.add_child(mi)

func _place_oar() -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/interaction/item_pickup.gd"))
	a.set("item_id", "old_oar")
	a.set("display_name", "Old Oar")
	a.position = Vector3(0, 0.1, -1.15)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.1
	cs.shape = sph
	a.add_child(cs)
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.045
	cyl.height = 1.4
	shaft.mesh = cyl
	shaft.material_override = _mat(DRIFTWOOD)
	shaft.rotation.z = 1.35
	shaft.position = Vector3(0, 0.12, 0)
	a.add_child(shaft)
	var blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(0.3, 0.02, 0.16)
	blade.mesh = blade_box
	blade.material_override = _mat(DRIFTWOOD.darkened(0.15))
	blade.position = Vector3(0.62, 0.24, 0)
	a.add_child(blade)
	add_child(a)

# --- helpers ---

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		_materials[color] = m
	return _materials[color]

func _first_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _first_mesh_instance(c)
		if r:
			return r
	return null
