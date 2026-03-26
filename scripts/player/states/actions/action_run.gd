extends ActionState
class_name ActionRun

func enter(_from: StringName) -> void:
	_play_animation(_get_run_animation())

func can_move() -> bool:
	return true

func _get_run_animation() -> StringName:
	if _player and _player.has_method("get_active_form_id"):
		var form: StringName = _player.get_active_form_id()
		return StringName(String(form).to_lower() + "_run")
	return &"run"