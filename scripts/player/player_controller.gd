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
@export var show_debug_widget: bool = true
@export var debug_log_events: bool = true
@export var debug_refresh_rate: float = 0.15
@export var attack_window_duration: float = 0.2
@export var player_arrow_texture: Texture2D = preload("res://assets/skeleton_sprites/Skeleton_Archer/Arrow.png")
@export var player_arrow_speed: float = 560.0
@export var player_arrow_lifetime: float = 1.0
@export var player_arrow_spawn_offset: Vector2 = Vector2(20.0, -8.0)
@export var melee_attack_forward_offset: float = 26.0

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
@onready var _attack_area: Area2D = get_node_or_null("AttackArea")

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
var _last_reset_reason: StringName = &""
var _warned_missing_animations: Dictionary = {}
var _lock_event_processed: Dictionary = {}
var _debug_refresh_remaining: float = 0.0
var _debug_label: Label
var _attack_area_base_position: Vector2 = Vector2.ZERO
var _attack_window_hit_ids: Dictionary = {}

# Camera2D shake integration
@onready var _camera: Camera2D = get_node_or_null("Camera2D")

func shake_camera(intensity: float = 8.0, duration: float = 0.15) -> void:
	if _camera:
		var tween := create_tween()
		var original_offset := _camera.offset
		tween.tween_property(_camera, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), duration)
		tween.tween_property(_camera, "offset", original_offset, duration)

func _ready() -> void:
	_game_manager = get_node_or_null("/root/GameManager")
	_reset_lock_event_tracking()
	_connect_game_manager_signals()
	if _guardian_sprite:
		_sprite_base_position = _guardian_sprite.position
		_guardian_sprite.flip_h = _facing_left
		_guardian_sprite.animation_finished.connect(_on_guardian_animation_finished)
	if _attack_area:
		_attack_area_base_position = _attack_area.position
	_cache_states()
	_connect_state_signals()
	_initialize_state_contexts()
	_sync_state_locks_from_manager()
	_ensure_debug_widget()
	_set_attack_area_active(false)
	_activate_first_available_state()
	_refresh_debug_widget(true)

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

	_apply_attack_overlap_hits()

func _process(delta: float) -> void:
	if _active_state:
		_active_state.update(delta)
	_debug_refresh_remaining = max(_debug_refresh_remaining - delta, 0.0)
	_refresh_debug_widget(false)

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

	_try_consume_buffered_action()
	_refresh_debug_widget(true)

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

	if _active_state.has_method("should_open_attack_window") and _active_state.should_open_attack_window(action_name):
		_open_attack_window()

	if _active_state.can_accept_action(action_name):
		var handled: bool = _active_state.handle_action(action_name)
		if not handled:
			_buffer_action(action_name)
	else:
		_buffer_action(action_name)

func _open_attack_window() -> void:
	if not _attack_area:
		return

	_set_attack_area_active(true)
	var timer: SceneTreeTimer = get_tree().create_timer(max(attack_window_duration, 0.05))
	timer.timeout.connect(func() -> void:
		_set_attack_area_active(false)
	)

func _set_attack_area_active(is_active: bool) -> void:
	if not _attack_area:
		return
	_attack_area.monitoring = is_active
	_attack_area.monitorable = is_active
	if is_active:
		_attack_window_hit_ids.clear()
		var forward_sign := -1.0 if _facing_left else 1.0
		_attack_area.position = _attack_area_base_position + Vector2(melee_attack_forward_offset * forward_sign, 0.0)
	else:
		_attack_area.position = _attack_area_base_position

func _apply_attack_overlap_hits() -> void:
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

func spawn_player_arrow_projectile() -> void:
	if not _guardian_sprite:
		return

	var arrow := Area2D.new()
	arrow.name = "PlayerArrowProjectile"
	arrow.collision_layer = 32
	arrow.collision_mask = 8
	arrow.monitoring = true
	arrow.monitorable = true
	arrow.add_to_group("projectile")
	arrow.add_to_group("attack")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18.0, 5.0)
	shape.shape = rect
	arrow.add_child(shape)

	var sprite := Sprite2D.new()
	sprite.texture = player_arrow_texture
	sprite.centered = true
	arrow.add_child(sprite)

	var direction := Vector2.LEFT if _guardian_sprite.flip_h else Vector2.RIGHT
	arrow.rotation = direction.angle()
	arrow.global_position = _guardian_sprite.global_position + Vector2(player_arrow_spawn_offset.x * direction.x, player_arrow_spawn_offset.y +50.0)

	var host: Node = get_parent()
	if host:
		host.add_child(arrow)
	else:
		add_child(arrow)

	arrow.area_entered.connect(func(area: Area2D) -> void:
		if not area:
			return
		if area.name != "AttackHitbox":
			return
		if is_instance_valid(arrow):
			arrow.queue_free()
	)

	var travel_distance: float = player_arrow_speed * max(player_arrow_lifetime, 0.15)
	var target: Vector2 = arrow.global_position + (direction * travel_distance)
	var travel_time: float = travel_distance / max(player_arrow_speed, 1.0)

	var tween: Tween = arrow.create_tween()
	tween.tween_property(arrow, "global_position", target, travel_time)
	tween.finished.connect(func() -> void:
		if is_instance_valid(arrow):
			arrow.queue_free()
	)

