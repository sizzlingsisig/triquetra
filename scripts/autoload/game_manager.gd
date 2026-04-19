extends Node

## Global run-state service.
## Tracks which guardian forms are locked and emits timeline reset requests.

signal guardian_locked(form_id: StringName)
signal guardian_pool_changed(active_count: int)
signal game_over_requested(reason: StringName)
signal timeline_reset_requested(reason: StringName)

const GUARDIAN_FORMS: Array[StringName] = [
	&"Sword",
	&"Spear",
	&"Bow"
]

var persistent_flags: Dictionary = {}
var _guardian_lock_map: Dictionary = {}
var _last_reset_reason: StringName = &""
var _game_state_machine: Node

func _ready() -> void:
	_game_state_machine = get_node_or_null("/root/GameStateMachine")
	reset_run_state()

func reset_run_state() -> void:
	# Restores all guardian forms for a fresh run.
	_guardian_lock_map.clear()
	for form_id in GUARDIAN_FORMS:
		_guardian_lock_map[form_id] = false
	_last_reset_reason = &""
	guardian_pool_changed.emit(get_active_guardian_count())

func lock_guardian(form_id: StringName) -> void:
	# Locks a form once and broadcasts pool changes.
	if not _guardian_lock_map.has(form_id):
		return
	if _guardian_lock_map[form_id]:
		return

	_guardian_lock_map[form_id] = true
	guardian_locked.emit(form_id)
	guardian_pool_changed.emit(get_active_guardian_count())

	if get_active_guardian_count() <= 0:
		request_game_over(&"no_guardians_remaining")

func request_game_over(reason: StringName) -> void:
	_last_reset_reason = reason
	if _game_state_machine and _game_state_machine.has_method("enter_game_over"):
		_game_state_machine.enter_game_over(reason)
	game_over_requested.emit(reason)

func unlock_guardian(form_id: StringName) -> void:
	if not _guardian_lock_map.has(form_id):
		return
	_guardian_lock_map[form_id] = false
	guardian_pool_changed.emit(get_active_guardian_count())

func is_guardian_locked(form_id: StringName) -> bool:
	return _guardian_lock_map.get(form_id, true)

func get_active_guardian_count() -> int:
	var count := 0
	for form_id in GUARDIAN_FORMS:
		if not is_guardian_locked(form_id):
			count += 1
	return count

func get_locked_forms() -> Array[StringName]:
	var locked_forms: Array[StringName] = []
	for form_id in GUARDIAN_FORMS:
		if is_guardian_locked(form_id):
			locked_forms.append(form_id)
	return locked_forms

func request_timeline_reset(reason: StringName) -> void:
	# Stores reason so UI/debug tooling can report why the reset happened.
	_last_reset_reason = reason
	if _game_state_machine and _game_state_machine.has_method("set_playing"):
		_game_state_machine.set_playing(&"timeline_reset")
	timeline_reset_requested.emit(reason)

func get_last_reset_reason() -> StringName:
	return _last_reset_reason

func set_persistent_flag(key: StringName, value: Variant) -> void:
	persistent_flags[key] = value

func get_persistent_flag(key: StringName, default_value: Variant = null) -> Variant:
	return persistent_flags.get(key, default_value)
