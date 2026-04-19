extends Node
class_name PlayerAnimationManager

## Handles guardian sprite playback and attack window timeline callbacks.
## Keeps locomotion and action animation routing out of PlayerController.

signal action_animation_finished(animation_name: StringName)
signal attack_window_toggled(active: bool)

@export var post_action_idle_hold: float = 0.08

# Timing table keeps attack windows data-driven instead of scattering timers in states.
@export var attack_window_table: Dictionary = {
	&"sword_attack": Vector2(0.05, 0.18),
	&"sword_attack2": Vector2(0.05, 0.2),
	&"sword_attack3": Vector2(0.04, 0.18),
	&"sword_runattack": Vector2(0.04, 0.2),
	&"spear_attack": Vector2(0.04, 0.16),
	&"spear_attack_2": Vector2(0.05, 0.18),
	&"spear_impale": Vector2(0.06, 0.22)
}

var _player: CharacterBody2D
var _sprite: AnimatedSprite2D
var _attack_timeline_player: AnimationPlayer
var _active_form: StringName = &"Sword"
var _facing_left: bool = false
var _post_action_idle_remaining: float = 0.0
var _current_action_animation: StringName = &""

func setup(player: CharacterBody2D, sprite: AnimatedSprite2D) -> void:
	# Player reference is kept for future extension hooks.
	_player = player
	_sprite = sprite
	if _sprite and not _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.connect(_on_sprite_animation_finished)
	_ensure_attack_timeline_player()
	_rebuild_attack_window_tracks()

func set_form(form_id: StringName) -> void:
	_active_form = form_id

func set_facing_left(facing_left: bool) -> void:
	_facing_left = facing_left
	if _sprite:
		_sprite.flip_h = _facing_left

func play(animation_name: StringName, reset_frame: bool = true) -> bool:
	# Action clips trigger attack-window timeline playback.
	if not _has_animation(animation_name):
		return false
	_play_animation(animation_name, reset_frame)
	if _is_action_clip(animation_name):
		_current_action_animation = animation_name
		_play_attack_window_timeline(animation_name)
	else:
		_current_action_animation = &""
		call_deferred("_emit_attack_window_signal", false)
	return true

func play_or_fallback(animation_name: StringName, reset_frame: bool = true) -> bool:
	return play(animation_name, reset_frame)

func update_locomotion(velocity: Vector2, delta: float) -> void:
	# Chooses run/walk/idle when no action animation is currently active.
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

func is_busy_with_action_animation() -> bool:
	return not _current_action_animation.is_empty()

func _ensure_attack_timeline_player() -> void:
	_attack_timeline_player = get_node_or_null("AttackWindowTimeline") as AnimationPlayer
	if _attack_timeline_player:
		return
	_attack_timeline_player = AnimationPlayer.new()
	_attack_timeline_player.name = "AttackWindowTimeline"
	add_child(_attack_timeline_player)

func _rebuild_attack_window_tracks() -> void:
	# Rebuilds generated method-track animations from attack_window_table.
	if not _attack_timeline_player:
		return

	var default_library: AnimationLibrary
	if _attack_timeline_player.has_animation_library(&""):
		default_library = _attack_timeline_player.get_animation_library(&"")
	else:
		default_library = AnimationLibrary.new()
		_attack_timeline_player.add_animation_library(&"", default_library)

	for animation_name in attack_window_table.keys():
		var name: StringName = animation_name
		if default_library.has_animation(name):
			default_library.remove_animation(name)

		var window: Vector2 = attack_window_table[name]
		var open_delay = max(window.x, 0.0)
		var close_delay = max(window.y, open_delay + 0.01)

		var timeline := Animation.new()
		timeline.length = close_delay + 0.02
		timeline.loop_mode = Animation.LOOP_NONE

		var track := timeline.add_track(Animation.TYPE_METHOD)
		timeline.track_set_path(track, NodePath("."))
		timeline.track_insert_key(track, open_delay, {
			"method": "_emit_attack_window",
			"args": [name, true]
		})
		timeline.track_insert_key(track, close_delay, {
			"method": "_emit_attack_window",
			"args": [name, false]
		})

		default_library.add_animation(name, timeline)

func _play_attack_window_timeline(animation_name: StringName) -> void:
	if not _attack_timeline_player:
		return
	if not _attack_timeline_player.has_animation(animation_name):
		call_deferred("_emit_attack_window_signal", false)
		return
	_attack_timeline_player.play(animation_name)

func _emit_attack_window(animation_name: StringName, active: bool) -> void:
	if _current_action_animation != animation_name:
		return
	call_deferred("_emit_attack_window_signal", active)

func _emit_attack_window_signal(active: bool) -> void:
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
		call_deferred("_emit_attack_window_signal", false)
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