func _buffer_action(action_name: StringName) -> void:
	_buffered_action = action_name
	_buffer_remaining = input_buffer_window
	_log_debug("Buffered action: %s" % String(action_name))
	_refresh_debug_widget(true)

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
	_log_debug("Consumed buffered action: %s" % String(action))
	_refresh_debug_widget(true)

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
	if _game_manager and _game_manager.has_method("lock_guardian"):
		_game_manager.lock_guardian(form_id)
	_handle_guardian_locked(form_id, &"state")

func _on_manager_guardian_locked(form_id: StringName) -> void:
	_handle_guardian_locked(form_id, &"manager")

func _handle_guardian_locked(form_id: StringName, source: StringName) -> void:
	if _states.has(form_id):
		(_states[form_id] as Node).is_locked = true

	if _lock_event_processed.get(form_id, false):
		return

	_lock_event_processed[form_id] = true
	form_locked.emit(form_id)
	_log_debug("Guardian locked (%s): %s" % [String(source), String(form_id)])

	if form_id == _active_form:
		_request_swap(+1)

	_refresh_debug_widget(true)

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
		_warn_missing_animation(animation_name)
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
		else:
			_warn_missing_animation(idle_animation)

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
		else:
			_warn_missing_animation(hold_idle_animation)
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
	else:
		_warn_missing_animation(idle_animation)

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

func _on_timeline_reset_requested(reason: StringName) -> void:
	_last_reset_reason = reason
	_log_debug("Timeline reset requested: %s" % String(reason))
	_refresh_debug_widget(true)
	call_deferred("_reset_run_flow")

func _reset_run_flow() -> void:
	if _game_manager and _game_manager.has_method("reset_run_state"):
		_game_manager.reset_run_state()

	_buffered_action = &""
	_buffer_remaining = 0.0
	_swap_coyote_remaining = 0.0
	_post_action_idle_remaining = 0.0
	_is_jumping = false
	_jump_elapsed = 0.0
	_jump_cooldown_remaining = 0.0
	_warned_missing_animations.clear()
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

func _warn_missing_animation(animation_name: StringName) -> void:
	if _warned_missing_animations.get(animation_name, false):
		return
	_warned_missing_animations[animation_name] = true
	push_warning("Missing animation '%s' for form '%s'." % [String(animation_name), String(_active_form)])

func _reset_lock_event_tracking() -> void:
	_lock_event_processed.clear()
	for form_id in FORM_ORDER:
		_lock_event_processed[form_id] = false

func _ensure_debug_widget() -> void:
	if not show_debug_widget:
		return

	var debug_layer := get_node_or_null("DebugLayer") as CanvasLayer
	if not debug_layer:
		debug_layer = CanvasLayer.new()
		debug_layer.name = "DebugLayer"
		add_child(debug_layer)

	var label := debug_layer.get_node_or_null("DebugLabel") as Label
	if not label:
		label = Label.new()
		label.name = "DebugLabel"
		label.position = Vector2(12.0, 12.0)
		label.z_index = 200
		debug_layer.add_child(label)

	_debug_label = label

func _refresh_debug_widget(force: bool) -> void:
	if not show_debug_widget:
		return
	if not _debug_label:
		return
	if not force and _debug_refresh_remaining > 0.0:
		return

	_debug_refresh_remaining = max(debug_refresh_rate, 0.02)
	var locked_forms := _get_locked_forms_for_debug()
	var buffered_action := String(_buffered_action)
	if buffered_action.is_empty():
		buffered_action = "<none>"

	var reset_reason := String(_last_reset_reason)
	if reset_reason.is_empty() and _game_manager and _game_manager.has_method("get_last_reset_reason"):
		reset_reason = String(_game_manager.get_last_reset_reason())
	if reset_reason.is_empty():
		reset_reason = "<none>"

	_debug_label.text = "Form: %s\nLocked: %s\nBuffered Action: %s\nLast Reset: %s" % [
		String(_active_form),
		", ".join(locked_forms) if not locked_forms.is_empty() else "<none>",
		buffered_action,
		reset_reason
	]

func _get_locked_forms_for_debug() -> PackedStringArray:
	var locked: PackedStringArray = []
	if _game_manager and _game_manager.has_method("get_locked_forms"):
		for form_id in _game_manager.get_locked_forms():
			locked.append(String(form_id))
		return locked

	for form_id in FORM_ORDER:
		if _states.has(form_id) and (_states[form_id] as Node).is_locked:
			locked.append(String(form_id))
	return locked

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
