extends Node2D

func _ready() -> void:
	var line := $Line2D as Line2D
	if not line:
		return
	
	# Build a circle out of line segments.
	var segments: int = 24
	var points: PackedVector2Array = []
	points.resize(segments + 1)
	for i in range(segments + 1):
		var angle: float = TAU * i / segments
		points[i] = Vector2(cos(angle), sin(angle))
	line.points = points
	
	# Expand and fade.
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(3.0, 3.0), 0.25)
	tween.tween_property(line, "modulate", Color(1, 1, 1, 0), 0.25)
	tween.finished.connect(queue_free)
