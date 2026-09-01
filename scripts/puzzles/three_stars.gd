extends Node3D
## Island 5, Riddle 2 — The Three Stars (the Bell Centre).
## The arena is empty and the ice still glows. The Zamboni sits on the
## centre dot: a hiss sends it fleeing to the corner. The great scoreboard
## cube hangs dark, the biggest thing downtown: from centre ice, a growl
## wakes it. Goal horn, and it calls the three stars as three retired
## numbers, one at a time. Five banners lie fallen at their hoists: raise
## the three stars in the order called and the penalty box door swings
## open on three spare panes of arena glass. A wrong hoist: buzzer, every
## banner drops, and the crowd that is not there groans.

const STARS := [9, 4, 10]           # Richard, Béliveau, Lafleur
const BANNERS := [9, 4, 33, 10, 16]
const CUBE_LOCAL := Vector3(0, 4.6, 0)
const CENTRE_LOCAL := Vector3(0, 0.0, 0)

var _arena: Node3D
var _cube: MeshInstance3D
var _screens: Array[MeshInstance3D] = []
var _screen_labels: Array[Label3D] = []
var _zamboni: Node3D
var _zamboni_moved := false
var _awake := false
var _call_round := 0   # bumping this retires any running callout loop
var _hoisted: Array[int] = []
var _banner_nodes := {}
var _box_door: MeshInstance3D

class BannerPlate:
	extends Interactable
	var owner_puzzle: Node
	var number := 0

	func interact(_player: Node) -> void:
		owner_puzzle.hoist(number)

