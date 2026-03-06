extends CharacterBody2D
class_name PlayerController

## PlayerController is the orchestration layer for the guardian player character.
##
## Responsibilities:
## - Gather and buffer input commands.
## - Apply movement and jump arc offsets.
## - Delegate combat actions to the active guardian state.
## - Coordinate form swapping/locking with GameManager.
## - Bridge state scripts with animation/debug components.

signal form_changed(form_id: StringName)
signal form_locked(form_id: StringName)

@export var move_speed: float = 180.0
@export var coyote_time_window: float = 0.12
@export var input_buffer_window: float = 0.12
@export var jump_height: float = 20.0
@export var jump_duration: float = 0.35
@export var jump_cooldown: float = 0.12
@export var show_debug_widget: bool = true
@export var debug_log_events: bool = true

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

const COMMAND_SWAP_NEXT: StringName = &"swap_next"
const COMMAND_SWAP_PREV: StringName = &"swap_prev"
const COMMAND_PRIMARY_ATTACK: StringName = &"primary_attack"
const COMMAND_SPECIAL: StringName = &"special"
const COMMAND_JUMP: StringName = &"jump"

@onready var _states_root: Node = $States
@onready var _guardian_sprite: AnimatedSprite2D = $GuardianSprite
@onready var _attack_area: Area2D = get_node_or_null("AttackArea")
@onready var _body_collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var _animation_manager: Node = get_node_or_null("AnimationManager")
@onready var _debug_widget: Node = get_node_or_null("PlayerDebugWidget")

var _states: Dictionary = {}
var _active_form: StringName = &"Sword"
var _active_state: Node
var _game_manager: Node

# Buffered commands are consumed during physics ticks so states can gate execution.
var _command_buffer: Array[Dictionary] = []
var _swap_coyote_remaining: float = 0.0
var _is_jumping: bool = false
var _jump_elapsed: float = 0.0
var _jump_cooldown_remaining: float = 0.0
var _sprite_base_position: Vector2 = Vector2.ZERO
var _body_collision_base_position: Vector2 = Vector2.ZERO
var _attack_area_base_position: Vector2 = Vector2.ZERO
var _current_jump_offset: Vector2 = Vector2.ZERO
var _facing_left: bool = false
var _last_reset_reason: StringName = &""
var _lock_event_processed: Dictionary = {}
var _attack_window_hit_ids: Dictionary = {}

@onready var _camera: Camera2D = get_node_or_null("Camera2D")

func _animation_manager_has(method_name: StringName) -> bool:
	return _animation_manager != null and _animation_manager.has_method(method_name)

# Uses callv to keep this script resilient to component class parse/cache issues.
func _animation_manager_call(method_name: StringName, args: Array = []) -> Variant:
	if not _animation_manager_has(method_name):
		return null
	return _animation_manager.callv(method_name, args)

func shake_camera(intensity: float = 8.0, duration: float = 0.15) -> void:
	if _camera:
		var tween := create_tween()
		var original_offset := _camera.offset
		tween.tween_property(_camera, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), duration)
		tween.tween_property(_camera, "offset", original_offset, duration)

func _ready() -> void:
	# Cache dependencies and initial local offsets before runtime updates begin.
	_game_manager = get_node_or_null("/root/GameManager")
	_reset_lock_event_tracking()
	_connect_game_manager_signals()

	if _guardian_sprite:
		_sprite_base_position = _guardian_sprite.position
		_guardian_sprite.flip_h = _facing_left
	if _body_collision_shape:
		_body_collision_base_position = _body_collision_shape.position
	if _attack_area:
		_attack_area_base_position = _attack_area.position

	if _animation_manager:
		# Optional component API calls are guarded to avoid hard coupling.
		_animation_manager_call(&"setup", [self, _guardian_sprite])
		_animation_manager_call(&"set_form", [_active_form])
		_animation_manager_call(&"set_facing_left", [_facing_left])
		if _animation_manager.has_signal("attack_window_toggled") and not _animation_manager.attack_window_toggled.is_connected(_set_attack_area_active):
			_animation_manager.attack_window_toggled.connect(_set_attack_area_active)

	_cache_states()
	_connect_state_signals()
	_initialize_state_contexts()
	_sync_state_locks_from_manager()
	_set_attack_area_active(false)
	_activate_first_available_state()
	_setup_debug_widget()

