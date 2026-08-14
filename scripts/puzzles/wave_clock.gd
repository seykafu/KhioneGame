extends Node3D
## Island 5, Riddle 1 — The Wave Clock.
## The cove's tide runs a fixed Fundy loop: three small swells, one big
## bore. Stepping stones to the golf shelf only stand clear between big
## waves. But swimming ONTO the bore rides it: it carries her north and
## beaches her on the wharf's net loft — and once the storm gate is
## open and the Santa Maria floats, the same ride lands her on deck.

## The stones cross the cove from the wharf's east hip to the shelf.
const STONES: Array[Vector3] = [
	Vector3(4.2, 0.0, 30.5), Vector3(7.0, 0.0, 28.6), Vector3(9.8, 0.0, 27.0),
	Vector3(12.8, 0.0, 25.6), Vector3(15.8, 0.0, 24.4), Vector3(18.6, 0.0, 23.2),
]
const LOFT_LANDING := Vector3(-3.5, 3.8, 30.6)
const DECK_LANDING_LOCAL := Vector3(0, 2.5, 1.0)  # on the Santa Maria

var _riding := false
var _stones: Array[MeshInstance3D] = []

func _ready() -> void:
	var island := get_parent()
	for s: Vector3 in STONES:
		var stone := MeshInstance3D.new()
		stone.mesh = _stone_mesh()
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.5, 0.51, 0.53)
		m.roughness = 0.9
		stone.material_override = m
		stone.position = Vector3(s.x, island.WATER_SURFACE_Y + 0.18, s.z)
		add_child(stone)
		stone.create_convex_collision()
		_stones.append(stone)
	# The bag of range balls waits on the net loft: bore-ride only.
	if island.has_method("_add_pickup"):
		island._add_pickup(LOFT_LANDING + Vector3(0, -0.35, 0), "golf_balls",
				"Bag of Range Balls", Color(0.93, 0.92, 0.9))

func _stone_mesh() -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.75
	c.bottom_radius = 0.9
	c.height = 0.5
	return c

func _process(_delta: float) -> void:
	if _riding:
		return
	var island := get_parent()
	if not island.is_bore():
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null or int(player.get("_water_zones")) < 1:
		return  # she has to be swimming to catch the wave
	# Swimming in the cove as the ridge passes: the bore takes her.
	var p := player.global_position
	var in_cove := absf(p.x - island.COVE_CENTER.x) < 11.0 \
			and absf(p.z - island.COVE_CENTER.y) < 12.0
	if in_cove and absf(p.z - island.bore_ridge_z()) < 2.6:
		_ride(player, island)

func _ride(player: Node3D, island: Node) -> void:
	_riding = true
	player.set("controls_enabled", false)
	player.set_physics_process(false)
	Sfx.play("wave_crash", 1.0, 0.0, -6.0)
	# Deck landing when the storm bore runs and the ship floats and she
	# started east of the wharf; the loft otherwise.
	var to_deck: bool = island.is_storm() and GameState.get_flag("ship_afloat") \
			and player.global_position.x > 6.0
	var target: Vector3
	if to_deck:
		target = (island.ship as Node3D).to_global(DECK_LANDING_LOCAL)
	else:
		target = LOFT_LANDING
	var from := player.global_position
	var crest := from + Vector3(0, island.bore_amplitude() + 0.5, 0)
	var t := create_tween()
	t.tween_property(player, "global_position", crest, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(player, "global_position", target + Vector3(0, 0.4, 0), 1.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func() -> void:
		player.set_physics_process(true)
		player.set("controls_enabled", true)
		Sfx.play("land", 1.0, 0.05, -12.0)
		_riding = false
		if to_deck:
			GameState.set_flag("boarded_ship")
			_flash("The bore sets her down on the Santa Maria's deck, light as spray.", 4.0)
		elif not GameState.get_flag("rode_the_bore"):
			GameState.set_flag("rode_the_bore")
			_flash("The wave was never the obstacle. The wave is the elevator.", 4.5))

## The finale's storm tide swallows the stones so the Santa Maria sails
## a clean corridor (the pirate test sweeps the route after this).
func submerge_stones() -> void:
	for stone in _stones:
		var t := stone.create_tween()
		t.tween_property(stone, "position:y", stone.position.y - 1.6, 1.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Test hook: ride without waiting on the clock.
func force_ride() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player:
		_ride(player, get_parent())

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)
