class_name PlayerStateNode extends Node

var state_id: int
var _fsm: PlayerRuntimeFsm
var _controller: PlayerController
var _movement: PlayerMovementComponent

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
