extends Node
class_name EnemyRuntimeFsm

enum EnemyState {
	IDLE,
	PATROLLING,
	SPOTTING,
	CHASING,
	ATTACKING,
	HURT,
	DEFENDING,
	COUNTER_ATTACKING,
	DEAD,
}

signal state_changed(previous_state: int, next_state: int, reason: StringName)

enum BehaviorChoice {
	ATTACK,
	CHASE,
	PATROL,
	IDLE,
	RECOVER,
	DEAD,
}

var _enemy: Enemy
var _combat_component: EnemyCombatComponent
var _animation_component: EnemyAnimationComponent
var _fx_component: EnemyFxComponent
var _state: EnemyState = EnemyState.IDLE
var _recovery_generation: int = 0
var _attack_requested: bool = false
var _attack_cooldown_remaining: float = 0.0
var _patrol_origin_x: float = 0.0
var _patrol_direction: float = 1.0
var _patrol_wait_remaining: float = 0.0
var _post_attack_hold_remaining: float = 0.0
var _attack_sequence_generation: int = 0

const DIRECTION_DEAD_ZONE_X: float = 1.5

func setup(enemy: Enemy, combat_component: EnemyCombatComponent, animation_component: EnemyAnimationComponent = null, fx_component: EnemyFxComponent = null) -> void:
	_enemy = enemy
	_combat_component = combat_component
	_animation_component = animation_component
	_fx_component = fx_component
	if _enemy:
		_patrol_origin_x = _enemy.global_position.x
	_patrol_direction = 1.0
	_patrol_wait_remaining = 0.0
	_attack_cooldown_remaining = 0.0
	_post_attack_hold_remaining = 0.0
	_attack_sequence_generation = 0
	force_transition_to(EnemyState.IDLE, &"setup")

func reset() -> void:
	_recovery_generation += 1
	_patrol_direction = 1.0
	_patrol_wait_remaining = 0.0
	_attack_cooldown_remaining = 0.0
	_post_attack_hold_remaining = 0.0
	_attack_sequence_generation += 1
	if _enemy:
		_patrol_origin_x = _enemy.global_position.x
	force_transition_to(EnemyState.IDLE, &"reset")

func get_state() -> EnemyState:
	return _state

func get_state_name() -> StringName:
	return _state_to_name(_state)

func can_transition(next_state: EnemyState) -> bool:
	if _state == EnemyState.DEAD and next_state != EnemyState.DEAD:
		return false
	return true

func transition_to(next_state: EnemyState, reason: StringName = &"") -> bool:
	if not can_transition(next_state):
		return false
	if _state == next_state:
		return false
	var previous_state: EnemyState = _state
	_state = next_state
	_on_state_enter(_state)
	state_changed.emit(previous_state, _state, reason)
	return true

func force_transition_to(next_state: EnemyState, reason: StringName = &"") -> void:
	if _state == next_state:
		return
	var previous_state: EnemyState = _state
	_state = next_state
	_on_state_enter(_state)
	state_changed.emit(previous_state, _state, reason)

func can_start_attack() -> bool:
	return _state not in [
		EnemyState.DEAD,
		EnemyState.HURT,
		EnemyState.DEFENDING,
		EnemyState.COUNTER_ATTACKING,
		EnemyState.ATTACKING,
	]

func request_attack() -> void:
	_attack_requested = true

func on_attack_started(recover_time: float) -> void:
	if transition_to(EnemyState.ATTACKING, &"attack_started"):
		_schedule_idle_recovery(recover_time, &"attack_recover")

func on_damage_hurt(recover_time: float) -> void:
	if transition_to(EnemyState.HURT, &"damage_hurt"):
		_schedule_idle_recovery(recover_time, &"hurt_recover")

func on_damage_blocked(recover_time: float) -> void:
	if transition_to(EnemyState.DEFENDING, &"damage_blocked"):
		_schedule_idle_recovery(recover_time, &"defend_recover")

func on_counter_attack(recover_time: float = 0.1) -> void:
	if transition_to(EnemyState.COUNTER_ATTACKING, &"counter_attack"):
		_schedule_idle_recovery(recover_time, &"counter_recover")

func on_died() -> void:
	_recovery_generation += 1
	_attack_sequence_generation += 1
	force_transition_to(EnemyState.DEAD, &"died")

