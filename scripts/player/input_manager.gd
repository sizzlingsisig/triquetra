extends Node
class_name InputManager

## Manages player input buffering and command execution.

signal command_executed(command_id: StringName)
signal action_requested(action_name: StringName)

@export var input_buffer_window: float = 0.12

@export var action_move_left: StringName = &"ui_left"
@export var action_move_right: StringName = &"ui_right"
@export var action_attack: StringName = &"attack"
@export var action_special: StringName = &"special"
@export var action_jump: StringName = &"jump"
@export var action_swap_next: StringName = &"swap_next"
@export var action_swap_prev: StringName = &"swap_prev"

const COMMAND_SWAP_NEXT: StringName = &"swap_next"
const COMMAND_SWAP_PREV: StringName = &"swap_prev"
const COMMAND_PRIMARY_ATTACK: StringName = &"primary_attack"
const COMMAND_SPECIAL: StringName = &"special"
const COMMAND_JUMP: StringName = &"jump"

var _command_buffer: Array[Dictionary] = []
var _owner: Node = null
var _action_callback: Callable = Callable()

func setup(owner_node: Node, action_callback: Callable) -> void:
	_owner = owner_node
	_action_callback = action_callback

func _unhandled_input(event: InputEvent) -> void:
	if _is_action_just_pressed(event, action_swap_next):
		_buffer_command(COMMAND_SWAP_NEXT)
		return
	if _is_action_just_pressed(event, action_swap_prev):
		_buffer_command(COMMAND_SWAP_PREV)
		return
	if _is_action_just_pressed(event, action_attack):
		_buffer_command(COMMAND_PRIMARY_ATTACK)
		return
	if _is_action_just_pressed(event, action_special):
		_buffer_command(COMMAND_SPECIAL)
		return
	if _is_action_just_pressed(event, action_jump):
		_buffer_command(COMMAND_JUMP)
		return

func consume_command_buffer(delta: float) -> bool:
	for i in range(_command_buffer.size() - 1, -1, -1):
		var cmd: Dictionary = _command_buffer[i]
		cmd["time_left"] = float(cmd["time_left"]) - delta
		if cmd["time_left"] <= 0.0:
			_command_buffer.remove_at(i)
		else:
			_command_buffer[i] = cmd

	if _command_buffer.is_empty():
		return false

	for i in range(_command_buffer.size()):
		var command_id: StringName = _command_buffer[i]["id"]
		if _try_execute_command(command_id):
			_command_buffer.remove_at(i)
			return true

	return false

func _try_execute_command(command_id: StringName) -> bool:
	match command_id:
		COMMAND_SWAP_NEXT, COMMAND_SWAP_PREV, COMMAND_JUMP:
			command_executed.emit(command_id)
			return true
		COMMAND_PRIMARY_ATTACK, COMMAND_SPECIAL:
			if _action_callback.is_valid():
				var result = _action_callback.call(command_id)
				if result is bool and result:
					action_requested.emit(command_id)
					return true
				if result:
					action_requested.emit(command_id)
					return true
			return false
	return true

func _buffer_command(command_id: StringName) -> void:
	for i in range(_command_buffer.size()):
		if _command_buffer[i]["id"] == command_id:
			_command_buffer[i]["time_left"] = input_buffer_window
			return
	_command_buffer.append({
		"id": command_id,
		"time_left": input_buffer_window
	})

func _is_action_just_pressed(event: InputEvent, action_name: StringName) -> bool:
	if action_name.is_empty():
		return false
	if not InputMap.has_action(action_name):
		return false
	return event.is_action_pressed(action_name)

func get_buffered_command() -> StringName:
	if _command_buffer.is_empty():
		return &""
	return _command_buffer[0]["id"]

func clear_buffer() -> void:
	_command_buffer.clear()

func get_input_direction() -> float:
	return Input.get_axis(action_move_left, action_move_right)