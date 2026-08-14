extends Node3D
## Island 5, Main riddle — Float the Santa Maria.
## Phase 1: the spigot wheel floods the drydock; the ship rights herself.
## Phase 2: a growl startles the boathouse pelican off the STORM GATE
## lever; the bore runs a tier higher, and riding it lands her on deck.
## Phase 3: broadside-cracked rust plus a capstan duet raises the anchor.
## Phase 4: the parrot takes the wheel-perch, the sails drop, and the
## Santa Maria surfs the bore straight out the cove's mouth onto open
## Atlantic. The single loudest exit in the game.

const SPIGOT_POS := Vector3(13.0, 0.5, 12.0)
const CAPSTAN_BEATS := 6
## The departure: drydock, down the cove's throat, out the mouth, gone.
## tools/test_pirate.gd sweeps this corridor (after the stones submerge).
const SAIL_ROUTE: Array[Vector3] = [
	Vector3(13.0, -0.9, 18.0), Vector3(11.0, -0.85, 28.0), Vector3(8.5, -0.8, 40.0),
	Vector3(6.5, -0.78, 54.0), Vector3(5.5, -0.75, 70.0), Vector3(5.0, -0.75, 84.0),
]

var _capstan_beat := 0
var _capstan_running := false
var _departing := false

class SpigotPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Fit the spigot"

	func interact(_player: Node) -> void:
		owner_puzzle.try_spigot()

class CapstanPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Man the capstan"

	func interact(_player: Node) -> void:
		owner_puzzle.try_capstan()

class HelmPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Take the wheel"

	func interact(_player: Node) -> void:
		owner_puzzle.try_helm()

func _ready() -> void:
	var island := get_parent()
	var spigot := SpigotPlate.new()
	spigot.owner_puzzle = self
	spigot.position = SPIGOT_POS
	_zone(spigot, 2.0)
	add_child(spigot)
	var cap := CapstanPlate.new()
	cap.owner_puzzle = self
	cap.position = Vector3.ZERO
	_zone(cap, 1.8)
	(island.capstan as Node3D).add_child(cap)
	var hel := HelmPlate.new()
	hel.owner_puzzle = self
	hel.position = Vector3(0, 0.3, 0.8)
	_zone(hel, 1.6)
	(island.helm as Node3D).add_child(hel)
	GameState.vocal_used.connect(_on_vocal)

# --- Phase 1: the flood ---