func _physics_process(delta: float) -> void:
	# Main gameplay loop: movement -> buffered commands -> state update -> jump/anim -> move.
	_apply_movement()
	_consume_command_buffer(delta)

	if _active_state:
		_active_state.physics_update(delta)

	_update_jump(delta)
	if _animation_manager:
		_animation_manager_call(&"update_locomotion", [velocity, delta])

	move_and_slide()

	if _swap_coyote_remaining > 0.0:
		_swap_coyote_remaining -= delta

	if _jump_cooldown_remaining > 0.0:
		_jump_cooldown_remaining -= delta

	_apply_attack_overlap_hits()

func _process(delta: float) -> void:
	if _active_state:
		_active_state.update(delta)

func _unhandled_input(event: InputEvent) -> void:
	# Convert raw input into action commands for deterministic buffering/consumption.
	if _is_action_just_pressed(event, action_swap_next):
		_buffer_command(COMMAND_SWAP_NEXT)
		return
	if _is_action_just_pressed(event, action_swap_prev):
		_buffer_command(COMMAND_SWAP_PREV)
		return
	if _is_action_just_pressed(event, action_attack):
		_buffer_command(COMMAND_PRIMARY_ATTACK)
		return
	if _is_action_just_pressed(event, action_special):
		_buffer_command(COMMAND_SPECIAL)
		return
	if _is_action_just_pressed(event, action_jump):
		_buffer_command(COMMAND_JUMP)
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

func _connect_game_manager_signals() -> void:
	if not _game_manager:
		return
	if _game_manager.has_signal("guardian_locked") and not _game_manager.guardian_locked.is_connected(_on_manager_guardian_locked):
		_game_manager.guardian_locked.connect(_on_manager_guardian_locked)
	if _game_manager.has_signal("timeline_reset_requested") and not _game_manager.timeline_reset_requested.is_connected(_on_timeline_reset_requested):
		_game_manager.timeline_reset_requested.connect(_on_timeline_reset_requested)

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
	# States own form-specific behavior. Controller only manages transitions.
	if not _states.has(next_form):
		return
	if _is_form_locked(next_form):
		_log_debug("Skipped activating locked form: %s" % String(next_form))
		return

	var previous_form := _active_form
	if _active_state:
		_active_state.exit(next_form)

	_active_form = next_form
	_active_state = _states[next_form] as Node
	_active_state.enter(previous_form)
	form_changed.emit(_active_form)
	_log_debug("Active form changed: %s -> %s" % [String(previous_form), String(_active_form)])

	if _animation_manager:
		_animation_manager_call(&"set_form", [_active_form])

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

func _request_action(action_name: StringName) -> bool:
	# Active state decides if/when an action is accepted.
	if not _active_state:
		return false
	if not _active_state.can_accept_action(action_name):
		return false
	return _active_state.handle_action(action_name)

func _consume_command_buffer(delta: float) -> void:
	# 1) Expire stale commands, 2) execute first command that can run this frame.
	for i in range(_command_buffer.size() - 1, -1, -1):
		var cmd := _command_buffer[i]
		cmd.time_left = float(cmd.time_left) - delta
		if cmd.time_left <= 0.0:
			_command_buffer.remove_at(i)
		else:
			_command_buffer[i] = cmd

	if _command_buffer.is_empty():
		return

	for i in range(_command_buffer.size()):
		var command_id: StringName = _command_buffer[i].id
		if _try_execute_command(command_id):
			_command_buffer.remove_at(i)
			return

func _try_execute_command(command_id: StringName) -> bool:
	match command_id:
		COMMAND_SWAP_NEXT:
			_request_swap(+1)
			return true
		COMMAND_SWAP_PREV:
			_request_swap(-1)
			return true
		COMMAND_JUMP:
			return _try_start_jump()
		COMMAND_PRIMARY_ATTACK:
			return _request_action(&"primary_attack")
		COMMAND_SPECIAL:
			return _request_action(&"special")
		_:
			return true

func _buffer_command(command_id: StringName) -> void:
	for i in range(_command_buffer.size()):
		if _command_buffer[i].id == command_id:
			_command_buffer[i].time_left = input_buffer_window
			return
	_command_buffer.append({
		"id": command_id,
		"time_left": input_buffer_window
	})

