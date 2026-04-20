extends Node
class_name PlayerMovementComponent

@export var move_speed: float = 180.0
@export var ground_acceleration: float = 1800.0
@export var ground_deceleration: float = 2200.0
@export var jump_height: float = 20.0
@export var jump_duration: float = 0.35
@export var jump_cooldown: float = 0.12
@export var max_fall_speed: float = 1200.0

var _gravity: float = 980.0

var _player: PlayerController
var _is_jumping: bool = false
var _jump_elapsed: float = 0.0
var _jump_cooldown_remaining: float = 0.0
var _current_jump_offset: Vector2 = Vector2.ZERO

func setup(player: PlayerController) -> void:
    _player = player
    _gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))

func apply_gravity(delta: float) -> void:
    if _player == null:
        return

    if _player.is_on_floor():
        if _player.velocity.y > 0.0:
            _player.velocity.y = 0.0
        return

    _player.velocity.y = minf(_player.velocity.y + (_gravity * delta), max_fall_speed)

func apply_movement(delta: float) -> void:
    var input_direction := Vector2.ZERO
    if _player.input_buffer:
        input_direction.x = Input.get_axis(_player.input_buffer.action_move_left, _player.input_buffer.action_move_right)

    if input_direction.length_squared() > 1.0:
        input_direction = input_direction.normalized()

    if abs(input_direction.x) > 0.01:
        _player._set_sprite_facing(input_direction.x < 0.0)

    var current_speed: float = move_speed
    if _is_jumping:
        current_speed *= 0.8

    var target_velocity_x: float = input_direction.x * current_speed
    var accel: float = ground_acceleration if absf(target_velocity_x) > 0.01 else ground_deceleration
    _player.velocity.x = move_toward(_player.velocity.x, target_velocity_x, accel * delta)

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

    if not _player._guardian_sprite:
        return

    if not _is_jumping:
        _current_jump_offset = Vector2.ZERO
        _player._apply_jump_offset_to_nodes()
        _player._guardian_sprite.scale = Vector2.ONE
        return

    _jump_elapsed += delta
    var t: float = clamp(_jump_elapsed / jump_duration, 0.0, 1.0)
    var arc: float = sin(t * PI)

    _current_jump_offset = Vector2(0.0, -arc * jump_height)
    _player._apply_jump_offset_to_nodes()

    var stretch: float = 1.0 + (0.08 * arc)
    _player._guardian_sprite.scale = Vector2(stretch, stretch)

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
    if _player._guardian_sprite:
        _player._guardian_sprite.scale = Vector2.ONE
        _player._apply_jump_offset_to_nodes()

func reset() -> void:
    stop_jump()
    _jump_cooldown_remaining = 0.0
