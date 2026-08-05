extends Node3D
## Oreo: border collie, one blue eye, heart of gold. Built from primitives
## in the game's low-poly language. Sits tangled until freed; once he joins
## he follows Khione everywhere and answers every meow with a bark, always,
## instantly, joyfully.

const FOLLOW_DIST := 2.2
const CATCH_UP_DIST := 1.7
const RUN_SPEED := 4.8

var following := false
var _island: Node3D
var _tail: Node3D
var _ear_l: Node3D
var _ear_r: Node3D
var _run_phase := 0.0
var _move_target := Vector3.INF  # scripted move (fetch, canoe) overrides follow

func _ready() -> void:
	add_to_group("oreo")
	_island = get_parent()
	_build_dog()
	GameState.vocal_used.connect(_on_vocal)
	var wag := _tail.create_tween().set_loops()
	wag.tween_property(_tail, "rotation:y", 0.55, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wag.tween_property(_tail, "rotation:y", -0.55, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_dog() -> void:
	var black := _m(Color(0.12, 0.12, 0.14))
	var white := _m(Color(0.93, 0.93, 0.9))
	var body := MeshInstance3D.new()
	var bc := CapsuleMesh.new()
	bc.radius = 0.22
	bc.height = 0.85
	body.mesh = bc
	body.material_override = black
	body.rotation.x = PI / 2.0
	body.position = Vector3(0, 0.42, 0)
	add_child(body)
	var chest := MeshInstance3D.new()
	var cc := SphereMesh.new()
	cc.radius = 0.16
	cc.height = 0.3
	chest.mesh = cc
	chest.material_override = white
	chest.position = Vector3(0, 0.36, 0.3)
	add_child(chest)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.17
	hs.height = 0.32
	head.mesh = hs
	head.material_override = black
	head.position = Vector3(0, 0.66, 0.42)
	add_child(head)
	var blaze := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.07, 0.18, 0.12)
	blaze.mesh = bb
	blaze.material_override = white
	blaze.position = Vector3(0, 0.7, 0.52)
	blaze.rotation.x = -0.3
	add_child(blaze)
	var muzzle := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(0.12, 0.09, 0.14)
	muzzle.mesh = mb
	muzzle.material_override = white
	muzzle.position = Vector3(0, 0.6, 0.56)
	add_child(muzzle)
	var nose := MeshInstance3D.new()
	var ns := SphereMesh.new()
	ns.radius = 0.03
	ns.height = 0.06
	nose.mesh = ns
	nose.material_override = black
	nose.position = Vector3(0, 0.62, 0.64)
	add_child(nose)
	# One blue eye, one brown: his signature.
	for def: Array in [[-0.07, Color(0.35, 0.6, 0.85)], [0.07, Color(0.4, 0.28, 0.18)]]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.025
		es.height = 0.05
		eye.mesh = es
		eye.material_override = _m(def[1])
		eye.position = Vector3(def[0], 0.71, 0.55)
		add_child(eye)
	# Ears: pivots so moods can droop them.
	_ear_l = _ear(-0.1)
	_ear_r = _ear(0.1)
	# Legs with white socks.
	for def: Vector2 in [Vector2(-0.12, 0.28), Vector2(0.12, 0.28), Vector2(-0.12, -0.24), Vector2(0.12, -0.24)]:
		var leg := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.045
		lc.bottom_radius = 0.04
		lc.height = 0.3
		leg.mesh = lc
		leg.material_override = black
		leg.position = Vector3(def.x, 0.15, def.y)
		add_child(leg)
		var sock := MeshInstance3D.new()
		var sc := CylinderMesh.new()
		sc.top_radius = 0.042
		sc.bottom_radius = 0.045
		sc.height = 0.08
		sock.mesh = sc
		sock.material_override = white
		sock.position = Vector3(def.x, 0.04, def.y)
		add_child(sock)
	# The tail: black with a white tip, on a wag pivot.
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.5, -0.42)
	add_child(_tail)
	var tail_mesh := MeshInstance3D.new()
	var tc := CapsuleMesh.new()
	tc.radius = 0.05
	tc.height = 0.34
	tail_mesh.mesh = tc
	tail_mesh.material_override = black
	tail_mesh.rotation.x = 1.1
	tail_mesh.position = Vector3(0, 0.06, -0.12)
	_tail.add_child(tail_mesh)
	var tip := MeshInstance3D.new()
	var tps := SphereMesh.new()
	tps.radius = 0.05
	tps.height = 0.1
	tip.mesh = tps
	tip.material_override = white
	tip.position = Vector3(0, 0.14, -0.24)
	_tail.add_child(tip)
	# The collar with its paw charm, and no name at all.
	var collar := MeshInstance3D.new()
	var col := TorusMesh.new()
	col.inner_radius = 0.13
	col.outer_radius = 0.17
	collar.mesh = col
	collar.material_override = _m(Color(0.55, 0.3, 0.25))
	collar.position = Vector3(0, 0.56, 0.36)
	collar.rotation.x = 0.5
	add_child(collar)
	var charm := MeshInstance3D.new()
	var chs := SphereMesh.new()
	chs.radius = 0.035
	chs.height = 0.07
	charm.mesh = chs
	charm.material_override = _m(Color(0.8, 0.68, 0.35))
	charm.position = Vector3(0, 0.46, 0.42)
	add_child(charm)

