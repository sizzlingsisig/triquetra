extends Node
class_name BaseGuardianState

## Base contract for all guardian forms.
## Derived states implement form-specific action handling and effects.

signal guardian_locked(form_id: StringName)

@export var form_id: StringName

var is_locked: bool = false
var is_busy: bool = false

var _player: CharacterBody2D
var _game_manager: Node

func setup(player: CharacterBody2D, game_manager: Node) -> void:
	# Injects runtime dependencies from PlayerController.
	_player = player
	_game_manager = game_manager

func enter(_previous_form: StringName) -> void:
	pass

func exit(_next_form: StringName) -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func can_accept_action(_action_name: StringName) -> bool:
	# Shared gate used by controller command consumption.
	return (not is_locked) and (not is_busy)

func handle_action(_action_name: StringName) -> bool:
	return false

func should_open_attack_window(action_name: StringName) -> bool:
	return action_name == &"primary_attack"

func receive_lethal_damage() -> void:
	# Play optional death animation before locking form state.
	if form_id and _has_animation(String(form_id).to_lower() + "_dead"):
		_play_animation(String(form_id).to_lower() + "_dead")
	_lock_guardian_once()

func _lock_guardian_once() -> bool:
	# Idempotent lock so duplicate lethal events do not double-emit.
	if is_locked:
		return false
	if _game_manager and _game_manager.has_method("is_guardian_locked") and _game_manager.is_guardian_locked(form_id):
		is_locked = true
		return false

	is_locked = true
	if _game_manager:
		_game_manager.lock_guardian(form_id)
	guardian_locked.emit(form_id)
	return true

func _play_animation(animation_name: StringName, reset_frame: bool = true) -> void:
	if not _player:
		return
	if _player.has_method("play_guardian_animation"):
		_player.play_guardian_animation(animation_name, reset_frame)

func _has_animation(animation_name: StringName) -> bool:
	if not _player:
		return false
	if _player.has_method("has_guardian_animation"):
		return _player.has_guardian_animation(animation_name)
	return false

func _play_first_available(animation_names: Array[StringName], reset_frame: bool = true) -> bool:
	for animation_name in animation_names:
		if _has_animation(animation_name):
			_play_animation(animation_name, reset_frame)
			return true

	return false
