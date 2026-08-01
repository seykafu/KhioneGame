extends Node3D
## Island 2, Riddle 2 — The Fountain of Small Wishes.
## Eight coins rest on the fountain's ledge, marked heads (dot) or tails
## (bar). A mosaic under the water reads: heads, heads, tails. Cats push
## things: nudge coins into the water in the mosaic's order. A wrong coin
## summons a pigeon onto Khione's head and the soaked coins clink back.
## Three right pushes and the fountain drains, revealing a brass key.

const RIM_R := 3.5
const RIM_Y := 1.11
const TARGET := ["H", "H", "T"]
const COIN_TYPES := ["H", "T", "H", "T", "T", "H", "T", "H"]
const GOLD := Color(0.95, 0.8, 0.3)
const DARK_GOLD := Color(0.62, 0.47, 0.14)
const TILE := Color(0.88, 0.88, 0.92)

var _coins: Array = []  # [{node, type, home, pushed}]
var _progress := 0
var _solved := false
var _resetting := false
var _pigeon: Node3D
var _materials := {}

class CoinPlate:
	extends Interactable
	var owner_puzzle: Node
	var index := 0

	func _init() -> void:
		prompt = "Nudge the coin"

	func interact(_player: Node) -> void:
		owner_puzzle.push_coin(index)

func _ready() -> void:
	_build_mosaic()
	_build_coins()

# --- construction ---

func _build_mosaic() -> void:
	# Three tiles in reading order just beneath the water, plus a start mark.
	var start := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.14, 0.015, 0.07)
	start.mesh = sb
	start.material_override = _mat(DARK_GOLD)
	start.position = Vector3(-1.15, 1.05, 0.9)
	add_child(start)
	for i in TARGET.size():
		var tile := MeshInstance3D.new()
		tile.mesh = _cyl(0.2, 0.2, 0.015)
		tile.material_override = _mat(TILE)
		tile.position = Vector3(-0.6 + i * 0.6, 1.05, 0.9)
		add_child(tile)
		var mark := MeshInstance3D.new()
		if TARGET[i] == "H":
			mark.mesh = _cyl(0.075, 0.075, 0.012)
		else:
			var bb := BoxMesh.new()
			bb.size = Vector3(0.22, 0.012, 0.06)
			mark.mesh = bb
		mark.material_override = _mat(DARK_GOLD)
		mark.position = tile.position + Vector3(0, 0.015, 0)
		add_child(mark)

func _build_coins() -> void:
	for i in COIN_TYPES.size():
		var ang := TAU * i / COIN_TYPES.size() + 0.3
		var pos := Vector3(cos(ang) * RIM_R, RIM_Y, sin(ang) * RIM_R)
		var coin := CoinPlate.new()
		coin.owner_puzzle = self
		coin.index = i
		coin.position = pos
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.9
		cs.shape = sph
		coin.add_child(cs)
		var mesh := MeshInstance3D.new()
		mesh.mesh = _cyl(0.15, 0.15, 0.045)
		mesh.material_override = _mat(GOLD)
		coin.add_child(mesh)
		var mark := MeshInstance3D.new()
		if COIN_TYPES[i] == "H":
			mark.mesh = _cyl(0.055, 0.055, 0.02)
		else:
			var bb := BoxMesh.new()
			bb.size = Vector3(0.17, 0.02, 0.05)
			mark.mesh = bb
		mark.material_override = _mat(DARK_GOLD)
		mark.position = Vector3(0, 0.032, 0)
		coin.add_child(mark)
		add_child(coin)
		_coins.append({"node": coin, "type": COIN_TYPES[i], "home": pos, "pushed": false})

# --- puzzle logic ---

