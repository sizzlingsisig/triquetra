class_name StateRunning
extends PlayerStateNode

func _ready() -> void:
	state_id = Fsm.PlayerStates.RUNNING

func enter(_prev: int) -> void:
	var move_anim: StringName = &"walk" if _controller.form_id == &"Bow" else &"run"
	_controller.play_animation(move_anim)

func can_accept_command(cmd: StringName) -> bool:
	return cmd == Fsm.COMMAND_PRIMARY_ATTACK or cmd == Fsm.COMMAND_SPECIAL or cmd == Fsm.COMMAND_JUMP or cmd == Fsm.COMMAND_SWAP_NEXT or cmd == Fsm.COMMAND_SWAP_PREV

func handle_action(cmd: StringName) -> bool:
	match cmd:
		Fsm.COMMAND_PRIMARY_ATTACK:
			return execute_primary_attack()
		Fsm.COMMAND_SPECIAL:
			return execute_special()
		Fsm.COMMAND_JUMP:
			return execute_jump()
		Fsm.COMMAND_SWAP_NEXT:
			return execute_swap_next()
		Fsm.COMMAND_SWAP_PREV:
			return execute_swap_prev()
	return false

func physics_update(delta: float) -> void:
	if _movement:
		_movement.apply_movement(delta)
	if absf(_controller.velocity.x) <= 4.0:
		_fsm.force_state(Fsm.PlayerStates.IDLE, &"stopped")
	elif not _controller.is_on_floor():
		_fsm.force_state(Fsm.PlayerStates.JUMPING, &"falling")