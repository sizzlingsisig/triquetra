extends CharacterBody2D
class_name PlayerController

signal form_changed(form_id: StringName)
signal form_locked(form_id: StringName)

@export var move_speed: float = 180.0
@export var coyote_time_window: float = 0.12
@export var input_buffer_window: float = 0.12
@export var post_action_idle_hold: float = 0.08
@export var jump_height: float = 20.0
@export var jump_duration: float = 0.35
@export var jump_cooldown: float = 0.12

@export var action_move_left: StringName = &"ui_left"
@export var action_move_right: StringName = &"ui_right"
@export var action_move_up: StringName = &"ui_up"
@export var action_move_down: StringName = &"ui_down"
@export var action_attack: StringName = &"attack"
@export var action_special: StringName = &"special"
@export var action_jump: StringName = &"jump"
@export var action_swap_next: StringName = &"swap_next"
@export var action_swap_prev: StringName = &"swap_prev"

const FORM_ORDER: Array[StringName] = [
	&"Sword",
	&"Spear",
	&"Bow"
]

@onready var _states_root: Node = $States
@onready var _guardian_sprite: AnimatedSprite2D = $GuardianSprite

var _states: Dictionary = {}
var _active_form: StringName = &"Sword"
var _active_state: Node
var _game_manager: Node

var _buffered_action: StringName = &""
var _buffer_remaining: float = 0.0
var _swap_coyote_remaining: float = 0.0
var _post_action_idle_remaining: float = 0.0
var _is_jumping: bool = false
var _jump_elapsed: float = 0.0
var _jump_cooldown_remaining: float = 0.0
var _sprite_base_position: Vector2 = Vector2.ZERO
var _facing_left: bool = false

# Camera2D shake integration
@onready var _camera: Camera2D = $Camera2D

func shake_camera(intensity: float = 8.0, duration: float = 0.15) -> void:
	if _camera:
		var tween := create_tween()
		var original_offset := _camera.offset
		tween.tween_property(_camera, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), duration)
		tween.tween_property(_camera, "offset", original_offset, duration)

func _ready() -> void:
	_game_manager = get_node_or_null("/root/GameManager")
	if _guardian_sprite:
		_sprite_base_position = _guardian_sprite.position
		_guardian_sprite.flip_h = _facing_left
		_guardian_sprite.animation_finished.connect(_on_guardian_animation_finished)
	_cache_states()
	_connect_state_signals()
	_initialize_state_contexts()
	_activate_first_available_state()

func _physics_process(delta: float) -> void:
	_apply_movement()
	if _active_state:
		_active_state.physics_update(delta)
	_update_jump(delta)
	if _post_action_idle_remaining > 0.0:
		_post_action_idle_remaining -= delta
	_update_locomotion_animation()
	move_and_slide()

	if _buffer_remaining > 0.0:
		_buffer_remaining -= delta
		if _buffer_remaining <= 0.0:
			_buffered_action = &""

	if _swap_coyote_remaining > 0.0:
		_swap_coyote_remaining -= delta

	if _jump_cooldown_remaining > 0.0:
		_jump_cooldown_remaining -= delta

func _process(delta: float) -> void:
	if _active_state:
		_active_state.update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _is_action_just_pressed(event, action_swap_next):
		_request_swap(+1)
		return
	if _is_action_just_pressed(event, action_swap_prev):
		_request_swap(-1)
		return
	if _is_action_just_pressed(event, action_attack):
		_request_action(&"primary_attack")
		return
	if _is_action_just_pressed(event, action_special):
		_request_action(&"special")
		return
	if _is_action_just_pressed(event, action_jump):
		_try_start_jump()
		return

func _cache_states() -> void:
	for child in _states_root.get_children():
		if child.has_method("setup") and child.has_method("receive_lethal_damage"):
			var state: Node = child
			_states[state.form_id] = state

func _connect_state_signals() -> void:
	for state in _states.values():
		var guardian_state: Node = state
		guardian_state.guardian_locked.connect(_on_guardian_locked)

func _initialize_state_contexts() -> void:
	for state in _states.values():
		(state as Node).setup(self, _game_manager)

func _activate_first_available_state() -> void:
	for form_id in FORM_ORDER:
		if not _is_form_locked(form_id):
			_set_active_form(form_id)
			return

	if _game_manager:
		_game_manager.request_timeline_reset(&"no_guardians_remaining")

func _set_active_form(next_form: StringName) -> void:
	if not _states.has(next_form):
		return
	if _is_form_locked(next_form):
		return

	var previous_form := _active_form
	if _active_state:
		_active_state.exit(next_form)

	_active_form = next_form
	_active_state = _states[next_form] as Node
	_active_state.enter(previous_form)
	form_changed.emit(_active_form)

	_try_consume_buffered_action()

func _request_swap(direction: int) -> void:
	if FORM_ORDER.is_empty():
		return

	_swap_coyote_remaining = coyote_time_window
	var start_index := FORM_ORDER.find(_active_form)
	if start_index < 0:
		start_index = 0

	for step in range(1, FORM_ORDER.size() + 1):
		var idx := (start_index + (direction * step) + FORM_ORDER.size()) % FORM_ORDER.size()
		var candidate := FORM_ORDER[idx]
		if not _is_form_locked(candidate):
			_set_active_form(candidate)
			return

	if _game_manager:
		_game_manager.request_timeline_reset(&"no_guardians_remaining")

func _request_action(action_name: StringName) -> void:
	if not _active_state:
		return

	if _active_state.can_accept_action(action_name):
		var handled: bool = _active_state.handle_action(action_name)
		if not handled:
			_buffer_action(action_name)
	else:
		_buffer_action(action_name)

