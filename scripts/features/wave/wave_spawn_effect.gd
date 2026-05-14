extends Node2D
class_name WaveSpawnEffect


func _ready() -> void:
	# Expanding ring flash
	var ring := Line2D.new()
	ring.default_color = Color(1.0, 1.0, 1.0, 0.6)
	ring.width = 2.0
	var segments: int = 24
	var pts: PackedVector2Array = []
	pts.resize(segments + 1)
	for i in range(segments + 1):
		var a: float = (float(i) / float(segments)) * TAU
		pts[i] = Vector2(cos(a) * 4.0, sin(a) * 4.0)
	ring.points = pts
	add_child(ring)

	# Ground puff particles (simple expanding circles)
	var puff := Line2D.new()
	puff.default_color = Color(0.9, 0.9, 0.9, 0.3)
	puff.width = 1.5
	var puff_pts: PackedVector2Array = []
	puff_pts.resize(segments + 1)
	for i in range(segments + 1):
		var a: float = (float(i) / float(segments)) * TAU
		puff_pts[i] = Vector2(cos(a) * 2.0, sin(a) * 2.0)
	puff.points = puff_pts
	puff.position.y = 4.0
	add_child(puff)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "width", 8.0, 0.35)
	tween.tween_property(ring, "default_color", Color(1.0, 1.0, 1.0, 0.0), 0.35)
	tween.tween_property(puff, "width", 5.0, 0.35)
	tween.tween_property(puff, "default_color", Color(0.9, 0.9, 0.9, 0.0), 0.35)
	tween.tween_callback(queue_free)
