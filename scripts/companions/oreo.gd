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
var _body: MeshInstance3D
var _ear_l: Node3D
var _ear_r: Node3D
var _hips: Array[Node3D] = []  # FL, FR, BL, BR pivots — legs swing from the hip
var _run_phase := 0.0
var _cur_speed := 0.0     # eased, so strides build and settle smoothly
var _chasing := false     # hysteresis so he doesn't stutter at the follow edge
var _hopping := false
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
	_body = MeshInstance3D.new()
	var bc := CapsuleMesh.new()
	bc.radius = 0.23
	bc.height = 0.9
	_body.mesh = bc
	_body.material_override = black
	_body.rotation.x = PI / 2.0
	_body.position = Vector3(0, 0.44, 0)
	add_child(_body)
	var chest := MeshInstance3D.new()
	var cc := SphereMesh.new()
	cc.radius = 0.17
	cc.height = 0.32
	chest.mesh = cc
	chest.material_override = white
	chest.position = Vector3(0, 0.37, 0.32)
	add_child(chest)
	# A soft white ruff where the neck meets the shoulders.
	var ruff := MeshInstance3D.new()
	var rs := SphereMesh.new()
	rs.radius = 0.15
	rs.height = 0.26
	ruff.mesh = rs
	ruff.material_override = white
	ruff.position = Vector3(0, 0.56, 0.3)
	add_child(ruff)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.18
	hs.height = 0.34
	head.mesh = hs
	head.material_override = black
	head.position = Vector3(0, 0.7, 0.44)
	add_child(head)
	# The blaze: a white stripe up the forehead, wider at the muzzle.
	var blaze := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.06, 0.2, 0.14)
	blaze.mesh = bb
	blaze.material_override = white
	blaze.position = Vector3(0, 0.77, 0.53)
	blaze.rotation.x = -0.35
	add_child(blaze)
	# Rounded muzzle in two steps, black nose, a hint of tongue.
	var muzzle := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(0.14, 0.11, 0.12)
	muzzle.mesh = mb
	muzzle.material_override = white
	muzzle.position = Vector3(0, 0.63, 0.56)
	add_child(muzzle)
	var snout := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.1, 0.085, 0.09)
	snout.mesh = sb
	snout.material_override = white
	snout.position = Vector3(0, 0.625, 0.64)
	add_child(snout)
	var nose := MeshInstance3D.new()
	var ns := SphereMesh.new()
	ns.radius = 0.034
	ns.height = 0.06
	nose.mesh = ns
	nose.material_override = black
	nose.position = Vector3(0, 0.655, 0.685)
	add_child(nose)
	var tongue := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.05, 0.012, 0.09)
	tongue.mesh = tb
	tongue.material_override = _m(Color(0.9, 0.5, 0.55))
	tongue.position = Vector3(0.015, 0.578, 0.63)
	tongue.rotation.x = 0.3
	add_child(tongue)
	# Cheek fluff.
	for s in [-1.0, 1.0]:
		var cheek := MeshInstance3D.new()
		var chs2 := SphereMesh.new()
		chs2.radius = 0.06
		chs2.height = 0.11
		cheek.mesh = chs2
		cheek.material_override = white
		cheek.position = Vector3(s * 0.1, 0.64, 0.52)
		add_child(cheek)
	# One blue eye, one brown, each set on a small white patch: his signature.
	for def: Array in [[-0.078, Color(0.35, 0.6, 0.85)], [0.078, Color(0.4, 0.28, 0.18)]]:
		var patch := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.036
		ps.height = 0.06
		patch.mesh = ps
		patch.material_override = white
		patch.position = Vector3(def[0], 0.725, 0.565)
		add_child(patch)
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.022
		es.height = 0.044
		eye.mesh = es
		eye.material_override = _m(def[1])
		eye.position = Vector3(def[0], 0.727, 0.595)
		add_child(eye)
	# Ears: pivots so moods can droop them; pink inner faces.
	_ear_l = _ear(-0.11)
	_ear_r = _ear(0.11)
	# Legs swing from hip pivots: the trot animates these, not the meshes.
	for def: Vector2 in [Vector2(-0.13, 0.3), Vector2(0.13, 0.3), Vector2(-0.13, -0.26), Vector2(0.13, -0.26)]:
		var hip := Node3D.new()
		hip.position = Vector3(def.x, 0.32, def.y)
		add_child(hip)
		_hips.append(hip)
		var leg := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.048
		lc.bottom_radius = 0.04
		lc.height = 0.3
		leg.mesh = lc
		leg.material_override = black
		leg.position = Vector3(0, -0.15, 0)
		hip.add_child(leg)
		var sock := MeshInstance3D.new()
		var sc := CylinderMesh.new()
		sc.top_radius = 0.042
		sc.bottom_radius = 0.048
		sc.height = 0.09
		sock.mesh = sc
		sock.material_override = white
		sock.position = Vector3(0, -0.28, 0)
		hip.add_child(sock)
	# The tail: a curved plume arcing up to a white tip, on the wag pivot.
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.5, -0.44)
	add_child(_tail)
	# Segments overlap into one arc that rises and curls back.
	for def: Array in [
		[Vector3(0, 0.05, -0.03), -0.45, 0.055, Color(0.12, 0.12, 0.14)],
		[Vector3(0, 0.15, -0.09), -0.85, 0.048, Color(0.12, 0.12, 0.14)],
		[Vector3(0, 0.22, -0.17), -1.25, 0.042, Color(0.93, 0.93, 0.9)],
	]:
		var seg := MeshInstance3D.new()
		var tc := CapsuleMesh.new()
		tc.radius = def[2]
		tc.height = 0.22
		seg.mesh = tc
		seg.material_override = _m(def[3])
		seg.position = def[0]
		seg.rotation.x = def[1]
		_tail.add_child(seg)
	var plume := MeshInstance3D.new()
	var pls := SphereMesh.new()
	pls.radius = 0.058
	pls.height = 0.11
	plume.mesh = pls
	plume.material_override = white
	plume.position = Vector3(0, 0.25, -0.25)
	_tail.add_child(plume)
	# The collar with its paw charm, and no name at all.
	var collar := MeshInstance3D.new()
	var col := TorusMesh.new()
	col.inner_radius = 0.13
	col.outer_radius = 0.17
	collar.mesh = col
	collar.material_override = _m(Color(0.55, 0.3, 0.25))
	collar.position = Vector3(0, 0.57, 0.37)
	collar.rotation.x = 0.5
	add_child(collar)
	var charm := MeshInstance3D.new()
	var chs := SphereMesh.new()
	chs.radius = 0.035
	chs.height = 0.07
	charm.mesh = chs
	charm.material_override = _m(Color(0.8, 0.68, 0.35))
	charm.position = Vector3(0, 0.47, 0.43)
	add_child(charm)

