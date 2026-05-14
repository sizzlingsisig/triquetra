extends Node
class_name PlayerRuntimeFsm

## All possible player runtime states.
## NOTE: enum name differs from the PlayerStateNode class (player_state.gd)
## to avoid shadowing the class with the local enum.
enum PlayerStates {
	IDLE = 0,
	RUNNING = 1,
	ATTACKING = 2,
	SPECIAL = 3,
	SWITCHING = 4,
	JUMPING = 5,
	DEAD = 6,
	STUNNED = 7,
	BOW_ATTACK = 8,
	EVASION = 9,
}

const COMMAND_PRIMARY_ATTACK: StringName = &"primary_attack"
const COMMAND_SPECIAL: StringName = &"special"
const COMMAND_JUMP: StringName = &"jump"
const COMMAND_SWAP_NEXT: StringName = &"swap_next"
const COMMAND_SWAP_PREV: StringName = &"swap_prev"

## Emitted when the player runtime state transitions.
## [param from] is the previous state, [param to] is the new state,
## [param reason] describes what caused the transition.
signal state_changed(from: int, to: int, reason: StringName)

const COMMAND_COOLDOWNS: Dictionary = {
	COMMAND_PRIMARY_ATTACK: 0.15,
	COMMAND_SPECIAL: 2.0,
}

var _state: int = PlayerStates.IDLE
var _states: Dictionary = {}
var _controller: PlayerController
var _command_cooldowns: Dictionary = {}

func setup(controller: PlayerController) -> void:
	_controller = controller
	for child in get_children():
		if child is PlayerStateNode:
			_states[child.state_id] = child
			child.setup(self, controller)

func get_state() -> int:
	return _state

func physics_update(delta: float) -> void:
	var state: PlayerStateNode = _states.get(_state)
	if state:
		state.physics_update(delta)
	else:
		push_error("PlayerRuntimeFsm: state %d not found in _states" % _state)

func execute_command(cmd: StringName) -> bool:
	if _state == PlayerStates.DEAD or _state == PlayerStates.STUNNED:
		return false
	# Only apply cooldown when transitioning FROM a neutral state (IDLE/RUNNING/JUMPING)
	# so combo presses during attack states are not blocked.
	if _is_neutral_state() and _is_command_on_cooldown(cmd):
		return false
	var state: PlayerStateNode = _states.get(_state)
	if state and state.can_accept_command(cmd):
		var handled: bool = state.handle_action(cmd)
		if handled:
			_mark_command_used(cmd)
			_update_state(cmd)
		return handled
	return false

func _is_neutral_state() -> bool:
	return _state == PlayerStates.IDLE or _state == PlayerStates.RUNNING or _state == PlayerStates.JUMPING

func _is_command_on_cooldown(cmd: StringName) -> bool:
	var cd: float = COMMAND_COOLDOWNS.get(cmd, 0.0)
	if cd <= 0.0:
		return false
	var last_use: float = _command_cooldowns.get(cmd, -INF)
	return Time.get_ticks_msec() / 1000.0 - last_use < cd

func _mark_command_used(cmd: StringName) -> void:
	var cd: float = COMMAND_COOLDOWNS.get(cmd, 0.0)
	if cd > 0.0:
		_command_cooldowns[cmd] = Time.get_ticks_msec() / 1000.0

func force_state(next_state: int, reason: StringName) -> void:
	if _state == next_state:
		return
	var prev: int = _state
	var prev_state: PlayerStateNode = _states.get(prev)
	if prev_state:
		prev_state.exit(next_state)
	else:
		push_error("PlayerRuntimeFsm: previous state %d not found in _states" % prev)
	_state = next_state
	var next_state_obj: PlayerStateNode = _states.get(_state)
	if next_state_obj:
		next_state_obj.enter(prev)
	else:
		push_error("PlayerRuntimeFsm: next state %d not found in _states" % _state)
	state_changed.emit(prev, _state, reason)

func _update_state(reason: StringName) -> void:
	var prev: int = _state
	var next: int = _resolve_next_state()
	if next != prev:
		var prev_state: PlayerStateNode = _states.get(prev) as PlayerStateNode
		if prev_state:
			prev_state.exit(next)
		_state = next
		var next_state: PlayerStateNode = _states.get(_state) as PlayerStateNode
		if next_state:
			next_state.enter(prev)
		state_changed.emit(prev, _state, reason)

func _resolve_next_state() -> int:
	match _state:
		PlayerStates.ATTACKING, PlayerStates.SPECIAL, PlayerStates.JUMPING, PlayerStates.STUNNED, PlayerStates.DEAD, PlayerStates.SWITCHING, PlayerStates.BOW_ATTACK, PlayerStates.EVASION:
			return _state
	if not _controller.is_on_floor():
		return PlayerStates.JUMPING
	if absf(_controller.velocity.x) > 4.0:
		return PlayerStates.RUNNING
	return PlayerStates.IDLE

func get_state_name() -> StringName:
	match _state:
		PlayerStates.IDLE:
			return &"IDLE"
		PlayerStates.RUNNING:
			return &"RUNNING"
		PlayerStates.ATTACKING:
			return &"ATTACKING"
		PlayerStates.SPECIAL:
			return &"SPECIAL"
		PlayerStates.SWITCHING:
			return &"SWITCHING"
		PlayerStates.JUMPING:
			return &"JUMPING"
		PlayerStates.DEAD:
			return &"DEAD"
		PlayerStates.STUNNED:
			return &"STUNNED"
		PlayerStates.BOW_ATTACK:
			return &"BOW_ATTACK"
		PlayerStates.EVASION:
			return &"EVASION"
		_:
			return &"UNKNOWN"
