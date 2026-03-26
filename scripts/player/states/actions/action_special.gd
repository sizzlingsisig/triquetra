extends ActionState
class_name ActionSpecial

## Special action - player cannot move during special (unless can_move_during is true)
## Automatically transitions to idle after duration expires

signal special_started()
signal special_finished()

@export var special_animation: StringName = &""
@export var can_move_during: bool = false
@export var duration: float = 0.5

var _duration_timer: SceneTreeTimer = null

func enter(_from: StringName) -> void:
	special_started.emit()
	if not special_animation.is_empty():
		_play_animation(special_animation)
	_connect_animation_finished()
	_start_duration_timer()

func can_move() -> bool:
	return can_move_during

func _connect_animation_finished() -> void:
	if _visuals_manager and _visuals_manager.has_method("get_sprite"):
		var sprite = _visuals_manager.get_sprite()
		if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)

func _start_duration_timer() -> void:
	if _player and _player.get_tree():
		_duration_timer = _player.get_tree().create_timer(duration)
		_duration_timer.timeout.connect(_on_duration_expired)

func _on_duration_expired() -> void:
	_on_animation_finished()

func _on_animation_finished() -> void:
	special_finished.emit()
	action_completed.emit(state_id)

func exit(_to: StringName) -> void:
	if _duration_timer:
		_duration_timer.timeout.disconnect(_on_duration_expired)
		_duration_timer = null