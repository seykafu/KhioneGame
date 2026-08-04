extends Node3D
## Island 2, Main Riddle — Make the Flock Fly.
## Everything the mall gave converges: the drummer's crank opens the skylight
## shutters; the owned clock turned to 6 leans the light to sunset, and sixty
## goose shadows land on the tiles pointing at the dark elevator; the fuse
## from the pigeons' vent blast wakes it. Ride to the roof, unhook the great
## banner, and glide out with the flock as it finally flies.

const SHUTTER_Y := 10.55
const SOCKET_POS := Vector3(6.0, 4.55, -6.8)
const ELEVATOR_POS := Vector3(13.5, 0.0, -6.5)
const BANNER_POS := Vector3(0.0, 10.9, 12.4)

const SHADOW := Color(0.16, 0.14, 0.2, 0.85)
const STEEL := Color(0.45, 0.47, 0.52)

var _skylight_shutters: Array[MeshInstance3D] = []
var _sunset_done := false
var _ridden := false
var _gliding := false
var _elevator_light: MeshInstance3D
var _materials := {}
var _ui: CanvasLayer
var _subtitle: Label
var _fade_rect: ColorRect

class CrankSocket:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "A crank-shaped socket"

	func interact(_player: Node) -> void:
		owner_puzzle.use_crank()

class BannerPlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Unhook the great banner"

	func interact(_player: Node) -> void:
		owner_puzzle.start_glide()

func _ready() -> void:
	add_to_group("flock_finale")
	_build_shutters()
	_build_socket()
	_build_elevator_bits()
	_build_banner_station()
	GameState.flag_changed.connect(_on_flag)

# --- phase 1: the shutters ---

func _build_shutters() -> void:
	for i in 6:
		var slat := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4.7, 0.12, 13.2)
		slat.mesh = box
		slat.material_override = _mat(Color(0.3, 0.31, 0.34))
		slat.position = Vector3(-11.75 + i * 4.7, SHUTTER_Y, 0)
		add_child(slat)
		_skylight_shutters.append(slat)

