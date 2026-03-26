extends ActionState
class_name ActionIdle

## Idle action - player can move

func enter(_from: StringName) -> void:
	_play_animation(_get_idle_animation())

func can_move() -> bool:
	return true

func update(delta: float) -> void:
	pass

func _get_idle_animation() -> StringName:
	if _player and _player.has_method("get_active_form_id"):
		var form: StringName = _player.get_active_form_id()
		return StringName(String(form).to_lower() + "_idle")
	return &"idle"