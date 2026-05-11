extends Area2D
class_name EnemyArrowProjectile

signal hit_target(body: Node, hit_position: Vector2)

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _marker: Polygon2D = $Polygon2D

func launch(start_position: Vector2, direction: Vector2, speed: float, lifetime: float) -> void:
	global_position = start_position
	rotation = direction.angle()
	monitoring = true
	monitorable = true

	var travel_distance: float = speed * max(lifetime, 0.2)
	var target: Vector2 = global_position + (direction * travel_distance)
	var travel_time: float = travel_distance / max(speed, 1.0)

	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", target, travel_time)
	tween.finished.connect(_on_travel_finished)

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	hit_target.emit(body, global_position)
	queue_free()

func _on_travel_finished() -> void:
	if is_instance_valid(self):
		queue_free()
