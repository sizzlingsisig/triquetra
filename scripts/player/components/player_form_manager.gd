extends Node
class_name PlayerFormManager

@export var coyote_time_window: float = 0.12

enum GuardianForm {
	SWORD,
	SPEAR,
	BOW,
}

const FORM_ORDER: Array[StringName] = [&"Sword", &"Spear", &"Bow"]
const FORM_ENUM_ORDER: Array[GuardianForm] = [
	GuardianForm.SWORD,
	GuardianForm.SPEAR,
	GuardianForm.BOW,
]
const FORM_ENUM_TO_ID: Dictionary = {
	GuardianForm.SWORD: &"Sword",
	GuardianForm.SPEAR: &"Spear",
	GuardianForm.BOW: &"Bow",
}
const FORM_ID_TO_ENUM: Dictionary = {
	&"Sword": GuardianForm.SWORD,
	&"Spear": GuardianForm.SPEAR,
	&"Bow": GuardianForm.BOW,
}

var _player: PlayerController
var _states: Dictionary = {}
var _active_form_enum: GuardianForm = GuardianForm.SWORD
var _active_state: Node
var _lock_event_processed: Dictionary = {}
var _swap_coyote_remaining: float = 0.0

func _form_enum_to_id(form_enum: GuardianForm) -> StringName:
	if FORM_ENUM_TO_ID.has(form_enum):
		return FORM_ENUM_TO_ID[form_enum]
	return &""

func _form_id_to_enum(form_id: StringName) -> GuardianForm:
	if FORM_ID_TO_ENUM.has(form_id):
		return FORM_ID_TO_ENUM[form_id]
	return GuardianForm.SWORD

func setup(player: PlayerController) -> void:
	_player = player
	_reset_lock_event_tracking()

func cache_states(states_root: Node) -> void:
	for child in states_root.get_children():
		if child.has_method("setup") and child.has_method("receive_lethal_damage"):
			var state: Node = child
			var form_id_value: Variant = state.get("form_id")
			if not (form_id_value is StringName):
				continue

			var form_id: StringName = form_id_value
			if form_id.is_empty() or not FORM_ID_TO_ENUM.has(form_id):
				continue

			var form_enum: GuardianForm = FORM_ID_TO_ENUM[form_id]
			_states[form_enum] = state

	for state in _states.values():
		var guardian_state: Node = state
		if not guardian_state.has_signal("guardian_locked"):
			continue
		if not guardian_state.guardian_locked.is_connected(_on_guardian_locked):
			guardian_state.guardian_locked.connect(_on_guardian_locked)

func initialize_state_contexts(game_manager: Node) -> void:
	for state in _states.values():
		(state as Node).setup(_player, game_manager)

func sync_state_locks_from_manager(game_manager: Node) -> void:
	if not game_manager:
		return
	for form_enum in FORM_ENUM_ORDER:
		if _states.has(form_enum):
			var form_id: StringName = FORM_ENUM_TO_ID[form_enum]
			(_states[form_enum] as Node).is_locked = game_manager.is_guardian_locked(form_id)

func activate_first_available_state(game_manager: Node) -> void:
	for form_enum in FORM_ENUM_ORDER:
		var form_id: StringName = FORM_ENUM_TO_ID[form_enum]
		if not is_form_locked(form_id, game_manager):
			set_active_form(form_id, game_manager)
			return

	if game_manager:
		if game_manager.has_method("request_game_over"):
			game_manager.request_game_over(&"no_guardians_remaining")
		else:
			game_manager.request_timeline_reset(&"no_guardians_remaining")

func get_active_form_id() -> StringName:
	return _form_enum_to_id(_active_form_enum)

func get_active_state() -> Node:
	return _active_state

func set_active_form(next_form: StringName, game_manager: Node) -> void:
	if not FORM_ID_TO_ENUM.has(next_form):
		return
	var next_form_enum: GuardianForm = _form_id_to_enum(next_form)
	if not _states.has(next_form_enum):
		return
	if is_form_locked(next_form, game_manager):
		_player._log_debug("Skipped activating locked form: %s" % String(next_form))
		return

	if _player.runtime_fsm:
		_player.runtime_fsm.on_switch_started()

	var previous_form: StringName = _form_enum_to_id(_active_form_enum)
	if _active_state:
		_active_state.exit(next_form)

	_active_form_enum = next_form_enum
	_active_state = _states[next_form_enum] as Node
	_active_state.enter(previous_form)
	_player.form_changed.emit(_form_enum_to_id(_active_form_enum))
	_player._log_debug("Active form changed: %s -> %s" % [String(previous_form), String(_form_enum_to_id(_active_form_enum))])

	if _player._animation_manager:
		_player._animation_manager.set_form(_form_enum_to_id(_active_form_enum))

	if _player.runtime_fsm:
		_player.runtime_fsm.on_switch_finished()

