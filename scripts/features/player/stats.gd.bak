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

func _init() -> void:
	current_max_health = base_max_health
	current_defense = base_defense
	current_attack = base_attack