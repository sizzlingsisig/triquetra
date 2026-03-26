extends Node
class_name VisualsManager

## Manages player visuals: sprite, animation, camera, jump effects.

@export var jump_height: float = 20.0
@export var jump_duration: float = 0.35
@export var jump_stretch_factor: float = 0.08

var _player: CharacterBody2D = null
var _sprite: AnimatedSprite2D = null
var _camera: Camera2D = null
var _animation_manager: Node = null

var _sprite_base_position: Vector2 = Vector2.ZERO
var _current_jump_offset: Vector2 = Vector2.ZERO
var _is_jumping: bool = false
var _jump_elapsed: float = 0.0
var _facing_left: bool = false

func setup(player: CharacterBody2D, sprite: AnimatedSprite2D, animation_manager: Node = null) -> void:
	_player = player
	_sprite = sprite
	_animation_manager = animation_manager
	_camera = player.get_node_or_null("Camera2D")
	
	_cache_sprite_base()

func _cache_sprite_base() -> void:
	if _sprite:
		_sprite_base_position = _sprite.position
		_sprite.flip_h = _facing_left

func set_facing_left(facing_left: bool) -> void:
	_facing_left = facing_left
	if _sprite:
		_sprite.flip_h = _facing_left

func is_facing_left() -> bool:
	return _facing_left

func update_locomotion(velocity: Vector2, delta: float) -> void:
	if _animation_manager_has("update_locomotion"):
		_animation_manager_call("update_locomotion", [velocity, delta])

func update_jump(delta: float) -> void:
	if not _sprite:
		return
	
	if not _is_jumping:
		_current_jump_offset = Vector2.ZERO
		_apply_jump_offset()
		_sprite.scale = Vector2.ONE
		return
	
	_jump_elapsed += delta
	var t: float = clamp(_jump_elapsed / jump_duration, 0.0, 1.0)
	var arc: float = sin(t * PI)
	
	_current_jump_offset = Vector2(0.0, -arc * jump_height)
	_apply_jump_offset()
	var stretch: float = 1.0 + (jump_stretch_factor * arc)
	_sprite.scale = Vector2(stretch, stretch)
	
	if t >= 1.0:
		_is_jumping = false
		_current_jump_offset = Vector2.ZERO
		_apply_jump_offset()
		_sprite.scale = Vector2.ONE

func start_jump() -> void:
	_is_jumping = true
	_jump_elapsed = 0.0

func is_jumping() -> bool:
	return _is_jumping

func _apply_jump_offset() -> void:
	if not _sprite:
		return
	_sprite.position = _sprite_base_position + _current_jump_offset

func play_animation(animation_name: StringName, reset_frame: bool = true) -> bool:
	if _animation_manager_has("play"):
		var result = _animation_manager_call("play", [animation_name, reset_frame])
		if result is bool and result:
			return true
	
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(animation_name):
		_sprite.play(animation_name)
		if reset_frame:
			_sprite.frame = 0
		return true
	
	return false

func has_animation(animation_name: StringName) -> bool:
	if _animation_manager_has("has_guardian_animation"):
		return _animation_manager_call("has_guardian_animation", [animation_name]) as bool
	
	if not _sprite or not _sprite.sprite_frames:
		return false
	return _sprite.sprite_frames.has_animation(animation_name)

func shake_camera(intensity: float = 8.0, duration: float = 0.15) -> void:
	if not _camera:
		return
	var tween := _player.create_tween()
	var original_offset := _camera.offset
	tween.tween_property(_camera, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), duration)
	tween.tween_property(_camera, "offset", original_offset, duration)

func set_form(form_id: StringName) -> void:
	if _animation_manager_has("set_form"):
		_animation_manager_call("set_form", [form_id])

func connect_attack_window(callback: Callable) -> void:
	if _animation_manager and _animation_manager.has_signal("attack_window_toggled"):
		_animation_manager.attack_window_toggled.connect(callback)

func _animation_manager_has(method_name: StringName) -> bool:
	return _animation_manager != null and _animation_manager.has_method(method_name)

func _animation_manager_call(method_name: StringName, args: Array = []) -> Variant:
	if not _animation_manager_has(method_name):
		return null
	return _animation_manager.callv(method_name, args)

func get_sprite() -> AnimatedSprite2D:
	return _sprite

func get_sprite_global_position() -> Vector2:
	if _sprite:
		return _sprite.global_position
	return Vector2.ZERO

func get_jump_offset() -> Vector2:
	return _current_jump_offset

func reset() -> void:
	_is_jumping = false
	_jump_elapsed = 0.0
	_current_jump_offset = Vector2.ZERO
	if _sprite:
		_sprite.position = _sprite_base_position
		_sprite.scale = Vector2.ONE