extends Node
class_name EnemyEventComponent

var _event_bus: Node

func setup() -> void:
	_event_bus = get_node_or_null("/root/EventBus")

func emit_player_hit(hit_position: Vector2, camera_intensity: float, camera_duration: float) -> void:
	if _event_bus and _event_bus.has_method("emit_enemy_hit_player"):
		_event_bus.emit_enemy_hit_player(hit_position, camera_intensity, camera_duration)
	if _event_bus and _event_bus.has_method("emit_enemy_hit_stop"):
		_event_bus.emit_enemy_hit_stop(0.06)

func emit_hit_stop(duration: float = 0.05) -> void:
	if _event_bus and _event_bus.has_method("emit_enemy_hit_stop"):
		_event_bus.emit_enemy_hit_stop(duration)
