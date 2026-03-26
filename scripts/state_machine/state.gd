extends Node
class_name BaseState

## Base class for all state machine states.
## Extend this class and implement the virtual methods.

signal state_transition_requested(target_state: StringName)

var state_id: StringName = &""
var state_machine: Node = null
var owner_node: Node = null

func enter(_from: StringName) -> void:
	pass

func exit(_to: StringName) -> void:
	pass

func _ready() -> void:
	if state_id.is_empty():
		state_id = _derive_state_id_from_class()

func _derive_state_id_from_class() -> StringName:
	var class_name: String = get_class()
	if class_name.begins_with("State"):
		class_name = class_name.substr(5)
	return StringName(class_name)

func can_accept_action(_action_name: StringName) -> bool:
	return true

func handle_action(_action_name: StringName) -> bool:
	return false

func physics_update(_delta: float) -> void:
	pass

func update(_delta: float) -> void:
	pass

func _request_transition(target_state: StringName) -> void:
	state_transition_requested.emit(target_state)