func _ready() -> void:
	var island := get_parent()
	_arena = island.arena
	# The ice: a pale glowing sheet with boards.
	var ice := MeshInstance3D.new()
	var im := BoxMesh.new()
	im.size = Vector3(11.5, 0.06, 9.5)
	ice.mesh = im
	var imat := StandardMaterial3D.new()
	imat.albedo_color = Color(0.86, 0.92, 0.97)
	imat.roughness = 0.08
	imat.emission_enabled = true
	imat.emission = Color(0.7, 0.8, 0.9)
	imat.emission_energy_multiplier = 0.25
	ice.material_override = imat
	ice.position = Vector3(0, 0.03, 0)
	_arena.add_child(ice)
	ice.create_convex_collision()
	for def: Array in [[Vector3(11.7, 0.5, 0.12), Vector3(0, 0.25, 4.8)], [Vector3(11.7, 0.5, 0.12), Vector3(0, 0.25, -4.8)],
			[Vector3(0.12, 0.5, 9.7), Vector3(5.85, 0.25, 0)], [Vector3(0.12, 0.5, 9.7), Vector3(-5.85, 0.25, 0)]]:
		_child_box(_arena, def[0], def[1], Color(0.95, 0.95, 0.95), true)
	# Red and blue lines, and the centre dot.
	_child_box(_arena, Vector3(0.12, 0.01, 9.4), Vector3(0, 0.065, 0), Color(0.8, 0.15, 0.15), false)
	for bx: float in [-3.5, 3.5]:
		_child_box(_arena, Vector3(0.1, 0.01, 9.4), Vector3(bx, 0.065, 0), Color(0.15, 0.25, 0.7), false)
	var dot := _child_mesh(_arena, _cyl(0.25, 0.25, 0.01), Vector3(0, 0.07, 0), Color(0.8, 0.15, 0.15), false)
	var _k := dot
	# Two nets.
	for gx: float in [-5.0, 5.0]:
		var net := _child_box(_arena, Vector3(0.3, 0.9, 1.6), Vector3(gx, 0.45, 0), Color(0.85, 0.2, 0.2), true)
		var _k2 := net
	# The Zamboni on the centre dot.
	_zamboni = Node3D.new()
	_zamboni.name = "Zamboni"
	_zamboni.position = CENTRE_LOCAL
	_arena.add_child(_zamboni)
	_child_box(_zamboni, Vector3(1.6, 1.0, 2.6), Vector3(0, 0.55, 0), Color(0.9, 0.9, 0.9), true)
	_child_box(_zamboni, Vector3(1.4, 0.7, 1.0), Vector3(0, 1.4, -0.6), Color(0.85, 0.2, 0.2), true)
	for s: Array in [[-0.7, 0.9], [0.7, 0.9], [-0.7, -0.9], [0.7, -0.9]]:
		var wheel := _child_mesh(_zamboni, _cyl(0.28, 0.28, 0.2), Vector3(s[0], 0.28, s[1]), Color(0.15, 0.15, 0.17), true)
		wheel.rotation.z = PI / 2.0
	# The scoreboard cube, hanging dark over centre.
	_cube = _child_box(_arena, Vector3(2.4, 1.6, 2.4), CUBE_LOCAL, Color(0.14, 0.14, 0.16), true)
	_cube.name = "ScoreboardCube"
	# A real jumbotron: an inset screen on each of the four faces, dark
	# until the growl wakes it, with the text rendered ON the glass.
	for k in 4:
		var face := Node3D.new()
		face.position = CUBE_LOCAL
		face.rotation.y = k * PI / 2.0
		_arena.add_child(face)
		var screen := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(2.0, 1.2, 0.05)
		screen.mesh = sm
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.05, 0.05, 0.07)
		smat.roughness = 0.25
		screen.material_override = smat
		screen.position = Vector3(0, 0, 1.23)
		face.add_child(screen)
		_screens.append(screen)
		var lbl := Label3D.new()
		lbl.font_size = 64
		lbl.pixel_size = 0.006
		lbl.modulate = Color(1.0, 0.78, 0.3)
		lbl.outline_size = 8
		lbl.outline_modulate = Color(0.4, 0.2, 0.05)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector3(0, 0, 1.27)
		lbl.text = ""
		face.add_child(lbl)
		_screen_labels.append(lbl)
	# The frame band around the screens.
	_child_box(_arena, Vector3(2.5, 0.12, 2.5), CUBE_LOCAL + Vector3(0, 0.72, 0), Color(0.75, 0.16, 0.2), false)
	_child_box(_arena, Vector3(2.5, 0.12, 2.5), CUBE_LOCAL + Vector3(0, -0.72, 0), Color(0.75, 0.16, 0.2), false)
	# Retired banners in the rafters (decor) and the five fallen ones.
	for i in 6:
		var b := _child_box(_arena, Vector3(0.7, 1.2, 0.04), Vector3(-4.5 + i * 1.8, 5.2, -3.6), Color(0.75, 0.16, 0.2), false)
		var _k3 := b
	for i in BANNERS.size():
		var num: int = BANNERS[i]
		var hoist := Node3D.new()
		hoist.name = "Banner%d" % num
		hoist.position = Vector3(-4.0 + i * 2.0, 0.08, 3.2)
		_arena.add_child(hoist)
		var cloth := _child_box(hoist, Vector3(0.9, 1.4, 0.05), Vector3(0, 0.05, 0), Color(0.75, 0.16, 0.2), false)
		cloth.rotation.x = -PI / 2.0 + 0.05   # lying on the ice
		var lbl := Label3D.new()
		lbl.text = str(num)
		lbl.font_size = 64
		lbl.pixel_size = 0.01
		lbl.modulate = Color(0.98, 0.96, 0.9)
		lbl.position = Vector3(0, 0.1, 0.05)
		lbl.rotation.x = -PI / 2.0
		hoist.add_child(lbl)
		var rope := _child_mesh(hoist, _cyl(0.02, 0.02, 5.0), Vector3(0, 2.6, 0.7), Color(0.6, 0.6, 0.6), false)
		var _k4 := rope
		var plate := BannerPlate.new()
		plate.owner_puzzle = self
		plate.number = num
		plate.prompt = "Hoist the %d banner" % num
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.1
		cs.shape = sph
		plate.add_child(cs)
		hoist.add_child(plate)
		_banner_nodes[num] = {"hoist": hoist, "cloth": cloth, "label": lbl}
	# The penalty box on the west boards, door shut, three panes inside.
	var box := Node3D.new()
	box.name = "PenaltyBox"
	box.position = Vector3(-4.5, 0, -5.4)
	_arena.add_child(box)
	_child_box(box, Vector3(2.4, 1.2, 0.1), Vector3(0, 0.6, -0.5), Color(0.5, 0.5, 0.55), true)
	_child_box(box, Vector3(0.1, 1.2, 1.0), Vector3(-1.2, 0.6, 0), Color(0.5, 0.5, 0.55), true)
	_child_box(box, Vector3(0.1, 1.2, 1.0), Vector3(1.2, 0.6, 0), Color(0.5, 0.5, 0.55), true)
	_box_door = _child_box(box, Vector3(2.4, 1.2, 0.08), Vector3(0, 0.6, 0.5), Color(0.75, 0.8, 0.85, 0.5), true)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.75, 0.8, 0.85, 0.5)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box_door.material_override = dm
	GameState.vocal_used.connect(_on_vocal)
	if GameState.get_flag("three_stars_done"):
		_open_box(true)

func _player_local() -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return Vector3(999, 0, 0)
	return _arena.to_local(player.global_position)

func _on_vocal(kind: String) -> void:
	var lp := _player_local()
	if absf(lp.x) > 8.0 or absf(lp.z) > 8.0:
		return  # not in the building
	if kind == "hiss" and not _zamboni_moved:
		if lp.distance_to(_zamboni.position) < 6.0:
			_zamboni_moved = true
			Sfx.play("robot_flee", 0.8, 0.0, -8.0)
			var t := create_tween()
			t.tween_property(_zamboni, "position", Vector3(4.6, 0, -3.6), 2.2) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.parallel().tween_property(_zamboni, "rotation:y", -0.9, 2.2)
			_flash("The Zamboni flees to the corner, resurfacing as it goes. Machines still hate a hiss. The centre dot is clear.", 4.5)
	elif kind == "growl" and not _awake:
		if lp.distance_to(CENTRE_LOCAL) < 3.5:
			_wake_cube()
		else:
			_flash("The cube hangs dark over the centre dot. Growl from RIGHT under it; big things need to hear you.", 3.5)

func _set_screens(text: String) -> void:
	for lbl in _screen_labels:
		lbl.text = text

