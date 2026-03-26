extends Node
class_name FormManager

## Manages player form lifecycle: switching, locking, state machine integration.

signal form_changed(form_id: StringName)
signal form_locked(form_id: StringName)
signal state_initialized(form_id: StringName)

const FORM_ORDER: Array[StringName] = [
	&"Sword",
	&"Spear",
	&"Bow"
]

var _player: CharacterBody2D = null
var _game_manager: Node = null
var _visuals_manager = null

var _states: Dictionary = {}
var _active_form: StringName = &"Sword"
var _active_state: Node = null
var _lock_event_processed: Dictionary = {}

var _states_root: Node = null

func setup(player: CharacterBody2D, game_manager: Node, states_root: Node, visuals_manager = null) -> void:
	_player = player
	_game_manager = game_manager
	_states_root = states_root
	_visuals_manager = visuals_manager
	_reset_lock_event_tracking()
	_cache_states()
	_connect_state_signals()
	_initialize_state_contexts()
	_sync_state_locks_from_manager()

func _cache_states() -> void:
	if not _states_root:
		return
	for child in _states_root.get_children():
		if child.has_method("setup") and child.has_method("receive_lethal_damage"):
			var state: Node = child
			_states[state.form_id] = state

func _connect_state_signals() -> void:
	for state in _states.values():
		var guardian_state: Node = state
		if guardian_state.has_signal("guardian_locked"):
			if not guardian_state.guardian_locked.is_connected(_on_guardian_locked):
				guardian_state.guardian_locked.connect(_on_guardian_locked)

func _initialize_state_contexts() -> void:
	for state in _states.values():
		(state as Node).setup(_player, _game_manager)
		state_initialized.emit(state.form_id)

func set_initial_form(form_id: StringName) -> void:
	if form_id.is_empty() or form_id == &"":
		form_id = &"Sword"
	_activate_first_available_state(form_id)

func _activate_first_available_state(_initial_form: StringName = &"Sword") -> void:
	for form_id in FORM_ORDER:
		if not _is_form_locked(form_id):
			_set_active_form(form_id)
			return
	
	if _game_manager and _game_manager.has_method("request_timeline_reset"):
		_game_manager.request_timeline_reset(&"no_guardians_remaining")

func _set_active_form(next_form: StringName) -> bool:
	if not _states.has(next_form):
		return false
	if _is_form_locked(next_form):
		return false

	var previous_form := _active_form
	if _active_state:
		_active_state.exit(next_form)

	_active_form = next_form
	_active_state = _states[next_form] as Node
	_active_state.enter(previous_form)
	form_changed.emit(_active_form)

	if _visuals_manager:
		_visuals_manager.set_form(_active_form)

	return true

func request_swap(direction: int) -> bool:
	if FORM_ORDER.is_empty():
		return false

	var start_index := FORM_ORDER.find(_active_form)
	if start_index < 0:
		start_index = 0

	for step in range(1, FORM_ORDER.size() + 1):
		var idx := (start_index + (direction * step) + FORM_ORDER.size()) % FORM_ORDER.size()
		var candidate := FORM_ORDER[idx]
		if _set_active_form(candidate):
			return true

	if _game_manager and _game_manager.has_method("request_timeline_reset"):
		_game_manager.request_timeline_reset(&"no_guardians_remaining")
	return false

func handle_action(action_name: StringName) -> bool:
	if not _active_state:
		return false
	if not _active_state.can_accept_action(action_name):
		return false
	return _active_state.handle_action(action_name)

func can_accept_action(action_name: StringName) -> bool:
	if not _active_state:
		return false
	return _active_state.can_accept_action(action_name)

func physics_update(delta: float) -> void:
	if _active_state and _active_state.has_method("physics_update"):
		_active_state.physics_update(delta)

func update(delta: float) -> void:
	if _active_state and _active_state.has_method("update"):
		_active_state.update(delta)

func receive_lethal_damage() -> void:
	if _active_state and _active_state.has_method("receive_lethal_damage"):
		_active_state.receive_lethal_damage()

func _is_form_locked(form_id: StringName) -> bool:
	if _game_manager:
		return _game_manager.is_guardian_locked(form_id)
	if _states.has(form_id):
		return (_states[form_id] as Node).is_locked
	return true

func _on_guardian_locked(form_id: StringName) -> void:
	if _game_manager and _game_manager.has_method("lock_guardian"):
		_game_manager.lock_guardian(form_id)
	_handle_guardian_locked(form_id, &"state")

func _on_manager_guardian_locked(form_id: StringName) -> void:
	_handle_guardian_locked(form_id, &"manager")

func _handle_guardian_locked(form_id: StringName, _source: StringName) -> void:
	if _states.has(form_id):
		(_states[form_id] as Node).is_locked = true

	if _lock_event_processed.get(form_id, false):
		return

	_lock_event_processed[form_id] = true
	form_locked.emit(form_id)

	if form_id == _active_form:
		request_swap(+1)

func _sync_state_locks_from_manager() -> void:
	if not _game_manager:
		return
	for form_id in FORM_ORDER:
		if _states.has(form_id):
			(_states[form_id] as Node).is_locked = _game_manager.is_guardian_locked(form_id)

func _reset_lock_event_tracking() -> void:
	_lock_event_processed.clear()
	for form_id in FORM_ORDER:
		_lock_event_processed[form_id] = false

func reset() -> void:
	_active_form = &"Sword"
	_active_state = null
	_reset_lock_event_tracking()
	_sync_state_locks_from_manager()

func get_active_form_id() -> StringName:
	return _active_form

func get_active_state() -> Node:
	return _active_state

func get_locked_forms() -> PackedStringArray:
	var locked: PackedStringArray = []
	if _game_manager and _game_manager.has_method("get_locked_forms"):
		return _game_manager.get_locked_forms()
	for form_id in FORM_ORDER:
		if _states.has(form_id) and (_states[form_id] as Node).is_locked:
			locked.append(form_id)
	return locked