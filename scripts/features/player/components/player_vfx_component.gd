extends Node
class_name PlayerVFXComponent

var _player: PlayerController

func _ready() -> void:
	var p := get_parent()
	if p is PlayerController:
		_player = p

## Camera shake with intensity decay.
func trigger_camera_shake(intensity: float, duration: float) -> void:
	var camera: Camera2D = _player.get_viewport().get_camera_2d()
	if not camera:
		return
	var shake_tween: Tween = _player.create_tween()
	shake_tween.tween_method(func(t: float):
		var decay: float = 1.0 - t
		camera.offset = Vector2(
			randf_range(-intensity, intensity) * decay,
			randf_range(-intensity, intensity) * decay
		)
	, 0.0, 1.0, duration)
	shake_tween.tween_callback(func(): camera.offset = Vector2.ZERO)


## Shield ring block effect.
func spawn_shield_ring() -> void:
	var segments: int = 24
	var ring := Line2D.new()
	ring.default_color = Color(0.4, 0.6, 1.0, 0.5)
	ring.width = 3.0
	var pts: PackedVector2Array = []
	pts.resize(segments + 1)
	for i in range(segments + 1):
		var a: float = (float(i) / float(segments)) * TAU
		pts[i] = Vector2(cos(a) * 26.0, sin(a) * 26.0)
	ring.points = pts
	ring.z_index = 1
	_player.add_child(ring)
	var tween: Tween = _player.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "default_color", Color(0.4, 0.6, 1.0, 0.0), 0.6)
	tween.tween_property(ring, "width", 5.0, 0.6)
	tween.tween_callback(ring.queue_free)

	var glow := Line2D.new()
	glow.default_color = Color(0.3, 0.5, 1.0, 0.2)
	glow.width = 1.5
	var glow_pts: PackedVector2Array = []
	glow_pts.resize(segments + 1)
	for i in range(segments + 1):
		var a: float = (float(i) / float(segments)) * TAU
		glow_pts[i] = Vector2(cos(a) * 36.0, sin(a) * 36.0)
	glow.points = glow_pts
	glow.z_index = 1
	_player.add_child(glow)
	var glow_tween: Tween = _player.create_tween()
	glow_tween.set_parallel(true)
	glow_tween.tween_property(glow, "default_color", Color(0.3, 0.5, 1.0, 0.0), 0.8)
	glow_tween.tween_property(glow, "width", 4.0, 0.8)
	glow_tween.tween_callback(glow.queue_free)


## Speed trail behind dashes.
func spawn_speed_trail(forward_dir: float) -> void:
	var trail := Line2D.new()
	trail.default_color = Color(1, 1, 0.95, 0.6)
	trail.width = 3.0
	var behind_dir: float = -forward_dir
	trail.points = PackedVector2Array([
		Vector2(behind_dir * 40.0, 0.0),
		Vector2(behind_dir * 60.0, 0.0)
	])
	trail.z_index = -1
	_player.add_child(trail)
	var tween: Tween = _player.create_tween()
	tween.tween_property(trail, "modulate", Color(1, 1, 1, 0), 0.25)
	tween.tween_callback(trail.queue_free)
