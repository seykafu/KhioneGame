extends Node3D
## Beats 4c + 5 — Rig the Raft, and the Departure.
## The beached raft frame accepts the Old Oar, Dry Frond (sail), and Vine
## Rope; installing all three readies it. Setting sail plays the island
## finale: Khione drifts out to sea, the camera returns to a beach printed
## with pawprints that are not hers, a letter fragment is found, and the
## island closes with a promise of Island 2.

const NEEDED := {"old_oar": "an oar", "palm_frond": "a sail", "vine_rope": "rope"}
const DRY := Color(0.66, 0.61, 0.32)
const DRIFTWOOD := Color(0.72, 0.65, 0.55)
const VINE_GREEN := Color(0.36, 0.52, 0.28)

var _installed := {}
var _raft: Node3D
var _sailing := false
var _materials := {}
var _ui: CanvasLayer
var _subtitle: Label
var _fade_rect: ColorRect

func _ready() -> void:
	add_to_group("raft_rigging")

func _process(_delta: float) -> void:
	if _sailing:
		return
	if _raft == null:
		_raft = get_node_or_null("../SundialReef/RaftFrame")
		return
	var ex: Interactable = _raft.get_node_or_null("Examine")
	if ex == null:
		return
	if _complete():
		ex.prompt = "Set sail"
	elif _any_needed_carried():
		ex.prompt = "Rig the raft"
	else:
		ex.prompt = "Examine the timbers"

func raft_interact(raft: Node3D) -> void:
	if _sailing:
		return
	_raft = raft
	if _complete():
		_set_sail()
		return
	var placed_any := false
	for id: String in NEEDED:
		if not _installed.has(id) and Inventory.has_item(id):
			Inventory.remove_item(id)
			_installed[id] = true
			_add_part_visual(id)
			placed_any = true
	if placed_any:
		Sfx.play("wood_creak", 1.05, 0.1, -8.0)
		Sfx.play("pickup_chime", 0.9, 0.0, -8.0)
		if _complete():
			GameState.set_flag("raft_rigged")
			_flash("The raft is ready. The sea is waiting.", 4.0)
		else:
			_flash("Lashed on. Still missing: %s." % _missing_text(), 3.5)
	else:
		_flash("The frame wants: %s." % _missing_text(), 3.5)

func _complete() -> bool:
	return _installed.size() == NEEDED.size()

func _any_needed_carried() -> bool:
	for id: String in NEEDED:
		if not _installed.has(id) and Inventory.has_item(id):
			return true
	return false

func _missing_text() -> String:
	var parts: Array[String] = []
	for id: String in NEEDED:
		if not _installed.has(id):
			parts.append(NEEDED[id])
	return ", ".join(parts)

func _add_part_visual(id: String) -> void:
	match id:
		"old_oar":
			var shaft := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.045
			cyl.bottom_radius = 0.045
			cyl.height = 1.5
			shaft.mesh = cyl
			shaft.material_override = _mat(DRIFTWOOD.darkened(0.1))
			shaft.rotation = Vector3(0, 0.5, 1.25)
			shaft.position = Vector3(-0.5, 0.22, 0.35)
			_raft.add_child(shaft)
		"palm_frond":
			var mast := MeshInstance3D.new()
			var mc := CylinderMesh.new()
			mc.top_radius = 0.05
			mc.bottom_radius = 0.06
			mc.height = 1.9
			mast.mesh = mc
			mast.material_override = _mat(DRIFTWOOD.darkened(0.2))
			mast.position = Vector3(0.15, 1.0, 0)
			_raft.add_child(mast)
			for i in 2:
				var sail := MeshInstance3D.new()
				var sb := BoxMesh.new()
				sb.size = Vector3(0.06, 0.95, 0.55)
				sail.mesh = sb
				sail.material_override = _mat(DRY)
				sail.position = Vector3(0.15, 1.45, 0.3 - i * 0.6)
				sail.rotation.x = 0.35 - i * 0.7
				_raft.add_child(sail)
		"vine_rope":
			for x in [-1.0, 1.0]:
				var knot := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = 0.09
				torus.outer_radius = 0.15
				knot.mesh = torus
				knot.material_override = _mat(VINE_GREEN.darkened(0.1))
				knot.rotation.x = PI / 2.0
				knot.position = Vector3(x, 0.16, 0)
				_raft.add_child(knot)