func _wake_cube() -> void:
	_awake = true
	Sfx.play("goal_horn", 1.0, 0.0, -4.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.2, 0.24)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.3)
	m.emission_energy_multiplier = 0.4
	_cube.material_override = m
	for screen in _screens:
		var on := StandardMaterial3D.new()
		on.albedo_color = Color(0.12, 0.08, 0.03)
		on.emission_enabled = true
		on.emission = Color(1.0, 0.6, 0.2)
		on.emission_energy_multiplier = 0.35
		screen.material_override = on
	_flash("The cube WAKES. Horn, house lights… and it calls the three stars of the game.", 4.0)
	_call_stars()

## The callout, the way a rink does it: counting DOWN to the first star.
## Three stars over the first number, two over the second, one over the
## last — then the cycle repeats until the banners answer.
func _call_stars() -> void:
	_call_round += 1
	var my := _call_round
	var loop := func() -> void:
		await get_tree().create_timer(2.0).timeout
		while is_inside_tree() and _awake and my == _call_round \
				and not GameState.get_flag("three_stars_done"):
			for i in STARS.size():
				if not is_inside_tree() or my != _call_round \
						or GameState.get_flag("three_stars_done"):
					return
				var stars: String = ["★ ★ ★", "★ ★", "★"][i]
				_set_screens(stars + "\n%d" % STARS[i])
				Sfx.play("bell_ding", 1.0 + 0.1 * i, 0.0, -10.0)
				await get_tree().create_timer(1.8).timeout
			_set_screens("")
			await get_tree().create_timer(1.0).timeout
	loop.call()

func hoist(number: int) -> void:
	if GameState.get_flag("three_stars_done"):
		_flash("The banners hang where the stars said. The building is satisfied.", 3.0)
		return
	if not _awake:
		_flash("The hoist works, but the rafters keep their secret while the cube is dark.", 3.5)
		return
	if number in _hoisted:
		return
	var b: Dictionary = _banner_nodes[number]
	var t := create_tween()
	t.tween_property(b.hoist, "position:y", 3.4, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(b.cloth, "rotation:x", 0.0, 1.2)
	t.parallel().tween_property(b.label, "rotation:x", 0.0, 1.2)
	Sfx.play("wood_creak", 1.2, 0.05, -14.0)
	var expected: int = STARS[_hoisted.size()]
	if number != expected:
		get_tree().create_timer(1.3).timeout.connect(_buzz)
		return
	_hoisted.append(number)
	if _hoisted.size() >= STARS.size():
		get_tree().create_timer(1.3).timeout.connect(_win)

func _buzz() -> void:
	Sfx.play("fail", 0.7, 0.0, -6.0)
	Sfx.play("crowd_groan", 1.0, 0.0, -6.0)
	for num: int in _banner_nodes:
		var b: Dictionary = _banner_nodes[num]
		var t := create_tween()
		t.tween_property(b.hoist, "position:y", 0.08, 0.7).set_trans(Tween.TRANS_BOUNCE)
		t.parallel().tween_property(b.cloth, "rotation:x", -PI / 2.0 + 0.05, 0.7)
		t.parallel().tween_property(b.label, "rotation:x", -PI / 2.0, 0.7)
	_hoisted.clear()
	_flash("BUZZER. Every banner drops and the whole building groans. Not that star, not in that order. The cube calls them again…", 4.5)
	_call_stars()

func _win() -> void:
	GameState.set_flag("three_stars_done")
	_call_round += 1
	Sfx.play("goal_horn", 1.05, 0.0, -4.0)
	Sfx.play("crowd_cheer", 1.0, 0.0, -6.0)
	_set_screens("★ 9\n★ 4\n★ 10")
	_open_box(false)
	_flash("The horn, again, and a crowd that is not there sings OLÉ. The penalty box door swings open: three spare panes of arena glass.", 5.5)
	# And the horn shakes something loose from the rafters…
	var delivery := get_node_or_null("../MmfaDelivery")
	if delivery and delivery.has_method("drop_portrait"):
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			delivery.drop_portrait(true))

func _open_box(instant: bool) -> void:
	var island := get_parent()
	if instant:
		_box_door.rotation.y = 1.4
	else:
		var t := create_tween()
		t.tween_property(_box_door, "rotation:y", 1.4, 0.9).set_trans(Tween.TRANS_BOUNCE)
	if not GameState.get_flag("panes_fitted") and Inventory.count_of("arena_pane") < 3 \
			and island.has_method("_add_pickup"):
		var box: Node3D = _arena.get_node("PenaltyBox")
		for i in 3:
			island._add_pickup(box.global_position + Vector3(-0.6 + i * 0.6, 0.1, 0.0),
					"arena_pane", "Arena Glass Pane", Color(0.8, 0.88, 0.95))

## Test hooks.
func force_zamboni() -> void:
	_zamboni_moved = true

func force_awake() -> void:
	if not _awake:
		_wake_cube()

func _child_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if with_collision:
		mi.create_convex_collision()
	return mi

func _child_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, with_collision := true) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _child_mesh(parent, box, pos, color, with_collision)

func _cyl(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)
