class_name Diggable
extends Node3D
## A snow-buried something. Khione meows nearby to mark it (her Whisker
## Sense shimmer sinks into the drift); Oreo digs it open. Puzzles connect
## to `dug` to hand out what was under there.

signal dug

@export var mound_radius := 0.7
var buried := true
var marked := false
var _mound: MeshInstance3D
var _ring: MeshInstance3D

func _ready() -> void:
	add_to_group("diggable")
	_mound = MeshInstance3D.new()
	var ms := SphereMesh.new()
	ms.radius = mound_radius
	ms.height = mound_radius * 0.9
	_mound.mesh = ms
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.93, 0.95, 0.99)
	mm.roughness = 0.9
	_mound.material_override = mm
	_mound.position.y = 0.05
	add_child(_mound)

func mark() -> void:
	if not buried or marked:
		return
	marked = true
	Sfx.play("whisker_shimmer", 1.15, 0.05, -10.0)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = mound_radius * 0.9
	torus.outer_radius = mound_radius * 1.05
	_ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.65, 0.9, 0.95, 0.7)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.emission_enabled = true
	rm.emission = Color(0.6, 0.9, 0.95)
	rm.emission_energy_multiplier = 1.2
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = rm
	_ring.position.y = 0.12
	add_child(_ring)
	var pulse := _ring.create_tween().set_loops()
	pulse.tween_property(_ring, "scale", Vector3(1.18, 1.0, 1.18), 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_ring, "scale", Vector3.ONE, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func dig_open() -> void:
	if not buried:
		return
	buried = false
	remove_from_group("diggable")
	if _ring:
		_ring.queue_free()
	var burst := CPUParticles3D.new()
	burst.amount = 26
	burst.lifetime = 0.7
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 55.0
	burst.gravity = Vector3(0, -6, 0)
	burst.initial_velocity_min = 1.8
	burst.initial_velocity_max = 3.4
	var flake := SphereMesh.new()
	flake.radius = 0.05
	flake.height = 0.1
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.95, 0.97, 1.0)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = fm
	burst.mesh = flake
	burst.position.y = 0.3
	burst.emitting = true
	add_child(burst)
	var t := _mound.create_tween()
	t.tween_property(_mound, "scale", Vector3(1.1, 0.06, 1.1), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(_mound.queue_free)
	var cleanup := create_tween()
	cleanup.tween_interval(1.2)
	cleanup.tween_callback(burst.queue_free)
	dug.emit()
