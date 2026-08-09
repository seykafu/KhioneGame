extends Node3D
## Main scene root and island manager: owns sun/ambience and swaps the
## current island when Khione travels between them.

var current_island: Node3D
var _sky_defaults := {}

func _ready() -> void:
	add_to_group("island_manager")
	current_island = $Ahalo
	$Sun.rotation_degrees = Vector3(-50, 30, 0)
	var sky_mat := ($WorldEnvironment.environment as Environment).sky.sky_material as ProceduralSkyMaterial
	if sky_mat:
		_sky_defaults = {
			"sky_top_color": sky_mat.sky_top_color,
			"sky_horizon_color": sky_mat.sky_horizon_color,
			"ground_horizon_color": sky_mat.ground_horizon_color,
			"ground_bottom_color": sky_mat.ground_bottom_color,
			"sky_cover_modulate": sky_mat.sky_cover_modulate,
		}
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
	# their own grade (Calgary gold, Winnipeg blue hour) set it in _ready.
	$Sun.rotation_degrees = Vector3(-50, 30, 0)
	$Sun.light_color = Color(1, 0.96, 0.88)
	$Sun.light_energy = 1.2
	var sky_mat := ($WorldEnvironment.environment as Environment).sky.sky_material as ProceduralSkyMaterial
	if sky_mat and not _sky_defaults.is_empty():
		for prop: String in _sky_defaults:
			sky_mat.set(prop, _sky_defaults[prop])
	var island: Node3D = load(scene_path).instantiate()
	add_child(island)
	current_island = island
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = spawn
		player.set("velocity", Vector3.ZERO)
		player.set_spawn(spawn)
	Music.play(track, 3.0)
	_sync_oreo(spawn)
	_arrival_fade()
	var hud := get_node_or_null("HUD")
	if hud:
		hud.show_location(display_name)

## Once Oreo has joined, he travels too: adopted as a child of the manager
## so island swaps never free him, and teleported to every new dock.
func _sync_oreo(spawn: Vector3) -> void:
	if not GameState.get_flag("oreo_joined"):
		return
	var oreo: Node3D = get_tree().get_first_node_in_group("oreo")
	if oreo == null or not is_instance_valid(oreo):
		oreo = Node3D.new()
		oreo.name = "Oreo"
		oreo.set_script(load("res://scripts/companions/oreo.gd"))
		add_child(oreo)
	elif oreo.get_parent() != self:
		oreo.reparent(self)
	oreo.set("following", true)
	oreo.set("_stay", false)
	oreo.set("_move_target", Vector3.INF)
	oreo.global_position = spawn + Vector3(1.3, 0, 1.0)

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
