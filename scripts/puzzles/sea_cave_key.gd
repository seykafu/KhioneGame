extends Node3D
## Island 5, Riddle 4 — The Sea Cave Key.
## A silvery-blue fish (the exact colour of Ahalo's stranded fish — a
## colour the player's eye already knows) patrols the sea cave under the
## headland. Followed from inside the cave, it pauses, three times, at
## the same rusted grate. Behind the grate, visible only from the cave's
## low angle: the drydock's missing spigot wheel. Watch, then pry.

## The patrol loop threads the cave's dogleg, pausing at the grate.
const PATROL: Array[Vector3] = [
	Vector3(29.5, -0.15, 31.5), Vector3(31.5, -0.15, 27.5),
	Vector3(33.2, -0.15, 21.6),   # the grate pause
	Vector3(31.0, -0.15, 24.5), Vector3(28.6, -0.15, 29.0),
]
const GRATE_IDX := 2
const FISH_BLUE := Color(0.62, 0.74, 0.85)

var _fish: Node3D
var _leg := 0
var _t := 0.0
var _pausing := 0.0
var _pause_count := 0

class GratePlate:
	extends Interactable
	var owner_puzzle: Node

	func _init() -> void:
		prompt = "Pry at the rusted grate"

	func interact(_player: Node) -> void:
		owner_puzzle.try_grate()

func _ready() -> void:
	_fish = Node3D.new()
	_fish.position = PATROL[0]
	add_child(_fish)
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.09
	bm.height = 0.45
	body.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = FISH_BLUE
	m.metallic = 0.5
	m.roughness = 0.3
	body.material_override = m
	body.rotation.x = PI / 2.0
	_fish.add_child(body)
	var tail := MeshInstance3D.new()
	var tm := PrismMesh.new()
	tm.size = Vector3(0.14, 0.12, 0.06)
	tail.mesh = tm
	tail.material_override = m
	tail.position = Vector3(0, 0, -0.28)
	_fish.add_child(tail)
	var plate := GratePlate.new()
	plate.owner_puzzle = self
	plate.position = Vector3(33.2, 0.3, 20.6)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	cs.shape = sph
	plate.add_child(cs)
	add_child(plate)

func _process(delta: float) -> void:
	if _pausing > 0.0:
		_pausing -= delta
		# A little nose-tap against the grate while it waits.
		_fish.position.y = -0.15 + 0.04 * sin(_pausing * 12.0)
		if _pausing <= 0.0 and _player_in_cave():
			_pause_count += 1
			if _pause_count >= 1 and not GameState.get_flag("fish_led"):
				GameState.set_flag("fish_led")
				_flash("Three taps at the same grate. Behind the bars, low from down here: a brass wheel, waiting.", 5.0)
		return
	var target := PATROL[(_leg + 1) % PATROL.size()]
	var to := target - _fish.position
	if to.length() < 0.15:
		_leg = (_leg + 1) % PATROL.size()
		if _leg == GRATE_IDX:
			_pausing = 2.2
			Sfx.play("crab_snip", 1.6, 0.1, -26.0)
		return
	_fish.position += to.normalized() * 1.5 * delta
	_fish.rotation.y = atan2(to.x, to.z)

func _player_in_cave() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var p := player.global_position
	return p.x > 27.0 and p.x < 36.5 and p.z > 18.0 and p.z < 33.0

func try_grate() -> void:
	if Inventory.has_item("spigot_wheel"):
		_flash("The grate hangs loose now, its secret already spent.", 3.0)
		return
	if not GameState.get_flag("fish_led"):
		_flash("Rusted bars, dark behind. Something silvery keeps stopping HERE, though — worth watching from inside the cave.", 4.5)
		return
	Sfx.play("stone_slide", 1.3, 0.05, -12.0)
	Sfx.play("pickup_chime", 1.0, 0.0, -10.0)
	var island := get_parent()
	var grate: Node3D = island.get_node_or_null("CaveGrate")
	if grate:
		var wheel := grate.get_node_or_null("SpigotWheel")
		if wheel:
			wheel.queue_free()
		var t := create_tween()
		t.tween_property(grate, "rotation:x", 0.5, 0.6).set_trans(Tween.TRANS_BOUNCE)
	Inventory.add_item("spigot_wheel")
	_flash("One bar was only ever rust. The brass spigot wheel is HERS — and the drydock's dry throat is waiting for it.", 5.0)

## Test hook: the fish has led her.
func force_led() -> void:
	GameState.set_flag("fish_led")

func _flash(text: String, dur: float) -> void:
	var hud := get_node_or_null("../../HUD")
	if hud:
		hud.flash_message(text, dur)
