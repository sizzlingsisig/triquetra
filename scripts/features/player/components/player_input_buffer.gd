extends Node
class_name PlayerInputBuffer

@export var action_move_left: StringName = &"move_left"
@export var action_move_right: StringName = &"move_right"
@export var action_attack: StringName = &"attack"
@export var action_special: StringName = &"special"
@export var action_jump: StringName = &"jump"
@export var action_swap_next: StringName = &"swap_next"
@export var action_swap_prev: StringName = &"swap_prev"
@export var action_pause: StringName = &"ui_cancel"

@export var input_buffer_window: float = 0.12

const COMMAND_SWAP_NEXT: StringName = &"swap_next"
const COMMAND_SWAP_PREV: StringName = &"swap_prev"
const COMMAND_PRIMARY_ATTACK: StringName = &"primary_attack"
const COMMAND_SPECIAL: StringName = &"special"
const COMMAND_JUMP: StringName = &"jump"

var _buffered_command_id: StringName = &""
var _buffered_command_time_left: float = 0.0
var _player: PlayerController

func _is_command_allowed(_command_id: StringName) -> bool:
	if _player and _player.runtime_fsm:
		var state: int = _player.runtime_fsm.get_state()
		if state == PlayerRuntimeFsm.PlayerStates.DEAD \
		or state == PlayerRuntimeFsm.PlayerStates.STUNNED \
		or state == PlayerRuntimeFsm.PlayerStates.SWITCHING:
			return false
	return true

func setup(player: PlayerController) -> void:
	_player = player
	# We want to capture input early
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed(): pass
	if not _player:
		return

	if _is_action_pressed(event, action_pause):
		var game_state: Node = get_node_or_null("/root/GameStateMachine")
		if game_state and game_state.has_method("toggle_pause"):
			game_state.toggle_pause()
		return

	if _player.is_game_over_state():
		if _is_action_pressed(event, action_attack) or _is_action_pressed(event, action_jump) or _is_action_pressed(event, action_special):
			var game_manager: Node = get_node_or_null("/root/GameManager")
			if game_manager and game_manager.has_method("request_timeline_reset"):
				game_manager.request_timeline_reset(&"player_retry")
		return

	if not _player.can_process_combat():
		return

	if _buffer_if_action_pressed(event, action_swap_next, COMMAND_SWAP_NEXT):
		_player.swap_to_next_form()
		return
	if _buffer_if_action_pressed(event, action_swap_prev, COMMAND_SWAP_PREV):
		_player.swap_to_prev_form()
		return
	if _buffer_if_action_pressed(event, action_attack, COMMAND_PRIMARY_ATTACK):
		return
	if _buffer_if_action_pressed(event, action_special, COMMAND_SPECIAL):
		return
	if _buffer_if_action_pressed(event, action_jump, COMMAND_JUMP):
		return

func _is_action_pressed(event: InputEvent, action_name: StringName) -> bool:
	if action_name.is_empty() or not InputMap.has_action(action_name):
		return false
	return event.is_action_pressed(action_name, true)

func _buffer_if_action_pressed(event: InputEvent, action_name: StringName, command_id: StringName) -> bool:
	if not _is_action_pressed(event, action_name):
		return false
	if not _is_command_allowed(command_id):
		return true
	_buffer_command(command_id)
	return true

func _buffer_command(command_id: StringName) -> void:
	_buffered_command_id = command_id
	_buffered_command_time_left = input_buffer_window

func _expire_buffer(delta: float) -> void:
	if _buffered_command_id.is_empty():
		return

	_buffered_command_time_left -= delta
	if _buffered_command_time_left <= 0.0:
		clear()

func process_buffer(delta: float) -> void:
	if not _player:
		return

	_expire_buffer(delta)
	if _buffered_command_id.is_empty():
		return

	if not _is_command_allowed(_buffered_command_id):
		return

	if _player._try_execute_command(_buffered_command_id):
		clear()

func clear() -> void:
	_buffered_command_id = &""
	_buffered_command_time_left = 0.0

func get_buffered_command_for_debug() -> String:
	if _buffered_command_id.is_empty():
		return "<none>"
	return String(_buffered_command_id)

func get_action_state_for_debug() -> String:
	if _player and _player.runtime_fsm:
		return str(_player.runtime_fsm.get_state())
	return "<none>"
