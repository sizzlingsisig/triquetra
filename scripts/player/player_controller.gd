extends CharacterBody2D
class_name PlayerController

signal form_changed(form_id: StringName)
signal form_locked(form_id: StringName)

@export var show_debug_widget: bool = true
@export var debug_log_events: bool = true

@onready var _states_root: Node = $States
@onready var _guardian_sprite: AnimatedSprite2D = $GuardianSprite
@onready var _attack_area: Area2D = get_node_or_null("AttackArea")
@onready var _body_collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var _animation_manager: PlayerAnimationManager = get_node_or_null("AnimationManager") as PlayerAnimationManager
@onready var _debug_widget: PlayerDebugWidget = get_node_or_null("PlayerDebugWidget") as PlayerDebugWidget

@onready var input_buffer: PlayerInputBuffer = get_node_or_null("InputBuffer")
@onready var movement_component: PlayerMovementComponent = get_node_or_null("MovementComponent")
@onready var combat_component: PlayerCombatComponent = get_node_or_null("CombatComponent")
@onready var form_manager: PlayerFormManager = get_node_or_null("FormManager")
var runtime_fsm: PlayerRuntimeFsm

var _game_manager: Node
var _game_state_machine: Node

var _sprite_base_position: Vector2 = Vector2.ZERO
var _body_collision_base_position: Vector2 = Vector2.ZERO
var _attack_area_base_position: Vector2 = Vector2.ZERO
var _facing_left: bool = false
var _last_reset_reason: StringName = &""
var _is_resetting: bool = false

@onready var _camera: Camera2D = get_node_or_null("Camera2D")

func shake_camera(intensity: float = 8.0, duration: float = 0.15) -> void:
	if _camera:
		var tween := create_tween()
		var original_offset := _camera.offset
		tween.tween_property(_camera, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), duration)
		tween.tween_property(_camera, "offset", original_offset, duration)

func _ready() -> void:
	_game_manager = get_node_or_null("/root/GameManager")
	_game_state_machine = get_node_or_null("/root/GameStateMachine")

	_connect_game_manager_signals()
	if _game_state_machine and _game_state_machine.has_method("set_playing"):
		_game_state_machine.set_playing(&"run_start")

	if _guardian_sprite:
		_sprite_base_position = _guardian_sprite.position
		_guardian_sprite.flip_h = _facing_left
	if _body_collision_shape:
		_body_collision_base_position = _body_collision_shape.position
	if _attack_area:
		_attack_area_base_position = _attack_area.position

	if not input_buffer or not movement_component or not combat_component or not form_manager:
		push_error("PlayerController: missing required component nodes in player.tscn.")
		return

	runtime_fsm = get_node_or_null("RuntimeFsm") as PlayerRuntimeFsm
	if runtime_fsm == null:
		runtime_fsm = PlayerRuntimeFsm.new()
		runtime_fsm.name = "RuntimeFsm"
		add_child(runtime_fsm)
	runtime_fsm.setup(self, movement_component, _animation_manager, form_manager, _game_manager)

	input_buffer.setup(self)
	movement_component.setup(self)
	combat_component.setup(self)
	form_manager.setup(self)

	if _animation_manager:
		_animation_manager.setup(self, _guardian_sprite)
		_animation_manager.set_form(form_manager.get_active_form_id())
		_animation_manager.set_facing_left(_facing_left)
		if not _animation_manager.attack_window_toggled.is_connected(_set_attack_area_active):
			_animation_manager.attack_window_toggled.connect(_set_attack_area_active)

	form_manager.cache_states(_states_root)
	form_manager.initialize_state_contexts(_game_manager)
	form_manager.sync_state_locks_from_manager(_game_manager)

	_set_attack_area_active(false)
	form_manager.activate_first_available_state(_game_manager)
	_setup_debug_widget()
	runtime_fsm.update(0.0)

func _physics_process(delta: float) -> void:
	if _can_process_movement():
		movement_component.apply_gravity(delta)
		movement_component.apply_movement(delta)
	else:
		velocity = Vector2.ZERO

	if _can_process_combat():
		runtime_fsm.physics_update(delta)
		input_buffer.process_buffer(delta)
	else:
		runtime_fsm.physics_update(delta)
		input_buffer.clear()

	form_manager.physics_update(delta)
	movement_component.update_jump(delta)

	if _animation_manager:
		_animation_manager.update_locomotion(velocity, delta)

	move_and_slide()

func _process(delta: float) -> void:
	runtime_fsm.update(delta)
	form_manager.update(delta)

func _connect_game_manager_signals() -> void:
	if not _game_manager:
		return
	if _game_manager.has_signal("guardian_locked") and not _game_manager.guardian_locked.is_connected(_on_manager_guardian_locked):
		_game_manager.guardian_locked.connect(_on_manager_guardian_locked)
	if _game_manager.has_signal("timeline_reset_requested") and not _game_manager.timeline_reset_requested.is_connected(_on_timeline_reset_requested):
		_game_manager.timeline_reset_requested.connect(_on_timeline_reset_requested)
	if _game_manager.has_signal("game_over_requested") and not _game_manager.game_over_requested.is_connected(_on_game_over_requested):
		_game_manager.game_over_requested.connect(_on_game_over_requested)

func _on_manager_guardian_locked(form_id: StringName) -> void:
	form_manager.handle_guardian_locked(form_id, &"manager")