func physics_update(delta: float) -> void:
	if _enemy == null:
		return
	if _attack_cooldown_remaining > 0.0:
		_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	if _post_attack_hold_remaining > 0.0:
		_post_attack_hold_remaining = maxf(0.0, _post_attack_hold_remaining - delta)
	match _select_behavior():
		BehaviorChoice.DEAD:
			_execute_dead_action()
		BehaviorChoice.RECOVER:
			_execute_recover_action(delta)
		BehaviorChoice.ATTACK:
			_execute_attack_action()
		BehaviorChoice.CHASE:
			_execute_chase_action(delta)
		BehaviorChoice.PATROL:
			_execute_patrol_action(delta)
		BehaviorChoice.IDLE:
			_execute_idle_action(delta)

func _select_behavior() -> BehaviorChoice:
	if _state == EnemyState.DEAD:
		return BehaviorChoice.DEAD

	if _state in [EnemyState.HURT, EnemyState.DEFENDING, EnemyState.COUNTER_ATTACKING, EnemyState.ATTACKING]:
		return BehaviorChoice.RECOVER

	if _should_attack():
		return BehaviorChoice.ATTACK

	if _can_chase_player():
		return BehaviorChoice.CHASE

	if _post_attack_hold_remaining > 0.0 and _state == EnemyState.IDLE:
		return BehaviorChoice.IDLE

	if _can_patrol():
		return BehaviorChoice.PATROL

	return BehaviorChoice.IDLE

func _should_attack() -> bool:
	if _enemy == null or not _enemy.enable_knight_attacks:
		_attack_requested = false
		return false
	if not can_start_attack():
		return false
	if _attack_cooldown_remaining > 0.0:
		return false
	if not _attack_requested and _is_player_in_attack_range():
		_attack_requested = true
	if not _attack_requested:
		return false
	if not _is_player_in_attack_range():
		_attack_requested = false
		return false
	return true


func _can_chase_player() -> bool:
	if _enemy == null or not _enemy.enable_chase:
		return false
	if _enemy._has_line_of_sight_to_player():
		return true
	if _post_attack_hold_remaining > 0.0:
		var tracked_target: Node2D = _enemy._get_target_player()
		return is_instance_valid(tracked_target)
	return false

func _can_patrol() -> bool:
	if _enemy == null:
		return false
	if not _enemy.enable_patrol:
		return false
	return _enemy.patrol_distance > 0.0 and _enemy.patrol_speed > 0.0

func _is_player_in_attack_range() -> bool:
	if _enemy == null:
		return false
	var target: Node2D = _enemy._get_detected_player()
	if target == null:
		target = _enemy._get_target_player()
	if target == null:
		return false
	var self_x: float = _enemy._get_combat_origin_x(_enemy)
	var target_x: float = _enemy._get_combat_origin_x(target)
	var distance_x: float = absf(target_x - self_x)
	var effective_melee_range: float = maxf(_enemy.attack_range, _enemy.chase_stop_distance)
	return distance_x <= effective_melee_range

func _execute_dead_action() -> void:
	if _enemy:
		_enemy.velocity.x = 0.0

func _execute_recover_action(delta: float) -> void:
	if _enemy:
		_enemy.velocity.x = move_toward(_enemy.velocity.x, 0.0, _enemy.chase_acceleration * delta)

func _execute_attack_action() -> void:
	if _enemy == null:
		return
	if transition_to(EnemyState.ATTACKING, &"selector_attack"):
		_attack_cooldown_remaining = maxf(0.0, _enemy.attack_interval)
		_post_attack_hold_remaining = maxf(_post_attack_hold_remaining, _get_post_attack_patrol_hold_time())
		_attack_sequence_generation += 1
		var sequence: int = _attack_sequence_generation
		var telegraph_time: float = _get_attack_telegraph_time()
		if telegraph_time <= 0.0:
			_perform_attack_impact(sequence)
		else:
			var tree: SceneTree = get_tree()
			if tree == null:
				_perform_attack_impact(sequence)
			else:
				var timer: SceneTreeTimer = tree.create_timer(telegraph_time)
				timer.timeout.connect(func() -> void:
					_perform_attack_impact(sequence)
				)
		_schedule_idle_recovery(_enemy._get_attack_recover_time() + telegraph_time, &"attack_recover")

