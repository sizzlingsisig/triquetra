class_name StateJumping
extends PlayerStateNode

const Fsm = preload("res://scripts/features/player/player_fsm.gd")

func _ready() -> void:
	state_id = Fsm.PlayerStateNode.JUMPING

func enter(_prev: int) -> void:
	_controller.play_animation("jump")

func can_accept_command(cmd: StringName) -> bool:
	return cmd == Fsm.COMMAND_PRIMARY_ATTACK or cmd == Fsm.COMMAND_SPECIAL

func handle_action(cmd: StringName) -> bool:
	match cmd:
		Fsm.COMMAND_PRIMARY_ATTACK:
			if _controller.form_id == &"Bow":
				_controller.spawn_arrow()
				_controller.play_animation(&"shot")
				_fsm.force_state(Fsm.PlayerStateNode.BOW_ATTACK, cmd)
			else:
				_controller.spawn_hitbox()
			return true
		Fsm.COMMAND_SPECIAL:
			match _controller.form_id:
				&"Bow":
					_controller.play_animation(&"evasion")
					_fsm.force_state(Fsm.PlayerStateNode.EVASION, cmd)
				&"Spear":
					_controller.play_animation(&"run_attack")
					_fsm.force_state(Fsm.PlayerStateNode.SPECIAL, cmd)
				&"Sword":
					_controller.play_animation(&"block")
					_fsm.force_state(Fsm.PlayerStateNode.SPECIAL, cmd)
			return true
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
			_fsm.force_state(Fsm.PlayerStateNode.RUNNING, &"landed_moving")
		else:
			_fsm.force_state(Fsm.PlayerStateNode.IDLE, &"landed")