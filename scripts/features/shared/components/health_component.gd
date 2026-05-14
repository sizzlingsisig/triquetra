extends Node
class_name HealthComponent

## Emitted whenever current health changes.
## [param new_health] is the health value after the change.
signal health_changed(new_health: int)

## Emitted when current_health reaches 0.
signal died

## Emitted each time damage is applied, even if health doesn't reach 0.
signal damage_taken(amount: int, new_health: int)

## Emitted each time healing is applied.
signal healed(amount: int, new_health: int)

@export var max_health: int = 2

var _current_health: int = 2


func _ready() -> void:
	assert(max_health > 0, "HealthComponent: max_health must be > 0")
	reset()


## Override max_health and reset to full.
func set_max_health(value: int) -> void:
	assert(value > 0, "HealthComponent: max_health must be > 0")
	max_health = value
	reset()


## Restore to full health.
func reset() -> void:
	_current_health = max_health
	health_changed.emit(_current_health)


## Apply [param amount] damage. Returns new_health. Emits died if <= 0.
func apply_damage(amount: int) -> int:
	assert(amount > 0, "HealthComponent: damage amount must be > 0")

	_current_health = maxi(_current_health - amount, 0)
	assert(_current_health >= 0, "HealthComponent: health should never go below 0")
	damage_taken.emit(amount, _current_health)
	health_changed.emit(_current_health)
	if _current_health <= 0:
		died.emit()
	return _current_health


## Heal [param amount] (capped at max_health). Returns new_health.
func heal(amount: int) -> int:
	if amount <= 0:
		return _current_health

	_current_health = mini(_current_health + amount, max_health)
	healed.emit(amount, _current_health)
	health_changed.emit(_current_health)
	return _current_health


func get_current_health() -> int:
	return _current_health


func is_dead() -> bool:
	return _current_health <= 0


func get_health_ratio() -> float:
	return float(_current_health) / float(max_health)
