extends Node3D
## Beat 4a — The Dry Frond (platforming test).
## The tallest palm carries one huge dry frond, too high to reach from the
## ground. A stepping rock and a bent palm's crown form a jump route; leaping
## into the frond knocks it loose, and it drops as the raft's sail.

const DRY := Color(0.66, 0.61, 0.32)

var _frond: Node3D
var _knocked := false
var _materials := {}

func _ready() -> void:
	var rock: Node3D = load("res://assets/nature/rock_smallC.glb").instantiate()
	rock.position = Vector3(-4.6, 0, 1.8)
	rock.scale = Vector3.ONE * 2.2
	add_child(rock)
	_fmi(rock).create_trimesh_collision()

	var bent: Node3D = load("res://assets/nature/tree_palmBend.glb").instantiate()
	bent.position = Vector3(-2.6, 0, 0.6)
	bent.scale = Vector3.ONE * 3.4
	bent.rotation.y = 0.4
	add_child(bent)
	# Invisible ledges along the bend so the climb is reliable.
	_ledge(Vector3(-3.2, 1.05, 0.9), Vector3(1.2, 0.15, 1.2))
	_ledge(Vector3(-2.2, 2.25, 0.4), Vector3(1.4, 0.15, 1.4))

	var tall: Node3D = load("res://assets/nature/tree_palmDetailedTall.glb").instantiate()
	tall.scale = Vector3.ONE * 3.6
	add_child(tall)
	var trunk := StaticBody3D.new()
	var tcs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 4.0
	tcs.shape = cyl
	tcs.position = Vector3(0, 2.0, 0)
	trunk.add_child(tcs)
	add_child(trunk)

	# The dry frond, fanned out high on the tall palm.
	_frond = Node3D.new()
	_frond.position = Vector3(0.3, 3.35, 0.3)
	for i in 3:
		var blade := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.95, 0.04, 0.22)
		blade.mesh = box
		blade.material_override = _mat(DRY)
		blade.position = Vector3(0.35, 0, 0)
		blade.rotation.y = -0.5 + i * 0.5
		blade.rotation.z = -0.3
		_frond.add_child(blade)
	add_child(_frond)

	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.95
	cs.shape = sph
	area.add_child(cs)
	area.position = _frond.position
	area.body_entered.connect(_on_touch)
	add_child(area)

func _on_touch(body: Node3D) -> void:
	if body.is_in_group("player"):
		knock_down()

func knock_down() -> void:
	if _knocked:
		return
	_knocked = true
	Sfx.play("paper_open", 0.6, 0.1, -4.0)
	Sfx.play("wood_creak", 1.3, 0.1, -10.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(_frond, "position", Vector3(0.9, 0.15, 0.9), 0.9) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_frond, "rotation", Vector3(0.4, 1.2, 1.3), 0.9)
	t.chain().tween_callback(_landed)

func _landed() -> void:
	Sfx.play("land", 0.8, 0.1, -8.0)
	_frond.queue_free()
	var a := Area3D.new()
	a.set_script(load("res://scripts/interaction/item_pickup.gd"))
	a.set("item_id", "palm_frond")
	a.set("display_name", "Dry Frond")
	a.position = Vector3(0.9, 0.05, 0.9)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.2
	cs.shape = sph
	a.add_child(cs)
	var mi := MeshInstance3D.new()
	var leaf := BoxMesh.new()
	leaf.size = Vector3(1.1, 0.05, 0.3)
	mi.mesh = leaf
	mi.material_override = _mat(DRY)
	mi.rotation.y = 0.7
	mi.position = Vector3(0, 0.05, 0)
	a.add_child(mi)
	add_child(a)
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message("A great dry frond drops to the grass.", 3.0)

func _ledge(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	body.position = pos
	add_child(body)

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
