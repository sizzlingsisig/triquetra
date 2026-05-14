class_name StateJumping
extends PlayerStateNode

func _ready() -> void:
	state_id = Fsm.PlayerStates.JUMPING

func enter(_prev: int) -> void:
	_controller.play_animation("jump")

func can_accept_command(cmd: StringName) -> bool:
	return cmd == Fsm.COMMAND_PRIMARY_ATTACK or cmd == Fsm.COMMAND_SPECIAL

func handle_action(cmd: StringName) -> bool:
	match cmd:
		Fsm.COMMAND_PRIMARY_ATTACK:
			return execute_primary_attack(false)  # No force_state mid-air
		Fsm.COMMAND_SPECIAL:
			return execute_special()
	return false

func physics_update(delta: float) -> void:
	if _movement:
		_movement.apply_movement(delta)
	if _movement:
		_movement.apply_gravity(delta)
	if _movement:
		_movement.update_jump(delta)
	if _controller.is_on_floor():
		if _movement:
			_movement.stop_jump()
		var dir: float = Input.get_axis("move_left", "move_right")
		if absf(dir) > 0.0:
			_fsm.force_state(Fsm.PlayerStates.RUNNING, &"landed_moving")
		else:
			_fsm.force_state(Fsm.PlayerStates.IDLE, &"landed")