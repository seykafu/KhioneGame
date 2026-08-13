extends Node3D
## Island 4, Riddle 2 — The Backyard Rink.
## An old puck waits on the ice. Bump it and it slides until it hits the
## boards… which is never where the painted target circle is. Snow will
## not pack on ice, but a border collie on a "stay" is the proudest bumper
## alive: meow while standing on the rink and Oreo sits exactly there.
## Park the puck on the circle and the ice cracks open its little vault.

const RINK_ORIGIN := Vector3(-10.0, 0.35, 2.0)
const BOUNDS_MIN := Vector2(-13.25, -0.25)  # inside face of the boards
const BOUNDS_MAX := Vector2(-6.75, 4.25)
const ICE_Y := 0.53
const TARGET := Vector3(-7.6, 0.45, 4.0)
const TARGET_R := 0.5
const PUCK_START := Vector3(-12.5, 0.53, 0.5)

var _puck: MeshInstance3D
var _sliding := false
var _materials := {}

class PuckPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Bump the old puck"

	func interact(player: Node) -> void:
		owner_puzzle.bump_puck(player)

func _ready() -> void:
	# The target circle, painted under the ice, and its little drain vault.
	var circle := _add_mesh(_cyl(TARGET_R, TARGET_R, 0.02), TARGET, Color(0.3, 0.45, 0.7, 0.55), false)
	circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puck = _add_mesh(_cyl(0.2, 0.2, 0.11), PUCK_START, Color(0.12, 0.12, 0.14), false)
	var plate := PuckPlate.new()
	plate.owner_puzzle = self
	plate.position = Vector3(0, 0.5, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.3
	cs.shape = sph
	plate.add_child(cs)
	_puck.add_child(plate)
	# Meow on the ice = "stay" mark for Oreo.
	GameState.vocal_used.connect(_on_vocal)

func _on_vocal(kind: String) -> void:
	if kind != "meow" or GameState.get_flag("rink_done") \
			or not GameState.get_flag("oreo_joined"):
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null or not _on_ice(Vector2(player.global_position.x, player.global_position.z)):
		return
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	if oreo == null:
		return
	var spot := Vector3(clampf(player.global_position.x, BOUNDS_MIN.x + 0.4, BOUNDS_MAX.x - 0.4),
			ICE_Y - 0.15, clampf(player.global_position.z, BOUNDS_MIN.y + 0.4, BOUNDS_MAX.y - 0.4))
	oreo.stay_at(spot)
	_flash("Oreo trots onto the ice and SITS where she stood. Immovable. Extremely proud of himself.", 4.0)

func _on_ice(p: Vector2) -> bool:
	return p.x > BOUNDS_MIN.x - 0.3 and p.x < BOUNDS_MAX.x + 0.3 \
			and p.y > BOUNDS_MIN.y - 0.3 and p.y < BOUNDS_MAX.y + 0.3

func bump_puck(player: Node) -> void:
	if _sliding or GameState.get_flag("rink_done"):
		return
	# The push goes away from her, snapped to the stronger axis.
	var away := _puck.global_position - (player as Node3D).global_position
	var dir := Vector2.RIGHT
	if absf(away.x) >= absf(away.z):
		dir = Vector2(signf(away.x), 0)
	else:
		dir = Vector2(0, signf(away.z))
	var from := Vector2(_puck.position.x, _puck.position.z)
	var stop := _slide_stop(from, dir)
	if stop.distance_to(from) < 0.05:
		_flash("The puck is already against something that way.", 2.0)
		return
	_sliding = true
	Sfx.play("stone_slide", 1.6, 0.05, -14.0)
	var t := create_tween()
	t.tween_property(_puck, "position", Vector3(stop.x, ICE_Y, stop.y),
			clampf(stop.distance_to(from) * 0.16, 0.25, 1.1)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		_sliding = false
		_check_target())

func _slide_stop(from: Vector2, dir: Vector2) -> Vector2:
	# Slide to the boards, unless Oreo holds his ground in the lane.
	var stop := from
	if dir.x > 0:
		stop.x = BOUNDS_MAX.x - 0.2
	elif dir.x < 0:
		stop.x = BOUNDS_MIN.x + 0.2
	elif dir.y > 0:
		stop.y = BOUNDS_MAX.y - 0.2
	else:
		stop.y = BOUNDS_MIN.y + 0.2
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	if oreo and oreo.get("_stay"):
		var op := Vector2(oreo.global_position.x, oreo.global_position.z)
		var lane := absf(op.y - from.y) < 0.55 if dir.x != 0.0 else absf(op.x - from.x) < 0.55
		if lane:
			var ahead := (op - from).dot(dir) > 0.2
			if ahead:
				var blocked := op - dir * 0.75
				# Only if the dog is nearer than the boards.
				if blocked.distance_to(from) < stop.distance_to(from):
					stop = blocked
	return stop

func _check_target() -> void:
	var flat := Vector2(_puck.position.x, _puck.position.z)
	if flat.distance_to(Vector2(TARGET.x, TARGET.z)) > TARGET_R:
		return
	GameState.set_flag("rink_done")
	Sfx.play("crab_snip", 0.7, 0.05, -10.0)
	Sfx.play("drain", 1.2, 0.0, -10.0)
	# The ice cracks a neat ring and the little vault under it pops open.
	var crack := _add_mesh(_cyl(TARGET_R + 0.15, TARGET_R + 0.15, 0.015),
			TARGET + Vector3(0, 0.02, 0), Color(0.85, 0.92, 0.98), false)
	crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var island := get_parent()
	if island.has_method("_add_pickup"):
		island._add_pickup(TARGET + Vector3(0, 0.1, -0.6), "runner_wax", "Runner Wax",
				Color(0.85, 0.6, 0.3))
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	if oreo:
		oreo.resume()
	_flash("The puck settles dead centre, the ice cracks a polite ring, and a tin of runner wax bobs up. Good bumper. The best bumper.", 5.5)

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
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[color] = m
	return _materials[color]

func _cyl(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c

func _add_mesh(mesh: Mesh, pos: Vector3, color: Color, with_collision := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
	if with_collision:
		# Convex, never trimesh: trimesh shells are hollow and trap the cat.
		mi.create_convex_collision()
	return mi