func _ear(x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 0.85, 0.42)
	pivot.rotation.z = -signf(x) * 0.14  # a light outward tilt
	add_child(pivot)
	var ear := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.1, 0.16, 0.06)
	ear.mesh = prism
	ear.material_override = _m(Color(0.12, 0.12, 0.14))
	ear.position = Vector3(0, 0.06, 0)
	pivot.add_child(ear)
	var inner := MeshInstance3D.new()
	var ip := PrismMesh.new()
	ip.size = Vector3(0.05, 0.09, 0.03)
	inner.mesh = ip
	inner.material_override = _m(Color(0.85, 0.55, 0.55))
	inner.position = Vector3(0, 0.04, 0.022)
	pivot.add_child(inner)
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
	if _hopping:
		return
	_hopping = true
	var t := create_tween()
	t.tween_property(self, "position:y", position.y + 0.35, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", position.y, 0.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: _hopping = false)

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
		if player:
			var to_player := Vector2(player.global_position.x - global_position.x,
					player.global_position.z - global_position.z).length()
			# Hysteresis: start chasing well outside the heel ring, stop well
			# inside it, so he never stutters on the boundary.
			if to_player > FOLLOW_DIST + 0.6:
				_chasing = true
			elif to_player < CATCH_UP_DIST:
				_chasing = false
			if _chasing:
				var dir := Vector2(global_position.x - player.global_position.x,
						global_position.z - player.global_position.z).normalized()
				target = player.global_position \
						+ Vector3(dir.x, 0, dir.y) * CATCH_UP_DIST
	if target == Vector3.INF:
		_settle(delta)
		return
	var flat := Vector2(target.x - global_position.x, target.z - global_position.z)
	if flat.length() < 0.25:
		if _move_target != Vector3.INF:
			_move_target = Vector3.INF
		_settle(delta)
		return
	# Far behind? Border collies do not do "far behind."
	if following and _move_target == Vector3.INF and flat.length() > 30.0:
		global_position.x = target.x
		global_position.z = target.z
		return
	var want_speed := clampf(RUN_SPEED + (flat.length() - 4.0) * 1.2, RUN_SPEED, 11.0)
	_cur_speed = lerpf(_cur_speed, want_speed, minf(6.0 * delta, 1.0))
	var step := flat.normalized() * minf(_cur_speed * delta, flat.length())
	global_position.x += step.x
	global_position.z += step.y
	rotation.y = lerp_angle(rotation.y, atan2(step.x, step.y), minf(8.0 * delta, 1.0))
	# The trot: diagonal leg pairs swing opposite ways from the hip, the
	# body rides a soft double-beat bounce and rocks a little, and it all
	# eases out again at rest.
	_run_phase += delta * (6.0 + _cur_speed * 0.6)
	for i in _hips.size():
		var phase := _run_phase + (0.0 if i == 0 or i == 3 else PI)
		_hips[i].rotation.x = sin(phase) * 0.6
	_body.rotation.z = sin(_run_phase) * 0.05
	_tail.rotation.x = -0.12 + sin(_run_phase * 0.5) * 0.08  # tail rides the gait
	if not _hopping:
		global_position.y = maxf(_ground_at(global_position), 0.0) \
				+ pow(absf(sin(_run_phase)), 2.0) * 0.05

func _settle(delta: float) -> void:
	# At rest: legs straighten under the hips, the body levels, and he
	# eases down onto the grass.
	_cur_speed = lerpf(_cur_speed, 0.0, minf(6.0 * delta, 1.0))
	for hip in _hips:
		hip.rotation.x = lerpf(hip.rotation.x, 0.0, minf(12.0 * delta, 1.0))
	_body.rotation.z = lerpf(_body.rotation.z, 0.0, minf(10.0 * delta, 1.0))
	_tail.rotation.x = lerpf(_tail.rotation.x, 0.0, minf(6.0 * delta, 1.0))
	if not _hopping:
		var ground := maxf(_ground_at(global_position), 0.0)
		global_position.y = lerpf(global_position.y, ground, minf(10.0 * delta, 1.0))

func _ground_at(pos: Vector3) -> float:
	if _island and _island.has_method("_terrain_height"):
		return _island._terrain_height(pos.x, pos.z)
	return 0.35

func _m(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m