func _set_attack_area_active(is_active: bool) -> void:
	# Attack area follows facing direction and current jump arc offset.
	if not _attack_area:
		return
	_attack_area.monitoring = is_active
	_attack_area.monitorable = is_active
	if is_active:
		_attack_window_hit_ids.clear()
		var forward_sign := -1.0 if _facing_left else 1.0
		_attack_area.position = _attack_area_base_position + Vector2(24.0 * forward_sign, 0.0) + _current_jump_offset
	else:
		_attack_area.position = _attack_area_base_position + _current_jump_offset

func _apply_attack_overlap_hits() -> void:
	# Prevent multiple hits on the same enemy within one active attack window.
	if not _attack_area:
		return
	if not _attack_area.monitoring:
		return

	for overlap in _attack_area.get_overlapping_areas():
		if not overlap:
			continue
		if overlap.name != "AttackHitbox":
			continue

		var enemy_node: Node = overlap.get_parent()
		if not enemy_node:
			continue

		var enemy_id := enemy_node.get_instance_id()
		if _attack_window_hit_ids.get(enemy_id, false):
			continue
		_attack_window_hit_ids[enemy_id] = true

		if enemy_node.has_method("receive_player_hit"):
			enemy_node.receive_player_hit()

func _apply_movement() -> void:
	# Top-down style directional movement with normalized diagonals.
	var input_direction := Vector2.ZERO
	input_direction.x = Input.get_axis(action_move_left, action_move_right)
	input_direction.y = Input.get_axis(action_move_up, action_move_down)

	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()

	if abs(input_direction.x) > 0.01:
		_set_sprite_facing(input_direction.x < 0.0)

	var current_speed: float = move_speed
	if _is_jumping:
		current_speed *= 0.8

	velocity = input_direction * current_speed

func _set_sprite_facing(facing_left: bool) -> void:
	_facing_left = facing_left
	if _animation_manager:
		_animation_manager_call(&"set_facing_left", [_facing_left])
	elif _guardian_sprite:
		_guardian_sprite.flip_h = _facing_left

func _try_start_jump() -> bool:
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

func _update_jump(delta: float) -> void:
	# Visual jump arc is implemented as local position offset, not physics y-velocity.
	if not _guardian_sprite:
		return

	if not _is_jumping:
		_current_jump_offset = Vector2.ZERO
		_apply_jump_offset_to_nodes()
		_guardian_sprite.scale = Vector2.ONE
		return

	_jump_elapsed += delta
	var t: float = clamp(_jump_elapsed / jump_duration, 0.0, 1.0)
	var arc: float = sin(t * PI)

	_current_jump_offset = Vector2(0.0, -arc * jump_height)
	_apply_jump_offset_to_nodes()
	var stretch: float = 1.0 + (0.08 * arc)
	_guardian_sprite.scale = Vector2(stretch, stretch)

	if t >= 1.0:
		_is_jumping = false
		_current_jump_offset = Vector2.ZERO
		_apply_jump_offset_to_nodes()
		_guardian_sprite.scale = Vector2.ONE

func _apply_jump_offset_to_nodes() -> void:
	# Keep sprite, body collision, and attack area aligned during jump arc.
	if _guardian_sprite:
		_guardian_sprite.position = _sprite_base_position + _current_jump_offset
	if _body_collision_shape:
		_body_collision_shape.position = _body_collision_base_position + _current_jump_offset
	if _attack_area:
		var attack_forward := Vector2.ZERO
		if _attack_area.monitoring:
			attack_forward.x = -24.0 if _facing_left else 24.0
		_attack_area.position = _attack_area_base_position + attack_forward + _current_jump_offset

func _is_form_locked(form_id: StringName) -> bool:
	if _game_manager:
		return _game_manager.is_guardian_locked(form_id)
	if _states.has(form_id):
		return (_states[form_id] as Node).is_locked
	return true

func _on_guardian_locked(form_id: StringName) -> void:
	if _game_manager and _game_manager.has_method("lock_guardian"):
		_game_manager.lock_guardian(form_id)
	_handle_guardian_locked(form_id, &"state")

func _on_manager_guardian_locked(form_id: StringName) -> void:
	_handle_guardian_locked(form_id, &"manager")

