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

var _visuals_manager = null
var _input_manager = null
var _combat_manager = null
var _form_manager = null

var _game_manager: Node

# Buffered commands are consumed during physics ticks so states can gate execution.
var _swap_coyote_remaining: float = 0.0
var _is_jumping: bool = false
var _jump_elapsed: float = 0.0
var _jump_cooldown_remaining: float = 0.0
var _sprite_base_position: Vector2 = Vector2.ZERO
var _body_collision_base_position: Vector2 = Vector2.ZERO
var _current_jump_offset: Vector2 = Vector2.ZERO
var _facing_left: bool = false
var _last_reset_reason: StringName = &""

func _animation_manager_has(method_name: StringName) -> bool:
	return _animation_manager != null and _animation_manager.has_method(method_name)

# Uses callv to keep this script resilient to component class parse/cache issues.
func _animation_manager_call(method_name: StringName, args: Array = []) -> Variant:
	if not _animation_manager_has(method_name):
		return null
	return _animation_manager.callv(method_name, args)

func shake_camera(intensity: float = 8.0, duration: float = 0.15) -> void:
	if _visuals_manager:
		_visuals_manager.shake_camera(intensity, duration)

func _ready() -> void:
	# Cache dependencies and initial local offsets before runtime updates begin.
	_game_manager = get_node_or_null("/root/GameManager")
	
	# Initialize VisualsManager
	var VisualsManagerScript := load("res://scripts/player/visuals_manager.gd")
	_visuals_manager = VisualsManagerScript.new()
	add_child(_visuals_manager)
	_visuals_manager.setup(self, _guardian_sprite, _animation_manager)
	_visuals_manager.jump_height = jump_height
	_visuals_manager.jump_duration = jump_duration
	_visuals_manager.set_facing_left(_facing_left)
	
	# Initialize CombatManager
	var CombatManagerScript := load("res://scripts/player/combat_manager.gd")
	_combat_manager = CombatManagerScript.new()
	add_child(_combat_manager)
	_combat_manager.setup(self, _attack_area, _visuals_manager)
	_visuals_manager.connect_attack_window(_on_attack_window_toggled)
	
	# Initialize InputManager
	var InputManagerScript := load("res://scripts/player/input_manager.gd")
	_input_manager = InputManagerScript.new()
	add_child(_input_manager)
	_input_manager.setup(self, _create_action_callback())
	_input_manager.input_buffer_window = input_buffer_window
	_input_manager.action_move_left = action_move_left
	_input_manager.action_move_right = action_move_right
	_input_manager.action_attack = action_attack
	_input_manager.action_special = action_special
	_input_manager.action_jump = action_jump
	_input_manager.action_swap_next = action_swap_next
	_input_manager.action_swap_prev = action_swap_prev
	
	# Initialize FormManager
	var FormManagerScript := load("res://scripts/player/form_manager.gd")
	_form_manager = FormManagerScript.new()
	add_child(_form_manager)
	_form_manager.setup(self, _game_manager, _states_root, _visuals_manager)
	_form_manager.set_initial_form(&"Sword")
	if _form_manager.has_signal("form_changed"):
		_form_manager.form_changed.connect(func(id): form_changed.emit(id))
	if _form_manager.has_signal("form_locked"):
		_form_manager.form_locked.connect(func(id): form_locked.emit(id))
	
	# Set initial attack area state
	if _combat_manager:
		_combat_manager.set_attack_area_active(false, _facing_left)
	
	_setup_debug_widget()

func _on_attack_window_toggled(is_active: bool) -> void:
	if _combat_manager and _visuals_manager:
		var facing_left: bool = false
		if _visuals_manager.has_method("get_facing_left"):
			facing_left = _visuals_manager.get_facing_left()
		_combat_manager.set_attack_area_active(is_active, facing_left)

func _physics_process(delta: float) -> void:
	_apply_movement()
	if _input_manager:
		_input_manager.consume_command_buffer(delta)

	if _input_manager:
		_input_manager.consume_command_buffer(delta)

	if _form_manager:
		_form_manager.physics_update(delta)

	if _visuals_manager:
		_visuals_manager.update_jump(delta)
		_visuals_manager.update_locomotion(velocity, delta)

	move_and_slide()

	if _swap_coyote_remaining > 0.0:
		_swap_coyote_remaining -= delta

	if _jump_cooldown_remaining > 0.0:
		_jump_cooldown_remaining -= delta

	if _combat_manager:
		_combat_manager.apply_hit_detection(_form_manager.get_active_form_id())
	_apply_jump_offset_to_nodes()

