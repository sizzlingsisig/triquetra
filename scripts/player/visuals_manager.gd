extends Node
class_name VisualsManager

## Manages player visuals: sprite, animation, camera, jump effects.

signal action_animation_finished(animation_name: StringName)
signal attack_window_toggled(active: bool)

@export var jump_height: float = 20.0
@export var jump_duration: float = 0.35
@export var jump_stretch_factor: float = 0.08
@export var post_action_idle_hold: float = 0.08

@export var attack_window_table: Dictionary = {
	&"sword_attack": Vector2(0.05, 0.18),
	&"sword_attack2": Vector2(0.05, 0.2),
	&"sword_attack3": Vector2(0.04, 0.18),
	&"sword_runattack": Vector2(0.04, 0.2),
	&"spear_attack": Vector2(0.04, 0.16),
	&"spear_attack_2": Vector2(0.05, 0.18),
	&"spear_impale": Vector2(0.06, 0.22)
}

var _player: CharacterBody2D = null
var _sprite: AnimatedSprite2D = null
var _camera: Camera2D = null
var _attack_timeline_player: AnimationPlayer = null

var _sprite_base_position: Vector2 = Vector2.ZERO
var _current_jump_offset: Vector2 = Vector2.ZERO
var _is_jumping: bool = false
var _jump_elapsed: float = 0.0
var _facing_left: bool = false
var _active_form: StringName = &"Sword"
var _post_action_idle_remaining: float = 0.0
var _current_action_animation: StringName = &""

func setup(player: CharacterBody2D, sprite: AnimatedSprite2D) -> void:
	_player = player
	_sprite = sprite
	_camera = player.get_node_or_null("Camera2D")
	_cache_sprite_base()
	_ensure_attack_timeline_player()
	_rebuild_attack_window_tracks()
	if _sprite and not _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.connect(_on_sprite_animation_finished)

func _cache_sprite_base() -> void:
	if _sprite:
		_sprite_base_position = _sprite.position
		_sprite.flip_h = _facing_left

func set_facing_left(facing_left: bool) -> void:
	_facing_left = facing_left
	if _sprite:
		_sprite.flip_h = _facing_left

func get_facing_left() -> bool:
	return _facing_left

func set_form(form_id: StringName) -> void:
	_active_form = form_id

func update_locomotion(velocity: Vector2, delta: float) -> void:
	if not _sprite or not _sprite.sprite_frames:
		return

	if _post_action_idle_remaining > 0.0:
		_post_action_idle_remaining = max(_post_action_idle_remaining - delta, 0.0)
		_play_idle_if_available()
		return

	if not _current_action_animation.is_empty():
		return

	if velocity.length_squared() > 4.0:
		var run_animation := StringName(String(_active_form).to_lower() + "_run")
		if _has_animation(run_animation):
			_play_if_changed(run_animation)
			return
		var walk_animation := StringName(String(_active_form).to_lower() + "_walk")
		if _has_animation(walk_animation):
			_play_if_changed(walk_animation)
			return

	_play_idle_if_available()

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
	if not _has_animation(animation_name):
		return false
	_play_animation(animation_name, reset_frame)
	if _is_action_clip(animation_name):
		_current_action_animation = animation_name
		_play_attack_window_timeline(animation_name)
	else:
		_current_action_animation = &""
		attack_window_toggled.emit(false)
	return true

func has_animation(animation_name: StringName) -> bool:
	if not _sprite or not _sprite.sprite_frames:
		return false
	return _sprite.sprite_frames.has_animation(animation_name)

func is_busy_with_action_animation() -> bool:
	return not _current_action_animation.is_empty()

func shake_camera(intensity: float = 8.0, duration: float = 0.15) -> void:
	if not _camera:
		return
	var tween := _player.create_tween()
	var original_offset := _camera.offset
	tween.tween_property(_camera, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), duration)
	tween.tween_property(_camera, "offset", original_offset, duration)

