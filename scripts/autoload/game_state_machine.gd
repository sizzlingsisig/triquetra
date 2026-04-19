extends Node

## Global game-state controller for high-level flow gating.

signal state_changed(previous_state: int, current_state: int)
signal state_change_denied(from_state: int, to_state: int, reason: StringName)

enum GameState {
	PAUSED,
	PLAYING,
	VICTORY,
	DIALOGUE,
	GAME_OVER
}

var _current_state: int = GameState.PLAYING

func _ready() -> void:
	_current_state = GameState.PLAYING

func get_state() -> int:
	return _current_state

func get_state_name() -> StringName:
	match _current_state:
		GameState.PAUSED:
			return &"PAUSED"
		GameState.PLAYING:
			return &"PLAYING"
		GameState.VICTORY:
			return &"VICTORY"
		GameState.DIALOGUE:
			return &"DIALOGUE"
		GameState.GAME_OVER:
			return &"GAME_OVER"
		_:
			return &"UNKNOWN"

func is_state(state_id: int) -> bool:
	return _current_state == state_id

func is_playing() -> bool:
	return _current_state == GameState.PLAYING

func is_paused() -> bool:
	return _current_state == GameState.PAUSED

func is_dialogue() -> bool:
	return _current_state == GameState.DIALOGUE

func is_victory() -> bool:
	return _current_state == GameState.VICTORY

func is_game_over() -> bool:
	return _current_state == GameState.GAME_OVER

func can_process_movement() -> bool:
	return _current_state == GameState.PLAYING or _current_state == GameState.DIALOGUE

func can_process_combat() -> bool:
	return _current_state == GameState.PLAYING

func request_state(next_state: int, reason: StringName = &"") -> bool:
	if next_state == _current_state:
		return true
	if not _is_transition_allowed(_current_state, next_state):
		state_change_denied.emit(_current_state, next_state, reason)
		return false

	var previous_state: int = _current_state
	_current_state = next_state
	state_changed.emit(previous_state, _current_state)
	return true

func set_playing(reason: StringName = &"") -> bool:
	return request_state(GameState.PLAYING, reason)

func toggle_pause() -> bool:
	if _current_state == GameState.PLAYING:
		return request_state(GameState.PAUSED, &"toggle_pause")
	if _current_state == GameState.PAUSED:
		return request_state(GameState.PLAYING, &"toggle_pause")
	return false

func enter_dialogue(reason: StringName = &"") -> bool:
	return request_state(GameState.DIALOGUE, reason)

func exit_dialogue(reason: StringName = &"") -> bool:
	return request_state(GameState.PLAYING, reason)

func enter_victory(reason: StringName = &"") -> bool:
	return request_state(GameState.VICTORY, reason)

func enter_game_over(reason: StringName = &"") -> bool:
	return request_state(GameState.GAME_OVER, reason)

func _is_transition_allowed(from_state: int, to_state: int) -> bool:
	match from_state:
		GameState.PLAYING:
			return to_state in [GameState.PAUSED, GameState.DIALOGUE, GameState.VICTORY, GameState.GAME_OVER]
		GameState.PAUSED:
			return to_state == GameState.PLAYING
		GameState.DIALOGUE:
			return to_state in [GameState.PLAYING, GameState.GAME_OVER]
		GameState.VICTORY:
			return to_state == GameState.PLAYING
		GameState.GAME_OVER:
			return to_state == GameState.PLAYING
		_:
			return false