func _build_socket() -> void:
	var pedestal := MeshInstance3D.new()
	pedestal.mesh = _cyl(0.16, 0.2, 0.5)
	pedestal.material_override = _mat(STEEL)
	pedestal.position = SOCKET_POS + Vector3(0, 0.25, 0)
	add_child(pedestal)
	pedestal.create_trimesh_collision()
	var hole := MeshInstance3D.new()
	hole.mesh = _cyl(0.06, 0.06, 0.08)
	hole.material_override = _mat(Color(0.1, 0.1, 0.1))
	hole.position = SOCKET_POS + Vector3(0, 0.52, 0)
	add_child(hole)
	var plate := CrankSocket.new()
	plate.owner_puzzle = self
	plate.position = SOCKET_POS + Vector3(0, 0.6, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.0
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

func use_crank() -> void:
	if GameState.get_flag("skylight_open"):
		_flash("The crank spins freely. The sky is already open.", 3.0)
		return
	if not Inventory.has_item("skylight_crank"):
		_flash("A crank-shaped socket, empty for years.", 3.0)
		return
	Inventory.remove_item("skylight_crank")
	Sfx.play("wood_creak", 0.9, 0.05, -6.0)
	Sfx.play("stone_slide", 0.8, 0.0, -4.0)
	for i in _skylight_shutters.size():
		var slat := _skylight_shutters[i]
		var dir := -1.0 if i < 3 else 1.0
		var t := slat.create_tween()
		t.tween_property(slat, "position:x", slat.position.x + dir * 16.0, 2.8) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	GameState.set_flag("skylight_open")
	_flash("The shutters grind apart, and the skylight drinks the sky. Now the light must lean.", 5.0)

# --- phase 2: sunset and the shadow flock ---

func _on_flag(flag: String, value: bool) -> void:
	if flag == "clock_at_6" and value and GameState.get_flag("skylight_open") \
			and not _sunset_done:
		_sunset()

func _sunset() -> void:
	_sunset_done = true
	GameState.set_flag("mall_sunset")
	var mgr := get_tree().get_first_node_in_group("island_manager")
	if mgr:
		var sun: DirectionalLight3D = mgr.get_node_or_null("Sun")
		if sun:
			var t := create_tween().set_parallel(true)
			t.tween_property(sun, "rotation_degrees", Vector3(-13.0, 30.0, 0.0), 3.0)
			t.tween_property(sun, "light_color", Color(1.0, 0.72, 0.45), 3.0)
			t.tween_property(sun, "light_energy", 1.35, 3.0)
	Sfx.play("whisker_shimmer", 0.7, 0.0, -8.0)
	var late := create_tween()
	late.tween_interval(2.5)
	late.tween_callback(_spawn_shadow_flock)

func _spawn_shadow_flock() -> void:
	Sfx.play("gull", 0.8, 0.1, -10.0)
	# A river of goose shadows across the tiles, all pointing at the elevator.
	var from := Vector3(-2.0, 0.41, 1.0)
	var to := Vector3(11.0, 0.41, -5.4)
	var dir := (to - from).normalized()
	var side := Vector3(dir.z, 0, -dir.x)
	var count := 14
	for i in count:
		var t := float(i) / (count - 1)
		var wobble := sin(t * 12.0) * 1.1
		var pos := from.lerp(to, t) + side * wobble
		_shadow_goose(pos, atan2(dir.x, dir.z), 0.1 * i)
	for k in 3:
		_shadow_goose(to + dir * (1.0 + 0.5 * k) + side * (k - 1.0) * 0.6,
				atan2(dir.x, dir.z), 1.5 + 0.1 * k)
	_flash("Sixty shadows land on the tiles… and point, all of them, at the dark glass elevator.", 5.0)
	_elevator_light_pulse()

func _shadow_goose(pos: Vector3, yaw: float, delay: float) -> void:
	var g := Node3D.new()
	var body := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.24
	bs.height = 0.05
	body.mesh = bs
	body.scale = Vector3(1.0, 1.0, 1.9)
	body.material_override = _shadow_mat()
	g.add_child(body)
	for s in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(0.55, 0.02, 0.24)
		wing.mesh = wb
		wing.material_override = _shadow_mat()
		wing.position = Vector3(0.35 * s, 0, -0.05)
		wing.rotation.y = 0.35 * s
		wing.rotation.z = 0.0
		g.add_child(wing)
	g.position = pos
	g.rotation.y = yaw
	g.scale = Vector3.ONE * 0.01
	add_child(g)
	var t := g.create_tween()
	t.tween_interval(delay)
	t.tween_property(g, "scale", Vector3.ONE, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- phase 3: the elevator ---

func _build_elevator_bits() -> void:
	var pad := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(2.2, 0.15, 2.2)
	pad.mesh = pb
	pad.material_override = _mat(STEEL)
	pad.position = ELEVATOR_POS + Vector3(0, 0.45, 0)
	add_child(pad)
	pad.create_trimesh_collision()
	# Landing pad at the shaft's top so the roof exit is safe.
	var top := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(2.6, 0.15, 2.6)
	top.mesh = tb
	top.material_override = _mat(STEEL)
	top.position = ELEVATOR_POS + Vector3(0, 10.55, 0)
	add_child(top)
	top.create_trimesh_collision()

func elevator_interact() -> void:
	if _ridden:
		_flash("The elevator hums, content with its one job done.", 3.0)
		return
	if not GameState.get_flag("mall_sunset"):
		_flash("Dark, silent, waiting. Its call button wants something the mall hasn't given yet.", 4.0)
		return
	if not Inventory.has_item("elevator_fuse"):
		_flash("The shadows all point here. Behind a little hatch: an empty fuse socket.", 4.0)
		return
	Inventory.remove_item("elevator_fuse")
	_ridden = true
	GameState.set_flag("elevator_powered")
	Sfx.play("pickup_chime", 1.2, 0.0, -8.0)
	Sfx.play("robot_whir", 1.3, 0.0, -8.0)
	_elevator_light = MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(2.0, 0.1, 2.0)
	_elevator_light.mesh = lb
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1.0, 0.95, 0.8)
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.93, 0.7)
	lm.emission_energy_multiplier = 2.0
	_elevator_light.material_override = lm
	_elevator_light.position = ELEVATOR_POS + Vector3(0, 9.6, 0)
	add_child(_elevator_light)
	_flash("The fuse seats with a satisfying clunk. The elevator wakes.", 3.0)
	_ride()

