extends Node
class_name BaseGuardianState

signal guardian_locked(form_id: StringName)

@export var form_id: StringName

var is_locked: bool = false
var is_busy: bool = false

var _player: CharacterBody2D
var _game_manager: Node

func setup(player: CharacterBody2D, game_manager: Node) -> void:
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
	return (not is_locked) and (not is_busy)

func handle_action(_action_name: StringName) -> bool:
	return false

func receive_lethal_damage() -> void:
	if is_locked:
		return

	is_locked = true
	if _game_manager:
		_game_manager.lock_guardian(form_id)
	guardian_locked.emit(form_id)

func _play_animation(animation_name: StringName, reset_frame: bool = true) -> void:
	if not _player:
		return
	if _player.has_method("play_guardian_animation"):
		_player.play_guardian_animation(animation_name, reset_frame)

func _has_animation(animation_name: StringName) -> bool:
	if not _player:
		return false

	var guardian_sprite := _player.get_node_or_null("GuardianSprite") as AnimatedSprite2D
	if not guardian_sprite:
		return false
	if not guardian_sprite.sprite_frames:
		return false

	return guardian_sprite.sprite_frames.has_animation(animation_name)

func _play_first_available(animation_names: Array[StringName], reset_frame: bool = true) -> bool:
	for animation_name in animation_names:
		if _has_animation(animation_name):
			_play_animation(animation_name, reset_frame)
			return true

	return false