func _buffer_action(action_name: StringName) -> void:
	_buffered_action = action_name
	_buffer_remaining = input_buffer_window

func _try_consume_buffered_action() -> void:
	if _buffered_action.is_empty():
		return
	if not _active_state:
		return
	if not _active_state.can_accept_action(_buffered_action):
		return

	var action := _buffered_action
	_buffered_action = &""
	_buffer_remaining = 0.0
	_active_state.handle_action(action)

func _apply_movement() -> void:
	var input_direction := Vector2.ZERO
	input_direction.x = Input.get_axis(action_move_left, action_move_right)
	input_direction.y = Input.get_axis(action_move_up, action_move_down)

	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()

	if abs(input_direction.x) > 0.01:
		_set_sprite_facing(input_direction.x < 0.0)

	var current_speed: float = move_speed
	if _is_jumping:
		# Slightly reduce steering during hop to keep jump readable.
		current_speed *= 0.8

	velocity = input_direction * current_speed

func _set_sprite_facing(facing_left: bool) -> void:
	_facing_left = facing_left
	if _guardian_sprite:
		_guardian_sprite.flip_h = _facing_left

func _try_start_jump() -> void:
	if _is_jumping:
		return
	if _jump_cooldown_remaining > 0.0:
		return
	if jump_duration <= 0.01:
		return

	_is_jumping = true
	_jump_elapsed = 0.0
	_jump_cooldown_remaining = jump_cooldown

func _update_jump(delta: float) -> void:
	if not _guardian_sprite:
		return

	if not _is_jumping:
		_guardian_sprite.position = _sprite_base_position
		_guardian_sprite.scale = Vector2.ONE
		return

	_jump_elapsed += delta
	var t: float = clamp(_jump_elapsed / jump_duration, 0.0, 1.0)
	var arc: float = sin(t * PI)

	_guardian_sprite.position = _sprite_base_position + Vector2(0.0, -arc * jump_height)
	var stretch: float = 1.0 + (0.08 * arc)
	_guardian_sprite.scale = Vector2(stretch, stretch)

	if t >= 1.0:
		_is_jumping = false
		_guardian_sprite.position = _sprite_base_position
		_guardian_sprite.scale = Vector2.ONE

func _is_form_locked(form_id: StringName) -> bool:
	if _game_manager:
		return _game_manager.is_guardian_locked(form_id)
	if _states.has(form_id):
		return (_states[form_id] as Node).is_locked
	return true

func _on_guardian_locked(form_id: StringName) -> void:
	form_locked.emit(form_id)
	if form_id != _active_form:
		return
	_request_swap(+1)

func _is_action_just_pressed(event: InputEvent, action_name: StringName) -> bool:
	if action_name.is_empty():
		return false
	if not InputMap.has_action(action_name):
		return false
	return event.is_action_pressed(action_name)

func play_guardian_animation(animation_name: StringName, reset_frame: bool = true) -> void:
	if not _guardian_sprite:
		return
	if not _guardian_sprite.sprite_frames:
		return
	if not _guardian_sprite.sprite_frames.has_animation(animation_name):
		return
	if not reset_frame and _guardian_sprite.animation == animation_name and _guardian_sprite.is_playing():
		return

	_guardian_sprite.play(animation_name)
	if reset_frame:
		_guardian_sprite.frame = 0

func _on_guardian_animation_finished() -> void:
	if not _guardian_sprite:
		return
	if not _guardian_sprite.sprite_frames:
		return
	if _is_action_animation_name(String(_guardian_sprite.animation)):
		_post_action_idle_remaining = post_action_idle_hold
		var idle_animation := StringName(String(_active_form).to_lower() + "_idle")
		if _guardian_sprite.sprite_frames.has_animation(idle_animation):
			_play_if_changed(idle_animation)

func _update_locomotion_animation() -> void:
	if not _guardian_sprite:
		return
	if not _guardian_sprite.sprite_frames:
		return
	if _is_action_animation_playing():
		return
	if _post_action_idle_remaining > 0.0:
		var hold_idle_animation := StringName(String(_active_form).to_lower() + "_idle")
		if _guardian_sprite.sprite_frames.has_animation(hold_idle_animation):
			_play_if_changed(hold_idle_animation)
		return

	var form_prefix := String(_active_form).to_lower()
	if velocity.length_squared() > 4.0:
		var run_animation := StringName(form_prefix + "_run")
		if _guardian_sprite.sprite_frames.has_animation(run_animation):
			_play_if_changed(run_animation)
			return

		# Some forms currently ship with walk-only locomotion clips.
		var walk_animation := StringName(form_prefix + "_walk")
		if _guardian_sprite.sprite_frames.has_animation(walk_animation):
			_play_if_changed(walk_animation)
			return

	var idle_animation := StringName(form_prefix + "_idle")
	if _guardian_sprite.sprite_frames.has_animation(idle_animation):
		_play_if_changed(idle_animation)

func _play_if_changed(animation_name: StringName) -> void:
	if not _guardian_sprite:
		return
	if _guardian_sprite.animation == animation_name and _guardian_sprite.is_playing():
		return
	_guardian_sprite.play(animation_name)

func _is_action_animation_playing() -> bool:
	if not _guardian_sprite:
		return false
	return _is_action_animation_name(String(_guardian_sprite.animation))

func _is_action_animation_name(current: String) -> bool:
	return (
		current.ends_with("_attack")
		or current.ends_with("_attack_2")
		or current.ends_with("_attack2")
		or current.ends_with("_attack3")
		or current.ends_with("_runattack")
		or current.ends_with("_block")
		or current.ends_with("_impale")
		or current.ends_with("_shot")
		or current.ends_with("_shot_2")
		or current.ends_with("_disengage")
	)