func _try_execute_command(command_id: StringName) -> bool:
	match command_id:
		input_buffer.COMMAND_SWAP_NEXT:
			form_manager.request_swap(+1, _game_manager)
			return true
		input_buffer.COMMAND_SWAP_PREV:
			form_manager.request_swap(-1, _game_manager)
			return true
		input_buffer.COMMAND_JUMP:
			var did_jump: bool = _try_start_jump()
			if did_jump:
				runtime_fsm.on_command_executed(command_id)
			return did_jump
		input_buffer.COMMAND_PRIMARY_ATTACK:
			if runtime_fsm and not runtime_fsm.can_accept_command(command_id):
				return false
			var did_attack: bool = form_manager.request_action(&"primary_attack")
			if did_attack:
				runtime_fsm.on_command_executed(command_id)
			return did_attack
		input_buffer.COMMAND_SPECIAL:
			if runtime_fsm and not runtime_fsm.can_accept_command(command_id):
				return false
			var did_special: bool = form_manager.request_action(&"special")
			if did_special:
				runtime_fsm.on_command_executed(command_id)
			return did_special
		_:
			_log_debug("Ignored unknown command id: %s" % String(command_id))
			return false

func _try_start_jump() -> bool:
	return movement_component.try_start_jump()

func _set_attack_area_active(is_active: bool) -> void:
	combat_component.set_attack_area_active(is_active)

func receive_enemy_hit() -> void:
	combat_component.receive_enemy_hit()

func _set_sprite_facing(facing_left: bool) -> void:
	_facing_left = facing_left
	if _animation_manager:
		_animation_manager.set_facing_left(_facing_left)
	elif _guardian_sprite:
		_guardian_sprite.flip_h = _facing_left

func _apply_jump_offset_to_nodes() -> void:
	var offset = movement_component.get_jump_offset()
	if _guardian_sprite:
		_guardian_sprite.position = _sprite_base_position + offset
	if _body_collision_shape:
		_body_collision_shape.position = _body_collision_base_position + offset
	if _attack_area:
		var attack_forward := Vector2.ZERO
		if _attack_area.monitoring:
			attack_forward.x = -24.0 if _facing_left else 24.0
		_attack_area.position = _attack_area_base_position + attack_forward + offset

func play_guardian_animation(animation_name: StringName, reset_frame: bool = true) -> void:
	if _animation_manager:
		var played: bool = _animation_manager.play(animation_name, reset_frame)
		if played:
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
	if _is_resetting:
		return

	if _game_state_machine and _game_state_machine.has_method("set_playing"):
		_game_state_machine.set_playing(&"timeline_reset")

	_is_resetting = true
	_last_reset_reason = reason
	_log_debug("Timeline reset requested: %s" % String(reason))
	call_deferred("_reset_run_flow")

func _on_game_over_requested(reason: StringName) -> void:
	_last_reset_reason = reason
	if runtime_fsm:
		runtime_fsm.transition_to(PlayerRuntimeFsm.PlayerState.DEAD, &"game_over")
	input_buffer.clear()
	if _game_state_machine and _game_state_machine.has_method("enter_game_over"):
		_game_state_machine.enter_game_over(reason)

func _reset_run_flow() -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()
	if not tree:
		return

	var scene_path: String = ""
	if tree.current_scene:
		scene_path = tree.current_scene.scene_file_path

	if _game_manager and _game_manager.has_method("reset_run_state"):
		_game_manager.reset_run_state()

	input_buffer.clear()
	movement_component.reset()
	form_manager.reset()
	if runtime_fsm:
		runtime_fsm.reset()

	_reload_current_scene(tree, scene_path)

func _reload_current_scene(tree: SceneTree, scene_path: String) -> void:
	if not tree:
		_is_resetting = false
		return
	if not scene_path.is_empty():
		tree.call_deferred("change_scene_to_file", scene_path)
		return
	tree.call_deferred("reload_current_scene")

func _setup_debug_widget() -> void:
	if not show_debug_widget:
		if _debug_widget:
			_debug_widget.visible = false
		return

	if not _debug_widget:
		return
	_debug_widget.visible = true
	_debug_widget.setup(self, _game_manager)

func _log_debug(message: String) -> void:
	if not debug_log_events:
		return
	print("[PlayerController] %s" % message)

func _can_process_movement() -> bool:
	if not _game_state_machine:
		return true
	if _game_state_machine.has_method("can_process_movement"):
		return _game_state_machine.can_process_movement()
	return true

func _can_process_combat() -> bool:
	if not _game_state_machine:
		return true
	if _game_state_machine.has_method("can_process_combat"):
		return _game_state_machine.can_process_combat()
	return true

func _is_game_over_state() -> bool:
	if not _game_state_machine:
		return false
	if _game_state_machine.has_method("is_game_over"):
		return _game_state_machine.is_game_over()
	return false

func _toggle_pause_state() -> void:
	if not _game_state_machine:
		return
	if _game_state_machine.has_method("toggle_pause"):
		_game_state_machine.toggle_pause()

func _request_retry_from_game_over() -> void:
	if not _is_game_over_state():
		return
	if _game_manager and _game_manager.has_method("request_timeline_reset"):
		_game_manager.request_timeline_reset(&"game_over_retry")

func get_active_form_id() -> StringName:
	return form_manager.get_active_form_id() if form_manager else &""

func get_buffered_command_for_debug() -> String:
	return input_buffer.get_buffered_command_for_debug() if input_buffer else "<none>"

func get_last_reset_reason_for_debug() -> String:
	return String(_last_reset_reason)

func get_locked_forms_for_debug() -> PackedStringArray:
	return form_manager.get_locked_forms_for_debug(_game_manager) if form_manager else PackedStringArray()

func get_facing_direction() -> Vector2:
	return Vector2.LEFT if _facing_left else Vector2.RIGHT

func get_arrow_spawn_position() -> Vector2:
	if not _guardian_sprite:
		return global_position
	var direction := get_facing_direction()
	return _guardian_sprite.global_position + Vector2(direction.x * 20.0, 4.0)