func _process(delta: float) -> void:
	if _form_manager:
		_form_manager.update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _input_manager:
		_input_manager._unhandled_input(event)

func _create_action_callback() -> Callable:
	return func(command_id: StringName) -> bool:
		if not _form_manager:
			return false
		match command_id:
			&"swap_next":
				return _form_manager.request_swap(+1)
			&"swap_prev":
				return _form_manager.request_swap(-1)
			&"jump":
				return _try_start_jump()
			&"primary_attack":
				return _form_manager.handle_action(&"primary_attack")
			&"special":
				return _form_manager.handle_action(&"special")
		return false

func receive_enemy_hit() -> void:
	if _form_manager:
		_form_manager.receive_lethal_damage()

func _apply_movement() -> void:
	# Top-down style directional movement with normalized diagonals.
	var input_direction := Vector2.ZERO
	input_direction.x = Input.get_axis(action_move_left, action_move_right)

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
	if _visuals_manager:
		_visuals_manager.set_facing_left(facing_left)
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
	# Keep sprite, body collision aligned during jump arc.
	# Attack area is now managed by CombatManager.
	if _guardian_sprite:
		_guardian_sprite.position = _sprite_base_position + _current_jump_offset
	if _body_collision_shape:
		_body_collision_shape.position = _body_collision_base_position + _current_jump_offset
	if _combat_manager:
		_combat_manager.update_jump_offset(_current_jump_offset, _facing_left)

func _is_action_just_pressed(event: InputEvent, action_name: StringName) -> bool:
	if action_name.is_empty():
		return false
	if not InputMap.has_action(action_name):
		return false
	return event.is_action_pressed(action_name)

func play_guardian_animation(animation_name: StringName, reset_frame: bool = true) -> void:
	if _visuals_manager and _visuals_manager.play_animation(animation_name, reset_frame):
		return
	if _guardian_sprite and _guardian_sprite.sprite_frames and _guardian_sprite.sprite_frames.has_animation(animation_name):
		_guardian_sprite.play(animation_name)
		if reset_frame:
			_guardian_sprite.frame = 0

func has_guardian_animation(animation_name: StringName) -> bool:
	if _visuals_manager:
		return _visuals_manager.has_animation(animation_name)
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

	if _input_manager:
		_input_manager.clear_buffer()
	_swap_coyote_remaining = 0.0
	_is_jumping = false
	_jump_elapsed = 0.0
	_jump_cooldown_remaining = 0.0
	_current_jump_offset = Vector2.ZERO
	if _form_manager:
		_form_manager.reset()
	if _visuals_manager:
		_visuals_manager.reset()
	if _combat_manager:
		_combat_manager.reset()
	_reload_current_scene()

func _reload_current_scene() -> void:
	var tree := get_tree()
	if not tree:
		return
	if tree.current_scene and not tree.current_scene.scene_file_path.is_empty():
		tree.change_scene_to_file(tree.current_scene.scene_file_path)
		return
	tree.reload_current_scene()

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

func _log_debug(message: String) -> void:
	if not debug_log_events:
		return
	print("[PlayerController] %s" % message)

func get_active_form_id() -> StringName:
	if _form_manager:
		return _form_manager.get_active_form_id()
	return &"Sword"

func get_buffered_command_for_debug() -> String:
	if _input_manager:
		var cmd: StringName = _input_manager.get_buffered_command()
		if cmd.is_empty():
			return "<none>"
		return String(cmd)
	return "<none>"

func get_last_reset_reason_for_debug() -> String:
	return String(_last_reset_reason)

func get_locked_forms_for_debug() -> PackedStringArray:
	if _form_manager:
		return _form_manager.get_locked_forms()
	return PackedStringArray()

func get_facing_direction() -> Vector2:
	# Shared utility for states/components (for example bow projectile spawn direction).
	return Vector2.LEFT if _facing_left else Vector2.RIGHT

func get_arrow_spawn_position() -> Vector2:
	var direction: Vector2 = get_facing_direction()
	if _visuals_manager:
		var sprite_pos: Vector2 = _visuals_manager.get_sprite_global_position()
		var jump_offset: Vector2 = _visuals_manager.get_jump_offset()
		return sprite_pos + Vector2(direction.x * 20.0, -8.0 + jump_offset.y)
	if not _guardian_sprite:
		return global_position
	return _guardian_sprite.global_position + Vector2(direction.x * 20.0, -8.0 + _current_jump_offset.y)