func _elevator_light_pulse() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.35
	torus.outer_radius = 1.5
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.5, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.position = ELEVATOR_POS + Vector3(0, 0.5, 0)
	add_child(ring)
	var t := ring.create_tween().set_loops(6)
	t.tween_property(ring, "scale", Vector3(1.5, 1.0, 1.5), 0.9)
	t.tween_property(ring, "scale", Vector3.ONE, 0.9)
	var cleanup := create_tween()
	cleanup.tween_interval(11.0)
	cleanup.tween_callback(ring.queue_free)

func _ride() -> void:
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.controls_enabled = false
	player.set_physics_process(false)
	var t := create_tween()
	t.tween_property(player, "global_position", ELEVATOR_POS + Vector3(0, 0.75, 0), 0.8)
	t.tween_interval(0.4)
	t.tween_property(player, "global_position", ELEVATOR_POS + Vector3(0, 10.9, 0), 3.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(player, "global_position", ELEVATOR_POS + Vector3(-1.4, 10.85, -1.2), 0.9)
	t.tween_callback(func() -> void:
		player.set_physics_process(true)
		player.controls_enabled = true
		_flash("The roof of the world. Or at least of the mall. A great banner waits at the south edge.", 5.0))

# --- phase 4: the banner and the glide ---

func _build_banner_station() -> void:
	var pole := MeshInstance3D.new()
	pole.mesh = _cyl(0.08, 0.1, 2.6)
	pole.material_override = _mat(STEEL)
	pole.position = BANNER_POS + Vector3(0, 1.3, 0)
	add_child(pole)
	pole.create_trimesh_collision()
	var roll := MeshInstance3D.new()
	roll.mesh = _cyl(0.22, 0.22, 1.9)
	roll.material_override = _mat(Color(0.2, 0.5, 0.5))
	roll.rotation.z = PI / 2.0
	roll.position = BANNER_POS + Vector3(0, 2.3, 0)
	add_child(roll)
	var plate := BannerPlate.new()
	plate.owner_puzzle = self
	plate.position = BANNER_POS + Vector3(0, 1.2, 0)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

func start_glide() -> void:
	if _gliding or GameState.get_flag("island2_complete"):
		return
	if not _ridden:
		_flash("The banner is knotted tight. Perhaps after the elevator hums.", 3.5)
		return
	_gliding = true
	_glide()

func _glide() -> void:
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.controls_enabled = false
	player.rig.set_process_unhandled_input(false)
	player.set_physics_process(false)
	_build_cine_ui()
	Music.play("intro", 2.0)

	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true

	# The flock flies.
	var geese: Node3D = get_parent().get_node_or_null("Geese")
	if geese:
		var gt := geese.create_tween()
		gt.tween_property(geese, "position", geese.position + Vector3(0, 7.0, 55.0), 9.0) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	Sfx.play("gull", 0.9, 0.1, -6.0)
	Sfx.play("gull", 1.05, 0.1, -9.0)

	# Banner streams behind her.
	var banner := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.6, 0.04, 0.9)
	banner.mesh = bb
	banner.material_override = _mat(Color(0.2, 0.5, 0.5))
	banner.position = Vector3(0, 0.5, -0.7)
	banner.rotation.x = 0.3
	player.add_child(banner)

	_narrate("And when the flock finally flew, a little white cat flew with them.")
	var hop := create_tween()
	hop.tween_property(player, "global_position", BANNER_POS + Vector3(0, 0.6, 0.8), 0.7)
	await hop.finished

	var p1 := player.global_position
	var p2 := Vector3(0.0, 6.5, 30.0)
	var p3 := Vector3(0.0, 1.05, 38.5)
	var glide := create_tween()
	var step := func(u: float) -> void:
		var pos: Vector3
		if u < 0.6:
			pos = p1.lerp(p2, u / 0.6)
		else:
			pos = p2.lerp(p3, (u - 0.6) / 0.4)
		player.global_position = pos
		cam.global_position = pos + Vector3(-7.0, 1.8, -3.0)
		cam.look_at(pos)
	glide.tween_method(step, 0.0, 1.0, 7.0)
	await glide.finished
	banner.queue_free()
	player._play_anim("Idle", 0.3)

	_show_fragment()
	GameState.set_flag("letter_fragment_2")
	await _sleep(5.5)

	_fade(1.0, 1.5)
	await _sleep(1.8)
	GameState.set_flag("island2_complete")
	player.set_physics_process(true)
	player.controls_enabled = true
	player.rig.set_process_unhandled_input(true)
	var pcam: Camera3D = player.rig.get_node("SpringArm/Camera")
	pcam.current = true
	cam.queue_free()
	_subtitle.visible = false
	_fade(0.0, 1.4)
	await _sleep(1.5)
	_ui.queue_free()
	_flash("Island 3 waits beyond the horizon. The Eaton Centre sleeps, lighter by one flock.", 6.0)

