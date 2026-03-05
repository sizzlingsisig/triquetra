extends "res://scripts/player/states/base_guardian_state.gd"
class_name StateSword

const PRIMARY_ATTACK_ANIMATIONS: Array[StringName] = [
	&"sword_attack",
	&"sword_attack2",
	&"sword_attack3"
]

var _primary_attack_index: int = 0

func _ready() -> void:
	form_id = &"Sword"

func enter(_previous_form: StringName) -> void:
	_primary_attack_index = 0
	_play_animation(&"sword_idle")

func handle_action(action_name: StringName) -> bool:
	if is_locked:
		return false

	match action_name:
		&"primary_attack":
			return _play_next_primary_attack()
		&"special":
			_play_animation(&"sword_block")
			return true
		_:
			return false

func _play_next_primary_attack() -> bool:
	for _attempt in range(PRIMARY_ATTACK_ANIMATIONS.size()):
		var animation_name := PRIMARY_ATTACK_ANIMATIONS[_primary_attack_index]
		_primary_attack_index = (_primary_attack_index + 1) % PRIMARY_ATTACK_ANIMATIONS.size()
		if _play_first_available([animation_name]):
			return true

	return false
