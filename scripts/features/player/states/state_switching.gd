class_name StateSwitching
extends PlayerStateNode

const Fsm = preload("res://scripts/features/player/player_fsm.gd")

func _ready() -> void:
	state_id = Fsm.PlayerStates.SWITCHING

func enter(_prev: int) -> void:
	_controller.play_animation("idle")

func can_accept_command(_cmd: StringName) -> bool:
	return false  # All commands blocked during swap

func handle_action(_cmd: StringName) -> bool:
	return false  # No actions during swap

func physics_update(_delta: float) -> void:
	_controller.velocity = Vector2.ZERO  # Brief frozen moment
	# Auto-exit to IDLE — the swap is complete, enable normal gameplay
	_fsm.force_state(Fsm.PlayerStates.IDLE, &"form_swap_complete")
