extends Area2D
class_name PlayerArrowProjectile

@export var speed: float = 560.0
@export var lifetime: float = 1.0

var _direction: Vector2 = Vector2.RIGHT

func launch(spawn_position: Vector2, direction: Vector2) -> void:
	_direction = direction.normalized()
	if _direction == Vector2.ZERO:
		_direction = Vector2.RIGHT
	rotation = _direction.angle()
	global_position = spawn_position

	var travel_distance: float = speed * max(lifetime, 0.1)
	var target: Vector2 = global_position + (_direction * travel_distance)
	var travel_time: float = travel_distance / max(speed, 1.0)

	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", target, travel_time)
	tween.finished.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)

func _on_area_entered(area: Area2D) -> void:
	if not area:
		return
	if area.name != "AttackHitbox":
		return
	queue_free()

func _on_body_entered(_body: Node) -> void:
	queue_free()
