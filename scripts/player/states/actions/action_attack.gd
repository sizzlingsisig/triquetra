extends ActionState
class_name ActionAttack

## Attack action - player cannot move during attack

signal attack_window_opened()
signal attack_window_closed()

@export var attack_animations: Array[StringName] = []
@export var attack_window_timing: Vector2 = Vector2(0.05, 0.2)

var _attack_index: int = 0
var _attack_timeline_played: bool = false

func enter(_from: StringName) -> void:
	_attack_timeline_played = false
	_connect_animation_finished()
	_play_attack_animation()
	_schedule_attack_window()

func _connect_animation_finished() -> void:
	if _visuals_manager and _visuals_manager.has_method("get_sprite"):
		var sprite = _visuals_manager.get_sprite()
		if sprite and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
			sprite.animation_finished.connect(_on_sprite_animation_finished)

func can_move() -> bool:
	return false

func physics_update(delta: float) -> void:
	pass

func _play_attack_animation() -> void:
	if attack_animations.is_empty():
		return
	var animation_name = attack_animations[_attack_index]
	_play_animation(animation_name)
	_attack_index = (_attack_index + 1) % attack_animations.size()

func _schedule_attack_window() -> void:
	if _player:
		var timer = _player.get_tree().create_timer(attack_window_timing.x)
		timer.timeout.connect(_on_attack_window_start)

func _on_attack_window_start() -> void:
	attack_window_opened.emit()
	if _player and _player.get_tree():
		var close_timer = _player.get_tree().create_timer(attack_window_timing.y - attack_window_timing.x)
		close_timer.timeout.connect(_on_attack_window_end)

func _on_attack_window_end() -> void:
	attack_window_closed.emit()
	action_completed.emit(state_id)

func _on_sprite_animation_finished() -> void:
	action_completed.emit(state_id)

func exit(_to: StringName) -> void:
	if _visuals_manager and _visuals_manager.has_method("get_sprite"):
		var sprite = _visuals_manager.get_sprite()
		if sprite and sprite.animation_finished.is_connected(_on_sprite_animation_finished):
			sprite.animation_finished.disconnect(_on_sprite_animation_finished)