func try_spigot() -> void:
	if GameState.get_flag("ship_afloat"):
		_flash("The drydock brims; the Santa Maria rides her lines, remembering how.", 3.5)
		return
	if not Inventory.has_item("spigot_wheel"):
		_flash("A bare spigot stem, wheel long gone. Something brass glinted behind that sea-cave grate…", 4.5)
		return
	Inventory.remove_item("spigot_wheel")
	GameState.set_flag("ship_afloat")
	Sfx.play("stone_slide", 0.8, 0.0, -8.0)
	Sfx.play("splash", 0.8, 0.0, -8.0)
	var island := get_parent()
	var dock_water: MeshInstance3D = island.dock_water
	dock_water.visible = true
	dock_water.position.y = -1.35
	var ship: Node3D = island.ship
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(dock_water, "position:y", island.WATER_SURFACE_Y + 0.02, 5.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(ship, "rotation:z", 0.0, 5.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(ship, "position:y", -0.9, 5.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.chain().tween_callback(func() -> void:
		Sfx.play("ship_groan", 1.0, 0.0, -8.0)
		_flash("The dock drinks the sea and the Santa Maria ROLLS UPRIGHT, groaning awake. Her deck still rides ten feet up.", 5.5))

# --- Phase 2: the storm gate ---

func _on_vocal(kind: String) -> void:
	if kind != "growl" or GameState.get_flag("storm_gate_open"):
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var island := get_parent()
	var house: Node3D = island.get_node_or_null("Boathouse")
	if player == null or house == null:
		return
	if player.global_position.distance_to(house.global_position) > 8.0:
		return
	GameState.set_flag("storm_gate_open")
	island.set_storm(true)
	Sfx.play("parrot_squawk", 0.6, 0.0, -8.0)
	var pelican: Node3D = house.get_node_or_null("Pelican")
	if pelican:
		var flap := create_tween()
		flap.tween_property(pelican, "position", pelican.position + Vector3(1.5, 3.5, 1.0), 0.9) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var lever: Node3D = house.get_node_or_null("StormLever")
	if lever:
		var drop := create_tween()
		drop.tween_property(lever, "rotation:x", 0.9, 0.5).set_trans(Tween.TRANS_BOUNCE)
	Sfx.play("wave_crash", 0.8, 0.0, -6.0)
	_flash("The pelican departs INDIGNANT and the STORM GATE lever slams home. Out in the cove, the next bore stands a whole tier taller.", 5.5)

# --- Phase 3: the capstan duet ---

func try_capstan() -> void:
	if GameState.get_flag("anchor_up"):
		_flash("The anchor is catted and snug. The wheel is waiting.", 3.0)
		return
	if not GameState.get_flag("broadside_done"):
		Sfx.play("capstan_clank", 0.7, 0.0, -12.0)
		_flash("The capstan strains: the anchor chain is one solid sleeve of rust. Cannon-fire has cracked worse.", 4.5)
		return
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	if oreo == null:
		_flash("This drum wants four paws and eight. Where is that dog?", 3.5)
		return
	if _capstan_running:
		return
	_capstan_running = true
	_capstan_beat = 0
	var island := get_parent()
	oreo.set("scripted", true)
	oreo.global_position = (island.capstan as Node3D).global_position + Vector3(-1.1, 0.0, 0)
	oreo.rotation.y = PI / 2.0
	_flash("Shoulder to the bars, the two of them. Push with the rhythm: [E], on the clank.", 4.0)
	_capstan_tick()

func _capstan_tick() -> void:
	if _capstan_beat >= CAPSTAN_BEATS:
		_capstan_done()
		return
	Sfx.play("capstan_clank", 1.0 + 0.05 * _capstan_beat, 0.0, -10.0)
	var island := get_parent()
	var spin := create_tween()
	spin.tween_property(island.capstan, "rotation:y",
			(island.capstan as Node3D).rotation.y + PI / 4.0, 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_capstan_beat += 1
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if _capstan_running:
			_capstan_tick())

func _capstan_done() -> void:
	_capstan_running = false
	GameState.set_flag("anchor_up")
	var island := get_parent()
	var rig: Node3D = island.anchor_rig
	if rig:
		var up := create_tween()
		up.tween_property(rig, "position:y", rig.position.y + 1.1, 1.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Sfx.play("pickup_chime", 1.1, 0.0, -8.0)
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	if oreo:
		oreo.set("scripted", false)
	_flash("UP SHE COMES, shedding cracked rust like confetti. The Santa Maria swings free on her lines.", 5.0)

# --- Phase 4: the departure ---

func try_helm() -> void:
	if _departing:
		return
	if not GameState.get_flag("anchor_up"):
		_flash("The wheel turns; the ship does not. She is still pinned by the hook below.", 3.5)
		return
	_departing = true
	_depart()

func _depart() -> void:
	var island := get_parent()
	var ship: Node3D = island.ship
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	if player == null:
		_departing = false
		return
	player.set("controls_enabled", false)
	player.set_physics_process(false)
	if oreo:
		oreo.set("following", false)
		oreo.set("scripted", true)
	# The storm tide swallows the stepping stones before she sails.
	var wave_clock := get_node_or_null("../WaveClock")
	if wave_clock and wave_clock.has_method("submerge_stones"):
		wave_clock.submerge_stones()
	# The parrot takes the wheel-perch; the sails drop.
	var parrot: Node3D = (island.crow_nest as Node3D).get_node_or_null("Parrot")
	if parrot:
		var hop := create_tween()
		hop.tween_property(parrot, "global_position",
				(island.helm as Node3D).global_position + Vector3(0, 0.9, 0), 1.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Sfx.play("parrot_squawk", 1.0, 0.0, -8.0)
	for md: Array in [[Vector3(0, 0, 3.4), 6.5], [Vector3(0, 0, -0.6), 8.6], [Vector3(0, 0, -4.4), 5.8]]:
		var h: float = md[1]
		var sheet := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(3.0, 2.4, 0.08)
		sheet.mesh = sb
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.9, 0.87, 0.78)
		sheet.material_override = sm
		sheet.position = (md[0] as Vector3) + Vector3(0, 2.0 + h * 0.72 - 1.3, 0)
		sheet.scale = Vector3(1.0, 0.04, 1.0)
		ship.add_child(sheet)
		var un := create_tween()
		un.tween_property(sheet, "scale:y", 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Sfx.play("wave_crash", 0.9, 0.0, -4.0)
	Sfx.play("ship_groan", 0.9, 0.0, -6.0)
	# Chase camera and the surf south.
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var pts := SAIL_ROUTE
	var ride := create_tween()
	var step := func(u: float) -> void:
		var f := u * (pts.size() - 1)
		var i := clampi(int(f), 0, pts.size() - 2)
		var pos := (pts[i] as Vector3).lerp(pts[i + 1], f - i)
		pos.y += 0.12 * sin(u * 14.0)   # riding the swell
		ship.global_position = pos
		var nxt: Vector3 = pts[mini(i + 2, pts.size() - 1)]
		var dir := (Vector3(nxt.x, 0, nxt.z) - Vector3(pos.x, 0, pos.z)).normalized()
		ship.rotation.y = atan2(dir.x, dir.z)  # the bow (local +z) leads
		ship.rotation.z = 0.06 * sin(u * 10.0)
		if player:
			player.global_position = ship.to_global(Vector3(0, 2.15, -0.5))
			player.rotation.y = ship.rotation.y
		var oreo2: Node3D = get_tree().get_first_node_in_group("oreo")
		if oreo2:
			oreo2.global_position = ship.to_global(Vector3(0.8, 2.15, 0.6))
			oreo2.rotation.y = ship.rotation.y
		cam.global_position = ship.global_position + Vector3(6.0, 5.0, -9.0)
		cam.look_at(ship.global_position + Vector3(0, 2.0, 3.0))
	ride.tween_method(step, 0.0, 1.0, 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	ride.tween_callback(func() -> void:
		_finish(player, oreo, cam))

func _finish(player: Node3D, oreo: Node3D, cam: Camera3D) -> void:
	Sfx.play("wave_crash", 0.7, 0.0, -8.0)
	var beat := create_tween()
	beat.tween_interval(0.8)
	beat.tween_callback(func() -> void:
		_show_fragment()
		GameState.set_flag("letter_fragment_5")
		GameState.set_flag("island5_complete"))
	beat.tween_interval(5.8)
	beat.tween_callback(func() -> void:
		player.global_position = Vector3(0, 0.7, 40.0)
		player.rotation = Vector3(0, PI, 0)
		player.set_physics_process(true)
		player.set("controls_enabled", true)
		var pcam: Camera3D = player.get("rig").get_node("SpringArm/Camera")
		pcam.current = true
		cam.queue_free()
		if oreo:
			oreo.set("scripted", false)
			oreo.set("following", true)
			oreo.global_position = Vector3(1.4, 0.7, 41.0)
		_departing = false
		_flash("The Santa Maria rides at anchor beyond the mouth, sails full of fog-light, pointed west. English Bay is out there. (Island 6 coming soon)", 6.5))

func _show_fragment() -> void:
	Sfx.play("paper_open", 1.0, 0.05, -6.0)
	var ui := CanvasLayer.new()
	ui.layer = 15
	add_child(ui)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
			preload("res://scripts/ui/hud.gd").parchment_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_top = -110.0
	panel.offset_right = 280.0
	panel.offset_bottom = 110.0
	ui.add_child(panel)
	var margin := MarginContainer.new()
	for m_side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(m_side, 22)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)
	var caption := Label.new()
	caption.text = "Nailed under the capstan's rim, folded small and sailor-tight, beside tally marks and one pawprint:"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(0.4, 0.3, 0.18))
	vbox.add_child(caption)
	var fragment := Label.new()
	fragment.text = "“… adventure.”"
	fragment.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fragment.add_theme_font_size_override("font_size", 34)
	fragment.add_theme_color_override("font_color", Color(0.28, 0.2, 0.12))
	vbox.add_child(fragment)
	panel.modulate.a = 0.0
	var t := panel.create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.7)
	t.tween_interval(4.2)
	t.tween_property(panel, "modulate:a", 0.0, 0.7)
	t.tween_callback(ui.queue_free)

# --- helpers ---

func _zone(area: Area3D, radius: float) -> void:
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	cs.shape = sph
	area.add_child(cs)

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)