func _perform_attack_impact(sequence: int) -> void:
	if _enemy == null:
		return
	if sequence != _attack_sequence_generation:
		return
	if _state != EnemyState.ATTACKING:
		return
	if _enemy.is_arrow_skeleton:
		_enemy._spawn_arrow_projectile()
	else:
		_enemy._activate_attack_area_window()
		if _enemy.has_method("_apply_direct_target_melee_fallback"):
			_enemy._apply_direct_target_melee_fallback()

func _get_attack_telegraph_time() -> float:
	if _enemy == null:
		return 0.0
	return maxf(_enemy.attack_telegraph_time, 0.0)

func _get_post_attack_patrol_hold_time() -> float:
	if _enemy == null:
		return 0.55
	return maxf(_enemy.post_attack_patrol_hold_time, 0.0)

func _execute_chase_action(delta: float) -> void:
	if _state in [EnemyState.IDLE, EnemyState.PATROLLING]:
		transition_to(EnemyState.SPOTTING, &"player_spotted")
	if _state == EnemyState.SPOTTING:
		transition_to(EnemyState.CHASING, &"chase_start")
	_apply_chase_movement(delta)

func _execute_patrol_action(delta: float) -> void:
	if _enemy == null:
		return
	if _state != EnemyState.PATROLLING:
		# Restart patrol around current position to avoid snapping back to stale origin.
		_patrol_origin_x = _enemy.global_position.x
		transition_to(EnemyState.PATROLLING, &"patrol_start")

	if _patrol_wait_remaining > 0.0:
		_patrol_wait_remaining = maxf(0.0, _patrol_wait_remaining - delta)
		_enemy.velocity.x = move_toward(_enemy.velocity.x, 0.0, _enemy.patrol_acceleration * delta)
		return

	var target_x: float = _patrol_origin_x + (_patrol_direction * _enemy.patrol_distance)
	var distance_x: float = target_x - _enemy.global_position.x
	if absf(distance_x) <= _enemy.patrol_arrive_threshold:
		_patrol_direction *= -1.0
		_patrol_wait_remaining = maxf(0.0, _enemy.patrol_wait_time)
		_enemy.velocity.x = move_toward(_enemy.velocity.x, 0.0, _enemy.patrol_acceleration * delta)
		return

	var direction: float = _patrol_direction
	if absf(distance_x) > DIRECTION_DEAD_ZONE_X:
		direction = signf(distance_x)
	var target_speed: float = direction * _enemy.patrol_speed
	_enemy.velocity.x = move_toward(_enemy.velocity.x, target_speed, _enemy.patrol_acceleration * delta)
	_enemy._set_enemy_facing_from_direction(direction)

func _execute_idle_action(delta: float) -> void:
	if _state in [EnemyState.SPOTTING, EnemyState.CHASING, EnemyState.PATROLLING]:
		transition_to(EnemyState.IDLE, &"player_lost")
	if _enemy:
		_enemy.velocity.x = move_toward(_enemy.velocity.x, 0.0, _enemy.chase_acceleration * delta)

func _apply_chase_movement(delta: float) -> void:
	if _enemy == null:
		return
	if _state != EnemyState.CHASING or not _enemy.enable_chase:
		_enemy.velocity.x = move_toward(_enemy.velocity.x, 0.0, _enemy.chase_acceleration * delta)
		return

	var target: Node2D = _enemy._get_detected_player()
	if target == null:
		target = _enemy._get_target_player()
	if target == null:
		_enemy.velocity.x = move_toward(_enemy.velocity.x, 0.0, _enemy.chase_acceleration * delta)
		return

	var self_x: float = _enemy._get_combat_origin_x(_enemy)
	var target_x: float = _enemy._get_combat_origin_x(target)
	var distance_x: float = target_x - self_x
	var direction: float = 0.0
	if absf(distance_x) > DIRECTION_DEAD_ZONE_X:
		direction = signf(distance_x)
	var effective_melee_range: float = maxf(_enemy.attack_range, _enemy.chase_stop_distance)
	if absf(distance_x) <= effective_melee_range:
		_enemy.velocity.x = move_toward(_enemy.velocity.x, 0.0, _enemy.chase_acceleration * delta)
		if _enemy.enable_knight_attacks and can_start_attack() and _attack_cooldown_remaining <= 0.0:
			_attack_requested = true
			_execute_attack_action()
		return

	var target_speed: float = direction * _enemy.chase_speed
	_enemy.velocity.x = move_toward(_enemy.velocity.x, target_speed, _enemy.chase_acceleration * delta)
	_enemy._set_enemy_facing_from_direction(direction)

