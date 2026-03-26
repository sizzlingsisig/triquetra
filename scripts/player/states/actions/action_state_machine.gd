extends Node
class_name ActionStateMachine

## Manages action states within a form (idle, run, attack, special).
## Handles transitions and blocks movement during specific actions.

signal action_changed(from_action: StringName, to_action: StringName)
signal action_started(action_id: StringName)
signal action_finished(action_id: StringName)

@export var initial_action: StringName = &"Idle"

var _actions: Dictionary = {}
var _current_action = null
var _player: CharacterBody2D = null
var _visuals_manager = null

func setup(player: CharacterBody2D, visuals_manager) -> void:
	_player = player
	_visuals_manager = visuals_manager

func add_action(id: StringName, action) -> void:
	action.setup(_player, _visuals_manager)
	action.action_completed.connect(_on_action_completed)
	_actions[id] = action

func set_action(id: StringName) -> bool:
	if not _actions.has(id):
		return false
	
	var previous_id: StringName = &""
	if _current_action:
		previous_id = _current_action.state_id
		_current_action.exit(id)
		action_finished.emit(previous_id)
	
	_current_action = _actions[id]
	_current_action.enter(previous_id)
	action_changed.emit(previous_id, id)
	action_started.emit(id)
	return true

func get_current_action():
	return _current_action

func can_player_move() -> bool:
	if _current_action and _current_action.has_method("can_move"):
		return _current_action.can_move()
	return true

func get_current_action_id() -> StringName:
	if _current_action:
		return _current_action.state_id
	return &""

func physics_update(delta: float) -> void:
	if _current_action and _current_action.has_method("physics_update"):
		_current_action.physics_update(delta)

func update(delta: float) -> void:
	if _current_action and _current_action.has_method("update"):
		_current_action.update(delta)

func _on_action_completed(action_id: StringName) -> void:
	action_finished.emit(action_id)
	set_action(&"Idle")