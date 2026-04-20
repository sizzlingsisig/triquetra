extends Node
class_name EnemyHealthComponent

signal health_changed(new_health: int)
signal died

@export var max_health: int = 2

var _current_health: int = 2

func setup(initial_max_health: int = -1) -> void:
	if initial_max_health > 0:
		max_health = initial_max_health
	reset()

func reset() -> void:
	_current_health = max(max_health, 1)
	health_changed.emit(_current_health)

func apply_damage(damage: int) -> int:
	if damage <= 0:
		return _current_health

	_current_health = max(_current_health - damage, 0)
	health_changed.emit(_current_health)
	if _current_health <= 0:
		died.emit()
	return _current_health

func get_current_health() -> int:
	return _current_health
