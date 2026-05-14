class_name StateDead
extends PlayerStateNode

func _ready() -> void:
	state_id = Fsm.PlayerStates.DEAD

func enter(_prev: int) -> void:
	_controller.play_death_animation()
	_controller.lock_guardian()

func can_accept_command(_cmd: StringName) -> bool:
	return false

func handle_action(_cmd: StringName) -> bool:
	return false