func _show_fragment() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
			preload("res://scripts/ui/hud.gd").parchment_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_top = -110.0
	panel.offset_right = 280.0
	panel.offset_bottom = 110.0
	var margin := MarginContainer.new()
	for m_side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(m_side, 22)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)
	var caption := Label.new()
	caption.text = "A scrap slips from the banner's stitching:"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(0.4, 0.3, 0.18))
	vbox.add_child(caption)
	var fragment := Label.new()
	fragment.text = "“… not supposed to …”"
	fragment.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fragment.add_theme_font_size_override("font_size", 34)
	fragment.add_theme_color_override("font_color", Color(0.28, 0.2, 0.12))
	vbox.add_child(fragment)
	panel.modulate.a = 0.0
	_ui.add_child(panel)
	var t := panel.create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.7)
	t.tween_interval(4.0)
	t.tween_property(panel, "modulate:a", 0.0, 0.7)
	Sfx.play("paper_open", 1.0, 0.05, -6.0)

# --- mini cinematic ui ---

func _build_cine_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	for preset: int in [Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_preset(preset)
		if preset == Control.PRESET_TOP_WIDE:
			bar.offset_bottom = 90.0
		else:
			bar.offset_top = -90.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(bar)
	_subtitle = Label.new()
	_subtitle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle.offset_top = -190.0
	_subtitle.offset_bottom = -104.0
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 26)
	_subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	_subtitle.add_theme_constant_override("outline_size", 10)
	_ui.add_child(_subtitle)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade_rect)

func _narrate(text: String) -> void:
	_subtitle.text = text
	_subtitle.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_subtitle, "modulate:a", 1.0, 0.45)

func _fade(to: float, dur: float) -> void:
	var t := create_tween()
	t.tween_property(_fade_rect, "color:a", to, dur)

func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

# --- helpers ---

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)

func _shadow_mat() -> StandardMaterial3D:
	if not _materials.has("shadow"):
		var m := StandardMaterial3D.new()
		m.albedo_color = SHADOW
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials["shadow"] = m
	return _materials["shadow"]

func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.8
		_materials[color] = m
	return _materials[color]

func _cyl(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = height
	return c
