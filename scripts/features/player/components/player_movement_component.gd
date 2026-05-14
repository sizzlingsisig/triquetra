extends Node
class_name PlayerMovementComponent

@export var move_speed: float = 180.0
@export var ground_acceleration: float = 1800.0
@export var ground_deceleration: float = 2200.0
@export var jump_height: float = 20.0
@export var jump_duration: float = 0.35
@export var jump_cooldown: float = 0.12
@export var max_fall_speed: float = 1200.0

var _player: PlayerController
var _is_jumping: bool = false
var _jump_elapsed: float = 0.0
var _jump_cooldown_remaining: float = 0.0
var _current_jump_offset: Vector2 = Vector2.ZERO
var _hit_control_lock_remaining: float = 0.0

func setup(player: PlayerController) -> void:
	_player = player

func apply_gravity(delta: float) -> void:
	if _player == null:
		return

	if _player.is_on_floor() and not _is_jumping:
		if _player.velocity.y > 0.0:
			_player.velocity.y = 0.0
		return

	_player.velocity.y = minf(_player.velocity.y + (_player.gravity * delta), max_fall_speed)

func apply_movement(delta: float, speed_modifier: float = 1.0) -> void:
	var effective_speed: float = move_speed * speed_modifier

	if _hit_control_lock_remaining > 0.0:
		_hit_control_lock_remaining = maxf(0.0, _hit_control_lock_remaining - delta)
		_player.velocity.x = move_toward(_player.velocity.x, 0.0, effective_speed)
		return

	var input_direction := Vector2.ZERO
	if _player:
		var buf: Node = _player.get_input_buffer()
		if buf:
			input_direction.x = Input.get_axis(buf.action_move_left, buf.action_move_right)
		else:
			input_direction.x = Input.get_axis(&"move_left", &"move_right")
	else:
		input_direction.x = Input.get_axis(&"move_left", &"move_right")

	if abs(input_direction.x) > 0.01:
		_player.velocity.x = input_direction.x * effective_speed
		if _player:
			_player.set_sprite_facing(input_direction.x < 0.0)
	else:
		_player.velocity.x = move_toward(_player.velocity.x, 0.0, effective_speed)

func try_start_jump() -> bool:
	if _is_jumping:
		return false
	if _jump_cooldown_remaining > 0.0:
		return false
	if jump_duration <= 0.01:
		return false

	_is_jumping = true
	_jump_elapsed = 0.0
	_jump_cooldown_remaining = jump_cooldown
	return true

func update_jump(delta: float) -> void:
	if _jump_cooldown_remaining > 0.0:
		_jump_cooldown_remaining -= delta

	if not _player:
		return

	if not _is_jumping:
		_current_jump_offset = Vector2.ZERO
		return

	_jump_elapsed += delta
	var t: float = clamp(_jump_elapsed / jump_duration, 0.0, 1.0)
	var arc: float = sin(t * PI)

	_current_jump_offset = Vector2(0.0, -arc * jump_height)

	if t >= 1.0:
		stop_jump()

func get_jump_offset() -> Vector2:
	return _current_jump_offset

func is_jumping() -> bool:
	return _is_jumping

func stop_jump() -> void:
	_is_jumping = false
	_jump_elapsed = 0.0
	_current_jump_offset = Vector2.ZERO
	pass  # Stretch effect deferred to animation manager

func apply_hit_reaction(knockback_velocity_x: float, control_lock_time: float = 0.12) -> void:
	if _player == null:
		return
	_hit_control_lock_remaining = maxf(_hit_control_lock_remaining, maxf(control_lock_time, 0.0))
	_player.velocity.x = knockback_velocity_x

func reset() -> void:
	stop_jump()
	_jump_cooldown_remaining = 0.0
	_hit_control_lock_remaining = 0.0
