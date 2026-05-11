extends Resource
class_name Stats

enum Faction {
	PLAYER,
	ENEMY,
}

@export var base_max_health: int = 1
@export var base_defense: int = 1
@export var base_attack: int = 1

var current_max_health: int = 1
var current_defense: int = 1
var current_attack: int = 1

signal health_depleted
signal health_changed(new_health: int, max_health: int)

var _health: int = 1
var _died_emitted: bool = false

var health: int:
	get: return _health
	set(value):
		_health = clampi(value, 0, current_max_health)
		health_changed.emit(_health, current_max_health)
		if _health == 0 and not _died_emitted:
			_died_emitted = true
			health_depleted.emit()

func _init() -> void:
	current_max_health = base_max_health
	current_defense = base_defense
	current_attack = base_attack
	_health = current_max_health

func take_damage(amount: int) -> void:
	health -= amount