# --- Beat 5: the departure ---

func _set_sail() -> void:
	_sailing = true
	GameState.set_flag("set_sail_started")
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.controls_enabled = false
	player.rig.set_process_unhandled_input(false)
	player.set_physics_process(false)
	Music.play("intro", 2.5)
	_build_cine_ui()

	player._play_anim("Jump_Start", 0.1)
	var hop := create_tween()
	hop.tween_property(player, "global_position", _raft.global_position + Vector3(0, 0.4, 0), 0.7)
	await hop.finished
	player._play_anim("Idle", 0.3)

	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = _raft.global_position + Vector3(-6.0, 2.8, -8.0)
	cam.look_at(_raft.global_position + Vector3(0, 0.5, 0))
	cam.current = true

	_narrate("And so, with borrowed timbers and a stranger's wish, Khione left the only home she had ever known.")
	Sfx.play("splash", 0.9, 0.1, -8.0)
	var start: Vector3 = _raft.global_position
	var dest := Vector3(14.0, start.y - 0.12, 78.0)
	var drift := create_tween()
	var step := func(t: float) -> void:
		var rp := start.lerp(dest, t)
		_raft.global_position = rp
		player.global_position = rp + Vector3(0, 0.4, 0)
		cam.global_position = rp + Vector3(-7.0, 3.0, -8.0).lerp(Vector3(-14.0, 6.5, -16.0), t)
		cam.look_at(rp + Vector3(0, 0.5, 0))
	drift.tween_method(step, 0.0, 1.0, 13.0)
	await drift.finished

	# The shot the whole island was building toward.
	_narrate("Behind her, the beach held its breath —")
	cam.global_position = Vector3(4.0, 2.4, 26.5)
	cam.look_at(Vector3(3.2, 0.0, 32.0))
	_spawn_big_pawprints()
	await _sleep(2.2)
	_narrate("— around prints that were not hers, pressed soft into the sand.")
	await _sleep(4.4)

	_show_fragment()
	GameState.set_flag("letter_fragment_1")
	await _sleep(5.5)

	_fade(1.0, 1.6)
	await _sleep(1.9)
	player.global_position = Vector3(0, 1, 30)
	player.set_physics_process(true)
	player.controls_enabled = true
	player.rig.set_process_unhandled_input(true)
	var pcam: Camera3D = player.rig.get_node("SpringArm/Camera")
	pcam.current = true
	cam.queue_free()
	_subtitle.visible = false
	_fade(0.0, 1.4)
	Music.play("ahalo", 3.0)
	GameState.set_flag("island1_complete")
	await _sleep(1.5)
	_ui.queue_free()
	_flash("Ahalo will remember you.   (Island 2 — coming soon)", 6.0)

func _spawn_big_pawprints() -> void:
	# Twice Khione's size. Players trained on her own prints will notice.
	var dir := Vector3(0.25, 0, 1.0).normalized()
	var side := Vector3(dir.z, 0, -dir.x)
	for i in 9:
		var paw := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2(0.2, 0.28)
		paw.mesh = quad
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.5, 0.35)
		m.roughness = 1.0
		paw.material_override = m
		var flip := 1.0 if i % 2 == 0 else -1.0
		paw.position = Vector3(1.5, 0.03, 29.0) + dir * (0.55 * i) + side * 0.16 * flip
		paw.rotation.y = atan2(dir.x, dir.z)
		add_child(paw)

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
	caption.text = "Tucked in the raft's knots — a scrap of familiar handwriting:"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(0.4, 0.3, 0.18))
	vbox.add_child(caption)
	var fragment := Label.new()
	fragment.text = "“… one final …”"
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
