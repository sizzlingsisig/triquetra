extends Node
class_name StateMachine

## Generic state machine for managing game entity states.
## Supports adding states, transitions, and delegation of lifecycle methods.

signal state_changed(from: StringName, to: StringName)
signal state_entered(state_id: StringName)
signal state_exited(state_id: StringName)

@export var initial_state: StringName = &""

var _states: Dictionary = {}
var _current_state: BaseState = null
var _owner: Node = null

func _ready() -> void:
	if _owner and _owner.has_method(&"set_state_machine"):
		_owner.set_state_machine(self)

func setup(owner_node: Node) -> void:
	_owner = owner_node
	_initialize_states()

func _initialize_states() -> void:
	if _states.is_empty():
		return
	
	for id in _states:
		var state: BaseState = _states[id]
		if state.has_method(&"_initialize"):
			state._initialize()
	
	if not initial_state.is_empty() and _states.has(initial_state):
		set_state(initial_state)

func add_state(id: StringName, state: BaseState) -> void:
	state.state_machine = self
	state.owner_node = _owner
	state.name = String(id)
	add_child(state)
	_states[id] = state
	if state.has_method(&"_state_added"):
		state._state_added(id)
	_connect_state_signals(state, id)

func _connect_state_signals(state: BaseState, _id: StringName) -> void:
	if state.has_signal(&"state_transition_requested"):
		if not state.state_transition_requested.is_connected(_on_state_transition_requested):
			state.state_transition_requested.connect(_on_state_transition_requested)

func _on_state_transition_requested(target_state: StringName) -> void:
	set_state(target_state)

func has_state(id: StringName) -> bool:
	return _states.has(id)

func get_state(id: StringName) -> BaseState:
	return _states.get(id)

func get_current_state() -> BaseState:
	return _current_state

func get_owner_node() -> Node:
	return _owner

func is_in_state(id: StringName) -> bool:
	if _current_state:
		return _current_state.state_id == id
	return false

func get_current_state_id() -> StringName:
	if _current_state:
		return _current_state.state_id
	return &""

func get_state_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for id in _states:
		ids.append(id)
	return ids

func set_state(id: StringName, skip_enter: bool = false) -> bool:
	if not _states.has(id):
		push_warning("[StateMachine] No state registered: %s" % id)
		return false
	
	var new_state: BaseState = _states[id]
	if _current_state == new_state:
		return true
	
	var from_id: StringName = &""
	if _current_state:
		from_id = _current_state.state_id
		_current_state.exit(id)
		state_exited.emit(from_id)
	
	_current_state = new_state
	
	if not skip_enter:
		_current_state.enter(from_id)
		state_entered.emit(id)
	
	state_changed.emit(from_id, id)
	return true

func _physics_process(delta: float) -> void:
	_current_state_update(delta, &"_physics_process")

func _process(delta: float) -> void:
	_current_state_update(delta, &"_process")

func _unhandled_input(event: InputEvent) -> void:
	if _current_state and _current_state.has_method(&"handle_input"):
		_current_state.handle_input(event)

func _current_state_update(delta: float, method_name: StringName) -> void:
	if not _current_state:
		return
	
	if _current_state.has_method(method_name):
		_current_state.call(method_name, delta)
	
	var update_method: StringName
	if method_name == &"_physics_process":
		update_method = &"physics_update"
	else:
		update_method = &"update"
	
	if _current_state.has_method(update_method):
		_current_state.call(update_method, delta)
