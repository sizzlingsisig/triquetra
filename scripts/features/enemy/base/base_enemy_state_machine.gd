extends Node
class_name BaseStateMachine

enum State {
	IDLE,
	CHASE,
	ATTACK,
	HURT,
	DEAD,
}

## Emitted on every state transition.
## [param previous_state] and [param next_state] are State enum values.
## [param reason] describes what triggered the change.
signal state_changed(previous_state: int, next_state: int, reason: StringName)

var _current_state: State = State.IDLE
var _transition_generation: int = 0


## Attempt a state transition. Returns false if blocked (e.g. DEAD can't leave).
func transition_to(next_state: State, reason: StringName = &"") -> bool:
	if _current_state == State.DEAD and next_state != State.DEAD:
		return false
	if _current_state == next_state:
		return false
	var previous: State = _current_state
	_current_state = next_state
	_transition_generation += 1
	state_changed.emit(previous, _current_state, reason)
	return true


## Force a state transition, bypassing the DEAD->non-DEAD guard.
func force_transition_to(next_state: State, reason: StringName = &"") -> void:
	if _current_state == next_state:
		return
	var previous: State = _current_state
	_current_state = next_state
	_transition_generation += 1
	state_changed.emit(previous, _current_state, reason)


func get_state() -> State:
	return _current_state


func get_state_index() -> int:
	return _current_state as int


## Schedule a return to IDLE after [param delay] seconds.
## Uses generation counter: if another schedule_idle_recovery is called before
## this one fires, the old timer is invalidated.
func schedule_idle_recovery(delay: float) -> void:
	_transition_generation += 1
	var gen: int = _transition_generation
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(maxf(delay, 0.0))
	timer.timeout.connect(func() -> void:
		if gen == _transition_generation:
			transition_to(State.IDLE, &"recovered")
	)


## Invalidate all pending recovery timers.
func invalidate_recovery() -> void:
	_transition_generation += 1
