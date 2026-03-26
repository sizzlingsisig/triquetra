extends BaseState
class_name ActionState

## Base class for player action states (idle, run, attack, special).
## Used within a form to manage action interactions (e.g., can't move during attack).

signal action_completed(action_id: StringName)

var _player: CharacterBody2D = null
var _visuals_manager = null

func setup(player: CharacterBody2D, visuals_manager) -> void:
	_player = player
	_visuals_manager = visuals_manager

func can_move() -> bool:
	return false

func _play_animation(animation_name: StringName, reset_frame: bool = true) -> void:
	if _visuals_manager and _visuals_manager.has_method("play_animation"):
		_visuals_manager.play_animation(animation_name, reset_frame)
	elif _player and _player.has_method("play_guardian_animation"):
		_player.play_guardian_animation(animation_name, reset_frame)

func _has_animation(animation_name: StringName) -> bool:
	if _visuals_manager and _visuals_manager.has_method("has_animation"):
		return _visuals_manager.has_animation(animation_name)
	if _player and _player.has_method("has_guardian_animation"):
		return _player.has_guardian_animation(animation_name)
	return false

func _play_first_available(animations: Array[StringName], reset_frame: bool = true) -> bool:
	for anim in animations:
		if _has_animation(anim):
			_play_animation(anim, reset_frame)
			return true
	return false