func request_swap(direction: int, game_manager: Node) -> void:
	if FORM_ENUM_ORDER.is_empty():
		return

	_swap_coyote_remaining = coyote_time_window
	var start_index := FORM_ENUM_ORDER.find(_active_form_enum)
	if start_index < 0:
		start_index = 0

	for step in range(1, FORM_ENUM_ORDER.size() + 1):
		var idx := (start_index + (direction * step) + FORM_ENUM_ORDER.size()) % FORM_ENUM_ORDER.size()
		var candidate_enum: GuardianForm = FORM_ENUM_ORDER[idx]
		var candidate_form: StringName = FORM_ENUM_TO_ID[candidate_enum]
		if not is_form_locked(candidate_form, game_manager):
			set_active_form(candidate_form, game_manager)
			return

	if game_manager:
		if game_manager.has_method("request_game_over"):
			game_manager.request_game_over(&"no_guardians_remaining")
		else:
			game_manager.request_timeline_reset(&"no_guardians_remaining")

func request_action(action_name: StringName) -> bool:
	if not _player._can_process_combat():
		return false
	if not _active_state:
		return false
	if not _active_state.can_accept_action(action_name):
		return false
	return _active_state.handle_action(action_name)

func is_form_locked(form_id: StringName, game_manager: Node) -> bool:
	if game_manager and game_manager.has_method("is_guardian_locked"):
		return game_manager.is_guardian_locked(form_id)
	if FORM_ID_TO_ENUM.has(form_id):
		var form_enum: GuardianForm = FORM_ID_TO_ENUM[form_id]
		if not _states.has(form_enum):
			return true
		var state: Node = _states[form_enum] as Node
		var lock_value: Variant = state.get("is_locked")
		if lock_value is bool:
			return lock_value
	return true

func _on_guardian_locked(form_id: StringName) -> void:
	if _player._game_manager and _player._game_manager.has_method("lock_guardian"):
		_player._game_manager.lock_guardian(form_id)
		return
	handle_guardian_locked(form_id, &"state")

func handle_guardian_locked(form_id: StringName, source: StringName) -> void:
	if FORM_ID_TO_ENUM.has(form_id):
		var form_enum: GuardianForm = FORM_ID_TO_ENUM[form_id]
		if _states.has(form_enum):
			(_states[form_enum] as Node).is_locked = true

	if _lock_event_processed.get(form_id, false):
		return

	_lock_event_processed[form_id] = true
	_player.form_locked.emit(form_id)
	_player._log_debug("Guardian locked (%s): %s" % [String(source), String(form_id)])

	if form_id == _form_enum_to_id(_active_form_enum):
		request_swap(+1, _player._game_manager)

func _reset_lock_event_tracking() -> void:
	_lock_event_processed.clear()
	for form_id in FORM_ID_TO_ENUM.keys():
		_lock_event_processed[form_id] = false

func update(delta: float) -> void:
	if _swap_coyote_remaining > 0.0:
		_swap_coyote_remaining -= delta

	if _active_state and _player._can_process_combat():
		_active_state.update(delta)

func physics_update(delta: float) -> void:
	if _active_state and _player._can_process_combat():
		_active_state.physics_update(delta)

func get_locked_forms_for_debug(game_manager: Node) -> PackedStringArray:
	var locked: PackedStringArray = []
	if game_manager and game_manager.has_method("get_locked_forms"):
		for form_id in game_manager.get_locked_forms():
			locked.append(String(form_id))
		return locked

	for form_enum in FORM_ENUM_ORDER:
		if _states.has(form_enum) and (_states[form_enum] as Node).is_locked:
			locked.append(String(FORM_ENUM_TO_ID[form_enum]))
	return locked

func reset() -> void:
	_swap_coyote_remaining = 0.0
	_reset_lock_event_tracking()
