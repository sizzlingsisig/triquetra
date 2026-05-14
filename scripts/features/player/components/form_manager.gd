extends Node
class_name FormManager

## Emitted when the active player changes after a swap.
signal active_player_changed(player: PlayerController)

## Single source of truth for form swap ordering.
const GUARDIAN_FORMS: Array[StringName] = [
	&"Sword", &"Spear", &"Bow"
]

var _players: Dictionary = {}  # form_id -> PlayerController
var _active_player: PlayerController
var _swap_in_progress: bool = false
var _initialized: bool = false

func _ready() -> void:
	# Defer so instanced child scenes exist in the tree before we iterate
	call_deferred(&"_initialize")

func _initialize() -> void:
	for child in get_children():
		if child is PlayerController:
			_players[child.form_id] = child
			child.form_manager = self
			if not _active_player:
				_active_player = child
				_enable_player(child)
				child.enter_idle()
				active_player_changed.emit(child)
			else:
				_disable_player(child)
	_initialized = true

func swap_to_next(from: PlayerController) -> bool:
	return _swap(from, 1)

func swap_to_prev(from: PlayerController) -> bool:
	return _swap(from, -1)

func _swap(from: PlayerController, direction: int) -> bool:
	if _swap_in_progress or not _initialized:
		return false

	var current_idx: int = GUARDIAN_FORMS.find(from.form_id)
	if current_idx == -1:
		return false

	var _game_manager: Node = get_node("/root/GameManager")
	var active_count: int = _game_manager.get_active_guardian_count()
	if active_count < 2:
		return false

	# Search for next unlocked form, wrapping around
	for i in range(GUARDIAN_FORMS.size() - 1):
		var next_idx: int = (current_idx + direction) % GUARDIAN_FORMS.size()
		if next_idx < 0:
			next_idx += GUARDIAN_FORMS.size()
		var next_id: StringName = GUARDIAN_FORMS[next_idx]

		if not _game_manager.is_guardian_locked(next_id):
			if not _players.has(next_id):
				push_error("FormManager: _players missing key '%s'. Keys: %s" % [next_id, _players.keys()])
				return false
			_swap_in_progress = true
			_perform_swap(from, _players[next_id])
			return true
		current_idx = next_idx

	return false

func _perform_swap(from: PlayerController, to: PlayerController) -> void:
	# Transfer state
	to.global_position = from.global_position
	to.set_facing(from.is_facing_left())

	# Force SWITCHING on new player BEFORE enabling physics (fixes IDLE frame leak)
	to._fsm.force_state(PlayerRuntimeFsm.PlayerStates.SWITCHING, &"form_swap")

	# Toggle players
	_disable_player(from)
	_enable_player(to)
	_active_player = to

	_swap_in_progress = false
	active_player_changed.emit(to)

func _disable_player(player: PlayerController) -> void:
	player.process_mode = PROCESS_MODE_DISABLED
	player.hide()

func _enable_player(player: PlayerController) -> void:
	player.process_mode = PROCESS_MODE_INHERIT
	player.show()
