class_name StateDead
extends PlayerStateNode

const Fsm = preload("res://scripts/features/player/player_fsm.gd")

func _ready() -> void:
	state_id = Fsm.PlayerStateNode.DEAD

func enter(_prev: int) -> void:
	_controller.play_death_animation()
	_controller.lock_guardian()

func can_accept_command(_cmd: StringName) -> bool:
	return false

func handle_action(_cmd: StringName) -> bool:
	return false