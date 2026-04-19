extends Area2D
class_name PlayerArrowProjectile

@export var speed: float = 560.0
@export var lifetime: float = 1.0
@export var attack_form: StringName = &"Bow"

var _direction: Vector2 = Vector2.RIGHT
var _has_impact: bool = false

func launch(spawn_position: Vector2, direction: Vector2) -> void:
	monitoring = true
	monitorable = true
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
	tween.finished.connect(_on_travel_finished)

func _on_travel_finished() -> void:
	if is_instance_valid(self):
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _has_impact:
		return
	if not area:
		return
	if area.name != "AttackHitbox" and not area.is_in_group("enemy_hurtbox"):
		return

	# Existing enemy AttackHitbox flow already applies damage in enemy.gd.
	# For other grouped hurtboxes, apply Bow damage directly.
	if area.name != "AttackHitbox":
		var enemy_node: Node = area.get_parent()
		if enemy_node and enemy_node.has_method("receive_player_hit"):
			enemy_node.receive_player_hit(attack_form)

	_has_impact = true
	queue_free()

func _on_body_entered(_body: Node) -> void:
	_has_impact = true
	queue_free()
