class_name StateRunning
extends PlayerStateNode

const Fsm = preload("res://scripts/features/player/player_fsm.gd")

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
			if _controller.form_id == &"Bow":
				_controller.spawn_arrow()
				_controller.play_animation(&"shot")
				_fsm.force_state(Fsm.PlayerStates.BOW_ATTACK, cmd)
			else:
				_controller.spawn_hitbox()
				_controller.play_animation(&"run_attack")
				_fsm.force_state(Fsm.PlayerStates.ATTACKING, cmd)
			return true
		Fsm.COMMAND_SPECIAL:
			match _controller.form_id:
				&"Bow":
					_controller.play_animation(&"evasion")
					_fsm.force_state(Fsm.PlayerStates.EVASION, cmd)
				&"Sword":
					_controller.play_animation(&"block")
					_fsm.force_state(Fsm.PlayerStates.SPECIAL, cmd)
				&"Spear":
					_controller.play_animation(&"run_attack")
					_fsm.force_state(Fsm.PlayerStates.SPECIAL, cmd)
			return true
		Fsm.COMMAND_JUMP:
			_controller.jump()
			if _movement:
				_movement.try_start_jump()
			_fsm.force_state(Fsm.PlayerStates.JUMPING, cmd)
			return true
		Fsm.COMMAND_SWAP_NEXT:
			_controller.swap_to_next_form()
			return true
		Fsm.COMMAND_SWAP_PREV:
			_controller.swap_to_prev_form()
			return true
	return false

func physics_update(delta: float) -> void:
	if _movement:
		_movement.apply_movement(delta)
	if absf(_controller.velocity.x) <= 4.0:
		_fsm.force_state(Fsm.PlayerStates.IDLE, &"stopped")
	elif not _controller.is_on_floor():
		_fsm.force_state(Fsm.PlayerStates.JUMPING, &"falling")