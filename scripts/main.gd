extends Node3D
## Main scene root and island manager: owns sun/ambience and swaps the
## current island when Khione travels between them.

var current_island: Node3D

func _ready() -> void:
	add_to_group("island_manager")
	current_island = $Ahalo
	$Sun.rotation_degrees = Vector3(-50, 30, 0)
	Sfx.play_ambient("ocean_loop", -16.0)
	_schedule_gull()
	# Ask the OS for keyboard focus; launches from scripts can open unfocused.
	get_window().grab_focus.call_deferred()
	_setup_clouds()

## Soft procedural clouds on the sky dome (noise cover with an alpha ramp).
func _setup_clouds() -> void:
	var env: Environment = $WorldEnvironment.environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.fractal_octaves = 4
	noise.frequency = 0.006
	var cover := NoiseTexture2D.new()
	cover.noise = noise
	cover.seamless = true
	cover.width = 512
	cover.height = 256
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.5, 0.62, 0.8])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.85)])
	cover.color_ramp = grad
	sky_mat.sky_cover = cover
	sky_mat.sky_cover_modulate = Color(1, 1, 1, 0.8)

## Swaps islands: frees the old one, loads the new, moves the player, fades
## in, and starts that island's music track (no-op until its file exists).
func travel_to(scene_path: String, spawn: Vector3, track: String, display_name: String) -> void:
	if current_island:
		current_island.queue_free()
	# Every island starts from the same neutral daylight; islands that want
	# their own light grade (Calgary gold, the Eaton sunset) set it in _ready.
	$Sun.rotation_degrees = Vector3(-50, 30, 0)
	$Sun.light_color = Color(1, 0.96, 0.88)
	$Sun.light_energy = 1.2
	var island: Node3D = load(scene_path).instantiate()
	add_child(island)
	current_island = island
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = spawn
		player.set("velocity", Vector3.ZERO)
		player.set_spawn(spawn)
	Music.play(track, 3.0)
	_arrival_fade()
	var hud := get_node_or_null("HUD")
	if hud:
		hud.show_location(display_name)

func _arrival_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 1)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var t := create_tween()
	t.tween_property(rect, "color:a", 0.0, 1.6)
	t.tween_callback(layer.queue_free)

func _schedule_gull() -> void:
	get_tree().create_timer(randf_range(14.0, 34.0)).timeout.connect(_on_gull_timer)

func _on_gull_timer() -> void:
	Sfx.play("gull", 1.0, 0.15, -10.0)
	_schedule_gull()