func push_coin(index: int) -> void:
	if _resetting:
		return
	var c: Dictionary = _coins[index]
	if c.pushed:
		return
	c.pushed = true
	var node: Node3D = c.node
	Sfx.play("splash", 1.7, 0.08, -12.0)
	var target := Vector3(node.position.x * 0.45, 0.95, node.position.z * 0.45)
	var t := node.create_tween()
	t.tween_property(node, "position", target, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _solved:
		return
	if c.type == TARGET[_progress]:
		_progress += 1
		Sfx.play("pickup_chime", 0.8 + 0.2 * _progress, 0.0, -14.0)
		if _progress >= TARGET.size():
			_solve()
	else:
		_fail()

func _fail() -> void:
	_resetting = true
	Sfx.play("gull", 0.55, 0.05, -10.0)
	_flash("A pigeon lands on Khione's head. It offers no advice.", 3.5)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and _pigeon == null:
		_pigeon = _make_pigeon()
		player.add_child(_pigeon)
		_pigeon.position = Vector3(0, 0.78, 0.05)
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_callback(_reset_coins)
	var t2 := create_tween()
	t2.tween_interval(4.2)
	t2.tween_callback(_pigeon_leaves)

func _reset_coins() -> void:
	_progress = 0
	for c: Dictionary in _coins:
		if c.pushed:
			c.pushed = false
			var node: Node3D = c.node
			var t := node.create_tween()
			t.tween_property(node, "position", c.home, 0.5) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("coconut_thunk", 1.8, 0.1, -14.0)
	_flash("The soaked coins clink back onto the ledge, unimpressed.", 3.0)
	_resetting = false

func _solve() -> void:
	_solved = true
	GameState.set_flag("fountain_wish_made")
	Sfx.play("drain", 1.0, 0.0, -4.0)
	var water: MeshInstance3D = get_parent().get_node_or_null("FountainWater")
	if water:
		var t := water.create_tween().set_parallel(true)
		t.tween_property(water, "position:y", water.position.y - 0.3, 2.0)
		t.tween_property(water, "transparency", 0.65, 2.0)
	var drain := MeshInstance3D.new()
	drain.mesh = _cyl(0.35, 0.35, 0.03)
	drain.material_override = _mat(Color(0.12, 0.11, 0.1))
	drain.position = Vector3(0, 1.0, 0)
	add_child(drain)
	_spawn_key(Vector3(0, 1.04, 0))
	_flash("The fountain sighs and drains. Something brass glints at the bottom.", 4.5)

func _spawn_key(pos: Vector3) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/interaction/item_pickup.gd"))
	a.set("item_id", "brass_key")
	a.set("display_name", "Brass Key")
	a.position = pos
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.4
	cs.shape = sph
	a.add_child(cs)
	var bow := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.05
	torus.outer_radius = 0.09
	bow.mesh = torus
	bow.material_override = _mat(Color(0.75, 0.6, 0.25))
	bow.rotation.x = PI / 2.0
	bow.position = Vector3(-0.08, 0.06, 0)
	a.add_child(bow)
	var shaft := MeshInstance3D.new()
	var shb := BoxMesh.new()
	shb.size = Vector3(0.22, 0.035, 0.035)
	shaft.mesh = shb
	shaft.material_override = _mat(Color(0.75, 0.6, 0.25))
	shaft.position = Vector3(0.08, 0.06, 0)
	a.add_child(shaft)
	for i in 2:
		var tooth := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.035, 0.07, 0.035)
		tooth.mesh = tb
		tooth.material_override = _mat(Color(0.75, 0.6, 0.25))
		tooth.position = Vector3(0.13 + i * 0.055, 0.02, 0)
		a.add_child(tooth)
	add_child(a)

func _make_pigeon() -> Node3D:
	var p := Node3D.new()
	var grey := Color(0.55, 0.56, 0.6)
	var body := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.11
	bs.height = 0.17
	body.mesh = bs
	body.scale = Vector3(1.0, 1.0, 1.4)
	body.material_override = _mat(grey)
	p.add_child(body)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.06
	hs.height = 0.11
	head.mesh = hs
	head.material_override = _mat(grey.darkened(0.15))
	head.position = Vector3(0, 0.1, 0.1)
	p.add_child(head)
	var beak := MeshInstance3D.new()
	var bk := CylinderMesh.new()
	bk.top_radius = 0.0
	bk.bottom_radius = 0.02
	bk.height = 0.05
	beak.mesh = bk
	beak.material_override = _mat(Color(0.9, 0.65, 0.3))
	beak.rotation.x = PI / 2.0
	beak.position = Vector3(0, 0.1, 0.16)
	p.add_child(beak)
	# The pigeon bobs, because pigeons bob.
	var bob := p.create_tween().set_loops()
	bob.tween_property(p, "rotation:x", 0.12, 0.35)
	bob.tween_property(p, "rotation:x", -0.06, 0.35)
	return p

func _pigeon_leaves() -> void:
	if _pigeon == null:
		return
	var p := _pigeon
	_pigeon = null
	Sfx.play("gull", 0.6, 0.08, -14.0)
	var t := p.create_tween().set_parallel(true)
	t.tween_property(p, "position", p.position + Vector3(1.5, 2.5, 0.5), 1.0)
	t.tween_property(p, "scale", Vector3.ONE * 0.05, 1.0) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(p.queue_free)

# --- helpers ---

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.6
		_materials[color] = m
	return _materials[color]

func _cyl(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c