func _handle_guardian_locked(form_id: StringName, source: StringName) -> void:
	# If current form gets locked, immediately rotate to the next available guardian.
	if _states.has(form_id):
		(_states[form_id] as Node).is_locked = true

	if _lock_event_processed.get(form_id, false):
		return

	_lock_event_processed[form_id] = true
	form_locked.emit(form_id)
	_log_debug("Guardian locked (%s): %s" % [String(source), String(form_id)])

	if form_id == _active_form:
		_request_swap(+1)

func _is_action_just_pressed(event: InputEvent, action_name: StringName) -> bool:
	if action_name.is_empty():
		return false
	if not InputMap.has_action(action_name):
		return false
	return event.is_action_pressed(action_name)

func play_guardian_animation(animation_name: StringName, reset_frame: bool = true) -> void:
	if _animation_manager_has(&"play"):
		var played_variant: Variant = _animation_manager_call(&"play", [animation_name, reset_frame])
		if played_variant is bool and played_variant:
			return
	if _guardian_sprite and _guardian_sprite.sprite_frames and _guardian_sprite.sprite_frames.has_animation(animation_name):
		_guardian_sprite.play(animation_name)
		if reset_frame:
			_guardian_sprite.frame = 0

func has_guardian_animation(animation_name: StringName) -> bool:
	if not _guardian_sprite:
		return false
	if not _guardian_sprite.sprite_frames:
		return false
	return _guardian_sprite.sprite_frames.has_animation(animation_name)

func _on_timeline_reset_requested(reason: StringName) -> void:
	_last_reset_reason = reason
	_log_debug("Timeline reset requested: %s" % String(reason))
	call_deferred("_reset_run_flow")

func _reset_run_flow() -> void:
	# Clear local runtime state, reset global run state, and reload current scene.
	if _game_manager and _game_manager.has_method("reset_run_state"):
		_game_manager.reset_run_state()

	_command_buffer.clear()
	_swap_coyote_remaining = 0.0
	_is_jumping = false
	_jump_elapsed = 0.0
	_jump_cooldown_remaining = 0.0
	_current_jump_offset = Vector2.ZERO
	_reset_lock_event_tracking()
	_reload_current_scene()

func _reload_current_scene() -> void:
	var tree := get_tree()
	if not tree:
		return
	if tree.current_scene and not tree.current_scene.scene_file_path.is_empty():
		tree.change_scene_to_file(tree.current_scene.scene_file_path)
		return
	tree.reload_current_scene()

func _reset_lock_event_tracking() -> void:
	_lock_event_processed.clear()
	for form_id in FORM_ORDER:
		_lock_event_processed[form_id] = false

func _setup_debug_widget() -> void:
	if not show_debug_widget:
		if _debug_widget:
			_debug_widget.set("visible", false)
		return

	if not _debug_widget:
		return
	if _debug_widget.has_method("set"):
		_debug_widget.set("visible", true)
	if _debug_widget.has_method("setup"):
		_debug_widget.call("setup", self, _game_manager)

func _sync_state_locks_from_manager() -> void:
	if not _game_manager:
		return
	for form_id in FORM_ORDER:
		if _states.has(form_id):
			(_states[form_id] as Node).is_locked = _game_manager.is_guardian_locked(form_id)

func _log_debug(message: String) -> void:
	if not debug_log_events:
		return
	print("[PlayerController] %s" % message)

func get_active_form_id() -> StringName:
	return _active_form

func get_buffered_command_for_debug() -> String:
	if _command_buffer.is_empty():
		return "<none>"
	return String(_command_buffer[0].id)

func get_last_reset_reason_for_debug() -> String:
	return String(_last_reset_reason)

func get_locked_forms_for_debug() -> PackedStringArray:
	var locked: PackedStringArray = []
	if _game_manager and _game_manager.has_method("get_locked_forms"):
		for form_id in _game_manager.get_locked_forms():
			locked.append(String(form_id))
		return locked

	for form_id in FORM_ORDER:
		if _states.has(form_id) and (_states[form_id] as Node).is_locked:
			locked.append(String(form_id))
	return locked

func get_facing_direction() -> Vector2:
	# Shared utility for states/components (for example bow projectile spawn direction).
	return Vector2.LEFT if _facing_left else Vector2.RIGHT

func get_arrow_spawn_position() -> Vector2:
	if not _guardian_sprite:
		return global_position
	var direction := get_facing_direction()
	return _guardian_sprite.global_position + Vector2(direction.x * 20.0, -8.0 + _current_jump_offset.y)
