extends Node

signal guardian_locked(form_id: StringName)
signal guardian_pool_changed(active_count: int)
signal timeline_reset_requested(reason: StringName)

const GUARDIAN_FORMS: Array[StringName] = [
	&"Sword",
	&"Spear",
	&"Bow"
]

var persistent_flags: Dictionary = {}
var _guardian_lock_map: Dictionary = {}

func _ready() -> void:
	reset_run_state()

func reset_run_state() -> void:
	_guardian_lock_map.clear()
	for form_id in GUARDIAN_FORMS:
		_guardian_lock_map[form_id] = false
	guardian_pool_changed.emit(get_active_guardian_count())

func lock_guardian(form_id: StringName) -> void:
	if not _guardian_lock_map.has(form_id):
		return
	if _guardian_lock_map[form_id]:
		return

	_guardian_lock_map[form_id] = true
	guardian_locked.emit(form_id)
	guardian_pool_changed.emit(get_active_guardian_count())

	if get_active_guardian_count() <= 0:
		request_timeline_reset(&"no_guardians_remaining")

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

func request_timeline_reset(reason: StringName) -> void:
	timeline_reset_requested.emit(reason)

func set_persistent_flag(key: StringName, value: Variant) -> void:
	persistent_flags[key] = value

func get_persistent_flag(key: StringName, default_value: Variant = null) -> Variant:
	return persistent_flags.get(key, default_value)
