extends Node3D
## Beat 3 — The Sundial Reef.
## A crude sundial on the Old Summit is missing its gnomon; the Sun Shell fits.
## Placed, its shadow (and a trail of glints) points at one specific sea rock
## among several with gulls perched on top. Climb the right rock and meow:
## the gulls burst skyward and a raft frame shakes loose from the reef,
## drifting to the south beach. Wrong rocks just annoy the gulls.

const SUNDIAL_POS := Vector3(1.8, 3.3, -1.5)
const TARGET_ROCK := Vector3(38.0, -0.8, -32.0)
const DECOY_ROCKS := [Vector3(-45.0, -0.8, 18.0), Vector3(-15.0, -0.8, -46.0)]
const BEACH_POINT := Vector3(-4.0, 0.14, 35.0)  # on the sand, clear of dunes, beside the bottle

const STONE := Color(0.55, 0.55, 0.58)
const DIAL := Color(0.85, 0.8, 0.66)
const GOLD := Color(0.95, 0.78, 0.25)
const DRIFTWOOD := Color(0.72, 0.65, 0.55)
const GULL_WHITE := Color(0.95, 0.95, 0.97)

var _materials := {}
var _socket: Interactable
var _dial_top := Vector3.ZERO
var _shell_placed := false
var _raft_released := false
var _raft: Node3D
var _rock_infos: Array = []

class SundialSocket:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "An empty socket…"

	func interact(_player: Node) -> void:
		owner_puzzle.sundial_interact()

class RaftExamine:
	extends Interactable

	func _init() -> void:
		prompt = "Examine the timbers"

	func interact(_player: Node) -> void:
		GameState.set_flag("raft_frame_examined")
		var rig := get_tree().get_first_node_in_group("raft_rigging")
		if rig:
			rig.raft_interact(get_parent())

func _ready() -> void:
	_build_sundial()
	_build_rock(TARGET_ROCK, true)
	for pos: Vector3 in DECOY_ROCKS:
		_build_rock(pos, false)
	GameState.vocal_used.connect(_on_vocal)

func _process(_delta: float) -> void:
	if _socket == null:
		return
	if _shell_placed:
		_socket.prompt = "Sight along the shadow"
	elif Inventory.has_item("sun_shell"):
		_socket.prompt = "Place the Sun Shell"
	else:
		_socket.prompt = "An empty socket…"

# --- sundial ---

func sundial_interact() -> void:
	if _shell_placed:
		_show_light_trail()
		_flash("The shadow reaches toward a far rock, out across the water…", 3.5)
		return
	if not Inventory.has_item("sun_shell"):
		_flash("An empty socket on the dial… shaped like a shell.", 3.0)
		return
	place_shell()

func place_shell() -> void:
	if _shell_placed:
		return
	Inventory.remove_item("sun_shell")
	_shell_placed = true
	GameState.set_flag("sundial_shell_placed")
	Sfx.play("stone_slide", 1.3, 0.05, -10.0)
	Sfx.play("pickup_chime", 1.15, 0.0, -8.0)
	_build_gnomon_and_shadow()
	_show_light_trail()
	_flash("The shell's shadow stretches far across the water…", 4.0)