func _schedule_idle_recovery(delay: float, reason: StringName) -> void:
	_recovery_generation += 1
	var generation: int = _recovery_generation
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(max(delay, 0.0))
	timer.timeout.connect(func() -> void:
		if generation != _recovery_generation:
			return
		transition_to(EnemyState.IDLE, reason)
	)

func _state_to_name(state: EnemyState) -> StringName:
	match state:
		EnemyState.IDLE:
			return &"idle"
		EnemyState.PATROLLING:
			return &"patrolling"
		EnemyState.SPOTTING:
			return &"spotting"
		EnemyState.CHASING:
			return &"chasing"
		EnemyState.ATTACKING:
			return &"attacking"
		EnemyState.HURT:
			return &"hurt"
		EnemyState.DEFENDING:
			return &"defending"
		EnemyState.COUNTER_ATTACKING:
			return &"counter_attacking"
		EnemyState.DEAD:
			return &"dead"
	return &"unknown"

func _on_state_enter(state: EnemyState) -> void:
	if _enemy == null:
		return

	match state:
		EnemyState.IDLE:
			_play_idle_animation()

		EnemyState.ATTACKING:
			_play_next_attack_animation()
			if _fx_component:
				_fx_component.spawn_attack_fx()

		EnemyState.HURT:
			_play_hurt_animation()

		EnemyState.DEFENDING:
			_play_defend_animation()

		EnemyState.COUNTER_ATTACKING:
			if _fx_component:
				_fx_component.spawn_hit_impact_fx(_enemy.global_position)

		EnemyState.DEAD:
			_play_dead_animation()
			if _combat_component:
				_combat_component.set_attack_enabled(false)

		EnemyState.SPOTTING:
			pass  # SPOTTING is currently a pass-through state

		EnemyState.CHASING:
			_play_run_animation()

		EnemyState.PATROLLING:
			_play_run_animation()

func _play_idle_animation() -> void:
	if _animation_component:
		_animation_component.play_if_exists(_get_idle_animation())

func _play_hurt_animation() -> void:
	if _animation_component:
		_animation_component.play_if_exists(_get_hurt_animation())

func _play_run_animation() -> void:
	if _animation_component:
		_animation_component.play_if_exists(_get_run_animation())

func _play_defend_animation() -> void:
	if _animation_component:
		_animation_component.play_if_exists(_get_defend_animation())

func _play_next_attack_animation() -> void:
	if _enemy == null:
		return
	# Delegate to enemy to handle animation cycling logic
	if _enemy.has_method("_play_next_attack_animation"):
		_enemy._play_next_attack_animation()

func _play_dead_animation() -> void:
	if _animation_component:
		_animation_component.play_if_exists(_get_dead_animation())

func _get_idle_animation() -> StringName:
	if _enemy == null:
		return &"knight_idle"
	if _enemy.enemy_data:
		return _enemy.enemy_data.idle_animation
	return &"knight_idle"

func _get_hurt_animation() -> StringName:
	if _enemy == null:
		return &"knight_hurt"
	if _enemy.enemy_data:
		return _enemy.enemy_data.hurt_animation
	return &"knight_hurt"

func _get_run_animation() -> StringName:
	if _enemy == null:
		return &"knight_run"
	if _enemy.enemy_data:
		return _enemy.enemy_data.run_animation
	return &"knight_run"

func _get_defend_animation() -> StringName:
	if _enemy == null:
		return &"knight_defend"
	if _enemy.enemy_data:
		return _enemy.enemy_data.defend_animation
	return &"knight_defend"

func _get_dead_animation() -> StringName:
	if _enemy == null:
		return &"knight_dead"
	if _enemy.enemy_data:
		return _enemy.enemy_data.dead_animation
	return &"knight_dead"