func connect_attack_window(callback: Callable) -> void:
	attack_window_toggled.connect(callback)

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
	_current_action_animation = &""
	_post_action_idle_remaining = 0.0
	attack_window_toggled.emit(false)
	if _sprite:
		_sprite.position = _sprite_base_position
		_sprite.scale = Vector2.ONE

func _ensure_attack_timeline_player() -> void:
	if _attack_timeline_player:
		return
	_attack_timeline_player = AnimationPlayer.new()
	_attack_timeline_player.name = "AttackWindowTimeline"
	add_child(_attack_timeline_player)

func _rebuild_attack_window_tracks() -> void:
	if not _attack_timeline_player:
		return

	var default_library: AnimationLibrary
	if _attack_timeline_player.has_animation_library(&""):
		default_library = _attack_timeline_player.get_animation_library(&"")
	else:
		default_library = AnimationLibrary.new()
		_attack_timeline_player.add_animation_library(&"", default_library)

	for animation_name in attack_window_table.keys():
		if default_library.has_animation(animation_name):
			default_library.remove_animation(animation_name)

		var window: Vector2 = attack_window_table[animation_name]
		var open_delay = max(window.x, 0.0)
		var close_delay = max(window.y, open_delay + 0.01)

		var timeline := Animation.new()
		timeline.length = close_delay + 0.02
		timeline.loop_mode = Animation.LOOP_NONE

		var track := timeline.add_track(Animation.TYPE_METHOD)
		timeline.track_set_path(track, NodePath("."))
		timeline.track_insert_key(track, open_delay, {
			"method": "_emit_attack_window",
			"args": [animation_name, true]
		})
		timeline.track_insert_key(track, close_delay, {
			"method": "_emit_attack_window",
			"args": [animation_name, false]
		})

		default_library.add_animation(animation_name, timeline)

func _play_attack_window_timeline(animation_name: StringName) -> void:
	if not _attack_timeline_player:
		attack_window_toggled.emit(false)
		return
	if not _attack_timeline_player.has_animation(animation_name):
		attack_window_toggled.emit(false)
		return
	_attack_timeline_player.play(animation_name)

func _emit_attack_window(animation_name: StringName, active: bool) -> void:
	if _current_action_animation != animation_name:
		return
	attack_window_toggled.emit(active)

func _is_action_clip(animation_name: StringName) -> bool:
	var clip := String(animation_name)
	if attack_window_table.has(animation_name):
		return true
	return (
		clip.ends_with("_attack")
		or clip.ends_with("_attack_2")
		or clip.ends_with("_attack2")
		or clip.ends_with("_attack3")
		or clip.ends_with("_runattack")
		or clip.ends_with("_block")
		or clip.ends_with("_impale")
		or clip.ends_with("_shot")
		or clip.ends_with("_shot_2")
		or clip.ends_with("_disengage")
		or clip.ends_with("_dead")
	)

func _on_sprite_animation_finished() -> void:
	if not _sprite:
		return

	if _current_action_animation == _sprite.animation:
		attack_window_toggled.emit(false)
		_post_action_idle_remaining = post_action_idle_hold
		action_animation_finished.emit(_current_action_animation)
		_current_action_animation = &""

func _play_idle_if_available() -> void:
	var idle_animation := StringName(String(_active_form).to_lower() + "_idle")
	if _has_animation(idle_animation):
		_play_if_changed(idle_animation)

func _has_animation(animation_name: StringName) -> bool:
	if not _sprite:
		return false
	if not _sprite.sprite_frames:
		return false
	return _sprite.sprite_frames.has_animation(animation_name)

func _play_animation(animation_name: StringName, reset_frame: bool) -> void:
	if not _sprite:
		return
	if not reset_frame and _sprite.animation == animation_name and _sprite.is_playing():
		return
	_sprite.play(animation_name)
	if reset_frame:
		_sprite.frame = 0

func _play_if_changed(animation_name: StringName) -> void:
	if not _sprite:
		return
	if _sprite.animation == animation_name and _sprite.is_playing():
		return
	_sprite.play(animation_name)