func _build_sundial() -> void:
	var pedestal := _box_free_mesh(_cylinder(0.55, 0.7, 0.5), SUNDIAL_POS + Vector3(0, 0.25, 0), STONE, true)
	var dial := _box_free_mesh(_cylinder(0.62, 0.62, 0.08), SUNDIAL_POS + Vector3(0, 0.54, 0), DIAL, true)
	_dial_top = SUNDIAL_POS + Vector3(0, 0.6, 0)
	for i in 8:
		var ang := TAU * i / 8.0
		var tick := BoxMesh.new()
		tick.size = Vector3(0.05, 0.02, 0.12)
		var mi := _box_free_mesh(tick, _dial_top + Vector3(sin(ang), 0.0, cos(ang)) * 0.5, STONE.darkened(0.3), false)
		mi.rotation.y = ang
	# The empty gnomon socket — a small dark slot at the centre.
	_box_free_mesh(_cylinder(0.07, 0.07, 0.06), _dial_top + Vector3(0, 0.01, 0), Color(0.15, 0.13, 0.1), false)

	_socket = SundialSocket.new()
	_socket.owner_puzzle = self
	_socket.position = SUNDIAL_POS + Vector3(0, 0.6, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.2
	cs.shape = sph
	_socket.add_child(cs)
	add_child(_socket)

func _build_gnomon_and_shadow() -> void:
	# The shell stands upright as the gnomon.
	_box_free_mesh(_cylinder(0.0, 0.24, 0.42), _dial_top + Vector3(0, 0.21, 0), GOLD, false)
	# Its shadow lies across the dial, aimed at the target rock.
	var yaw := atan2(TARGET_ROCK.x - SUNDIAL_POS.x, TARGET_ROCK.z - SUNDIAL_POS.z)
	var wedge := BoxMesh.new()
	wedge.size = Vector3(0.14, 0.015, 1.15)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.09, 0.12, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = wedge
	mi.material_override = m
	mi.position = _dial_top + Vector3(sin(yaw), 0.02, cos(yaw)) * 0.58
	mi.rotation.y = yaw
	add_child(mi)

func _show_light_trail() -> void:
	var from := _dial_top + Vector3(0, 0.3, 0)
	var to := TARGET_ROCK + Vector3(0, 2.6, 0)
	for i in 16:
		var t := (i + 1) / 16.0
		var pos := from.lerp(to, t)
		var tw := create_tween()
		tw.tween_interval(0.09 * i)
		tw.tween_callback(_spawn_glint.bind(pos))

func _spawn_glint(pos: Vector3) -> void:
	var g := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.11
	s.height = 0.22
	g.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.9, 0.5, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g.material_override = m
	add_child(g)
	g.global_position = pos
	var t := g.create_tween().set_parallel(true)
	t.tween_property(g, "position:y", g.position.y + 0.4, 1.2)
	t.tween_property(g, "transparency", 1.0, 1.2)
	t.chain().tween_callback(g.queue_free)

# --- gull rocks ---

func _build_rock(pos: Vector3, is_target: bool) -> void:
	var rock: Node3D = load("res://assets/nature/rock_tallB.glb").instantiate()
	rock.position = pos
	rock.scale = Vector3.ONE * (3.2 if is_target else 3.0)
	rock.rotation.y = pos.x * 0.7
	add_child(rock)
	var mi := _first_mesh_instance(rock)
	if mi:
		mi.create_convex_collision()  # climbable solid rock, not a hollow shell
	# A lower stepping rock on the island-facing side, so the climb reads.
	var toward_island := Vector3(-pos.x, 0, -pos.z).normalized() * 3.2
	var step: Node3D = load("res://assets/nature/rock_smallB.glb").instantiate()
	step.position = pos + toward_island + Vector3(0, 0.25, 0)
	step.scale = Vector3.ONE * 2.4
	add_child(step)
	var smi := _first_mesh_instance(step)
	if smi:
		smi.create_convex_collision()  # solid stepping rock

	var info := {"pos": pos, "birds": [], "is_target": is_target, "scattered": false}
	_rock_infos.append(info)
	_build_birds(info)

func _build_birds(info: Dictionary) -> void:
	info.scattered = false
	for i in 3:
		var bird := Node3D.new()
		var body := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.14
		bs.height = 0.24
		body.mesh = bs
		body.material_override = _mat(GULL_WHITE)
		bird.add_child(body)
		var head := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 0.08
		hs.height = 0.16
		head.mesh = hs
		head.material_override = _mat(GULL_WHITE)
		head.position = Vector3(0, 0.12, 0.1)
		bird.add_child(head)
		var beak := MeshInstance3D.new()
		var bk := CylinderMesh.new()
		bk.top_radius = 0.0
		bk.bottom_radius = 0.025
		bk.height = 0.07
		beak.mesh = bk
		beak.material_override = _mat(Color(0.95, 0.6, 0.2))
		beak.rotation.x = PI / 2.0
		beak.position = Vector3(0, 0.12, 0.18)
		bird.add_child(beak)
		bird.position = (info.pos as Vector3) + Vector3(randf_range(-0.9, 0.9), 2.25 + randf_range(-0.1, 0.25), randf_range(-0.9, 0.9))
		bird.rotation.y = randf_range(0.0, TAU)
		add_child(bird)
		info.birds.append(bird)
		var bob := bird.create_tween().set_loops()
		bob.tween_property(bird, "position:y", bird.position.y + 0.05, 0.8 + 0.2 * i)
		bob.tween_property(bird, "position:y", bird.position.y, 0.8 + 0.2 * i)

func _on_vocal(kind: String) -> void:
	if kind != "meow":
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for info: Dictionary in _rock_infos:
		var top: Vector3 = (info.pos as Vector3) + Vector3(0, 2.3, 0)
		if player.global_position.distance_to(top) < 4.8 and player.global_position.y > 0.5:
			_scatter(info)
			break

func _scatter(info: Dictionary) -> void:
	if info.scattered:
		return
	info.scattered = true
	Sfx.play("gull", 1.1, 0.15, -6.0)
	Sfx.play("gull", 0.92, 0.1, -9.0)
	for b: Node3D in info.birds:
		var t := b.create_tween().set_parallel(true)
		t.tween_property(b, "position", b.position + Vector3(randf_range(-2.5, 2.5), 6.5 + randf() * 2.0, randf_range(-2.5, 2.5)), 1.5)
		t.tween_property(b, "scale", Vector3.ONE * 0.05, 1.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		t.chain().tween_callback(b.queue_free)
	info.birds = []
	if info.is_target:
		if not _raft_released:
			_release_raft()
	else:
		_flash("The gulls resettle somewhere else… unimpressed.", 3.0)
		var tw := create_tween()
		tw.tween_interval(25.0)
		tw.tween_callback(_build_birds.bind(info))

# --- the raft frame ---

func _release_raft() -> void:
	_raft_released = true
	GameState.set_flag("raft_released")
	_flash("The gulls burst skyward. Something shakes loose from the reef below…", 4.0)
	Sfx.play("splash", 0.8, 0.1, -6.0)
	Sfx.play("wood_creak", 0.8, 0.1, -8.0)
	_raft = _build_raft(TARGET_ROCK + Vector3(-3.0, 0.58, 3.0))
	# Drift around the east shore in open water, then ground on the south beach.
	var t := create_tween()
	t.tween_property(_raft, "position", Vector3(52.0, -0.2, 10.0), 3.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(_raft, "position", Vector3(20.0, -0.1, 40.0), 3.5) \
			.set_trans(Tween.TRANS_SINE)
	t.tween_property(_raft, "position", BEACH_POINT, 2.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(_raft_beached)
	var rt := create_tween()
	rt.tween_property(_raft, "rotation:y", 1.2, 9.5)

func _raft_beached() -> void:
	GameState.set_flag("raft_frame_beached")
	Sfx.play("wood_creak", 1.1, 0.1, -8.0)
	_flash("Timbers wash up on the south beach.", 4.0)

func _build_raft(pos: Vector3) -> Node3D:
	var raft := Node3D.new()
	raft.name = "RaftFrame"
	raft.position = pos
	raft.rotation.z = 0.04
	for z in [-0.7, 0.0, 0.7]:
		var log_mesh := BoxMesh.new()
		log_mesh.size = Vector3(2.4, 0.16, 0.24)
		var mi := MeshInstance3D.new()
		mi.mesh = log_mesh
		mi.material_override = _mat(DRIFTWOOD)
		mi.position = Vector3(0, 0, z)
		raft.add_child(mi)
	for x in [-1.0, 1.0]:
		var cross := BoxMesh.new()
		cross.size = Vector3(0.18, 0.12, 1.7)
		var mi := MeshInstance3D.new()
		mi.mesh = cross
		mi.material_override = _mat(DRIFTWOOD.darkened(0.15))
		mi.position = Vector3(x, 0.13, 0)
		raft.add_child(mi)
	var examine := RaftExamine.new()
	examine.name = "Examine"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	cs.shape = sph
	examine.add_child(cs)
	raft.add_child(examine)
	add_child(raft)
	return raft

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

func _cylinder(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c

func _box_free_mesh(mesh: Mesh, pos: Vector3, color: Color, collide: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
	if collide:
		mi.create_convex_collision()  # cylinders/boxes are single convex prims
	return mi

func _first_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _first_mesh_instance(c)
		if r:
			return r
	return null
