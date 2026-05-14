class_name PlayerStateNode extends Node

var state_id: int
var _fsm: PlayerRuntimeFsm
var _controller: PlayerController
var _movement: PlayerMovementComponent

const Fsm = preload("res://scripts/features/player/player_fsm.gd")

func setup(fsm: PlayerRuntimeFsm, controller: PlayerController) -> void:
	_fsm = fsm
	_controller = controller
	_movement = controller.get_node_or_null("MovementComponent") as PlayerMovementComponent

func enter(_prev: int) -> void:
	pass

func exit(_next: int) -> void:
	pass

func can_accept_command(_cmd: StringName) -> bool:
	return true

func handle_action(_cmd: StringName) -> bool:
	return false

func physics_update(_delta: float) -> void:
	pass

func update(_delta: float) -> void:
	pass

## Shared: execute a primary attack. Returns true if handled.
## [param force_transition] If false, skips the ATTACKING state transition
## (used by StateJumping where the player stays mid-air without state change).
func execute_primary_attack(force_transition: bool = true) -> bool:
	if _controller.form_id == &"Bow":
		_controller.spawn_arrow()
		_controller.play_animation(&"shot")
		_fsm.force_state(Fsm.PlayerStates.BOW_ATTACK, Fsm.COMMAND_PRIMARY_ATTACK)
	else:
		_controller.spawn_hitbox()
		if _controller.form_id == &"Spear":
			_controller.play_animation(&"run_attack")
		else:
			_controller.play_animation(&"attack")
		if force_transition:
			_fsm.force_state(Fsm.PlayerStates.ATTACKING, Fsm.COMMAND_PRIMARY_ATTACK)
	return true


## Shared: execute a special action based on form. Returns true if handled.
func execute_special() -> bool:
	match _controller.form_id:
		&"Bow":
			_controller.play_animation(&"evasion")
			_fsm.force_state(Fsm.PlayerStates.EVASION, Fsm.COMMAND_SPECIAL)
		&"Sword":
			_controller.play_animation(&"block")
			_fsm.force_state(Fsm.PlayerStates.SPECIAL, Fsm.COMMAND_SPECIAL)
		&"Spear":
			_controller.play_animation(&"run_attack")
			_fsm.force_state(Fsm.PlayerStates.SPECIAL, Fsm.COMMAND_SPECIAL)
	return true


## Shared: execute a jump action. Returns true if handled.
func execute_jump() -> bool:
	_controller.jump()
	if _movement:
		_movement.try_start_jump()
	_fsm.force_state(Fsm.PlayerStates.JUMPING, Fsm.COMMAND_JUMP)
	return true


## Shared: swap to next form.
func execute_swap_next() -> bool:
	_controller.swap_to_next_form()
	return true


## Shared: swap to previous form.
func execute_swap_prev() -> bool:
	_controller.swap_to_prev_form()
	return true