func _ear(x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 0.8, 0.38)
	add_child(pivot)
	var ear := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.09, 0.14, 0.05)
	ear.mesh = prism
	ear.material_override = _m(Color(0.12, 0.12, 0.14))
	ear.position = Vector3(0, 0.05, 0)
	pivot.add_child(ear)
	return pivot

func set_ears_droop(droop: bool) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_ear_l, "rotation:x", 1.1 if droop else 0.0, 0.35)
	t.tween_property(_ear_r, "rotation:x", 1.1 if droop else 0.0, 0.35)

func shake_free() -> void:
	var t := create_tween()
	for i in 5:
		t.tween_property(self, "rotation:z", 0.14 * (1 if i % 2 == 0 else -1), 0.08)
	t.tween_property(self, "rotation:z", 0.0, 0.1)
	set_ears_droop(false)

func hop() -> void:
	var t := create_tween()
	t.tween_property(self, "position:y", position.y + 0.35, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", position.y, 0.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func move_to(target: Vector3) -> void:
	_move_target = target

func arrived() -> bool:
	return _move_target == Vector3.INF

func _on_vocal(kind: String) -> void:
	if kind != "meow" or not GameState.get_flag("oreo_joined"):
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and player.global_position.distance_to(global_position) < 25.0:
		Sfx.play("bark", randf_range(0.95, 1.1), 0.02, -6.0)
		hop()

func _process(delta: float) -> void:
	var target := Vector3.INF
	if _move_target != Vector3.INF:
		target = _move_target
	elif following:
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player and Vector2(player.global_position.x - global_position.x,
				player.global_position.z - global_position.z).length() > FOLLOW_DIST:
			var dir3 := (global_position - player.global_position).normalized()
			target = player.global_position + dir3 * CATCH_UP_DIST
	if target == Vector3.INF:
		return
	var flat := Vector2(target.x - global_position.x, target.z - global_position.z)
	if flat.length() < 0.25:
		if _move_target != Vector3.INF:
			_move_target = Vector3.INF
		return
	# Far behind? Border collies do not do "far behind."
	if following and _move_target == Vector3.INF and flat.length() > 30.0:
		global_position.x = target.x
		global_position.z = target.z
		return
	var speed := clampf(RUN_SPEED + (flat.length() - 4.0) * 1.2, RUN_SPEED, 11.0)
	var step := flat.normalized() * minf(speed * delta, flat.length())
	global_position.x += step.x
	global_position.z += step.y
	rotation.y = atan2(step.x, step.y)
	_run_phase += delta * 11.0
	var ground := 0.35
	if _island and _island.has_method("_terrain_height"):
		ground = _island._terrain_height(global_position.x, global_position.z)
	global_position.y = maxf(ground, 0.0) + absf(sin(_run_phase)) * 0.09

func _m(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m
