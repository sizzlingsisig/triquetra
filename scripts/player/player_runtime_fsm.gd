extends Node
class_name PlayerRuntimeFsm

enum PlayerState {
	DEAD,
	IDLE,
	RUNNING,
	ATTACKING,
	SPECIAL,
	SWITCHING,
	JUMPING,
	STUNNED,
}

signal state_changed(previous_state: int, next_state: int, reason: StringName)

const COMMAND_SWAP_NEXT: StringName = &"swap_next"
const COMMAND_SWAP_PREV: StringName = &"swap_prev"
const COMMAND_PRIMARY_ATTACK: StringName = &"primary_attack"
const COMMAND_SPECIAL: StringName = &"special"
const COMMAND_JUMP: StringName = &"jump"

var _state: PlayerState = PlayerState.IDLE

var _player: PlayerController
var _movement_component: PlayerMovementComponent
var _animation_manager: PlayerAnimationManager
var _form_manager: PlayerFormManager
var _game_manager: Node

func setup(player: PlayerController, movement_component: PlayerMovementComponent, animation_manager: PlayerAnimationManager, form_manager: PlayerFormManager, game_manager: Node) -> void:
	_player = player
	_movement_component = movement_component
	_animation_manager = animation_manager
	_form_manager = form_manager
	_game_manager = game_manager
	_update_state_from_runtime(&"setup")

func reset() -> void:
	_state = PlayerState.IDLE

func get_state() -> PlayerState:
	return _state

func get_state_name() -> StringName:
	return _state_to_name(_state)

func transition_to(next_state: PlayerState, reason: StringName = &"") -> bool:
	if not can_transition(next_state):
		return false
	if _state == next_state:
		return false

	var previous_state: PlayerState = _state
	_state = next_state
	state_changed.emit(previous_state, _state, reason)
	return true

func can_transition(next_state: PlayerState) -> bool:
	if _state == PlayerState.DEAD and next_state != PlayerState.DEAD:
		return false
	return true

func can_accept_command(command_id: StringName) -> bool:
	if _player == null:
		return false
	if _player._is_game_over_state() or not _player._can_process_combat():
		return false

	match _state:
		PlayerState.DEAD, PlayerState.STUNNED, PlayerState.SWITCHING:
			return false
		_:
			return true

func on_command_executed(command_id: StringName) -> void:
	match command_id:
		COMMAND_PRIMARY_ATTACK:
			transition_to(PlayerState.ATTACKING, &"command_attack")
		COMMAND_SPECIAL:
			transition_to(PlayerState.SPECIAL, &"command_special")
		COMMAND_JUMP:
			transition_to(PlayerState.JUMPING, &"command_jump")

func on_switch_started() -> void:
	transition_to(PlayerState.SWITCHING, &"switch_start")

func on_switch_finished() -> void:
	_update_state_from_runtime(&"switch_finish")

func physics_update(_delta: float) -> void:
	_update_state_from_runtime(&"physics")

func update(_delta: float) -> void:
	_update_state_from_runtime(&"process")

func _update_state_from_runtime(reason: StringName) -> void:
	if _player == null:
		return

	if _player._is_game_over_state() or not _player._can_process_combat():
		transition_to(PlayerState.STUNNED, &"combat_locked")
		return

	if _is_all_guardians_locked():
		transition_to(PlayerState.DEAD, &"all_guardians_locked")
		return

	if _state == PlayerState.DEAD:
		return

	if _movement_component and _movement_component.is_jumping():
		transition_to(PlayerState.JUMPING, reason)
		return

	if _animation_manager and _animation_manager.is_busy_with_action_animation():
		var action_name: StringName = _animation_manager.get_current_action_animation()
		if _is_special_animation(action_name):
			transition_to(PlayerState.SPECIAL, reason)
		else:
			transition_to(PlayerState.ATTACKING, reason)
		return

	if abs(_player.velocity.x) > 4.0:
		transition_to(PlayerState.RUNNING, reason)
		return

	transition_to(PlayerState.IDLE, reason)

func _is_special_animation(animation_name: StringName) -> bool:
	var clip: String = String(animation_name)
	return clip.ends_with("_block") or clip.ends_with("_impale") or clip.ends_with("_disengage")

func _is_all_guardians_locked() -> bool:
	if _game_manager == null:
		return false
	if _game_manager.has_method("get_active_guardian_count"):
		return _game_manager.get_active_guardian_count() <= 0
	return false

func _state_to_name(state: PlayerState) -> StringName:
	match state:
		PlayerState.DEAD:
			return &"dead"
		PlayerState.IDLE:
			return &"idle"
		PlayerState.RUNNING:
			return &"running"
		PlayerState.ATTACKING:
			return &"attacking"
		PlayerState.SPECIAL:
			return &"special"
		PlayerState.SWITCHING:
			return &"switching"
		PlayerState.JUMPING:
			return &"jumping"
		PlayerState.STUNNED:
			return &"stunned"
		_:
			return &"idle"
