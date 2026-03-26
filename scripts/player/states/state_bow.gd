extends "res://scripts/player/states/base_guardian_state.gd"
class_name StateBow

## Bow form: ranged primary shots + disengage movement special.

const PRIMARY_ATTACK_ANIMATIONS: Array[StringName] = [
	&"bow_shot",
	&"bow_shot_2"
]

var _primary_attack_index: int = 0
var _action_sm = null

@export var disengage_speed: float = 260.0
@export var disengage_duration: float = 0.14
@export var disengage_particle_amount: int = 14
@export var slide_trail_interval: float = 0.04
@export var slide_trail_lifetime: float = 0.12
@export var slide_trail_alpha: float = 0.5
@export var arrow_scene: PackedScene

var _disengage_time_remaining: float = 0.0
var _trail_spawn_cooldown: float = 0.0
var _disengage_direction: float = 0.0

func _ready() -> void:
	form_id = &"Bow"

func enter(_previous_form: StringName) -> void:
	_primary_attack_index = 0
	_disengage_time_remaining = 0.0
	_trail_spawn_cooldown = 0.0
	_disengage_direction = 0.0
	is_busy = false
	_play_animation(&"bow_idle")
	_setup_action_state_machine()

func _setup_action_state_machine() -> void:
	if _action_sm:
		_action_sm.queue_free()
		_action_sm = null
	
	var ActionStateMachineScript = load("res://scripts/player/states/actions/action_state_machine.gd")
	_action_sm = ActionStateMachineScript.new()
	_player.add_child(_action_sm)
	_action_sm.setup(_player, _get_visuals_manager())
	
	var ActionIdleScript = load("res://scripts/player/states/actions/action_idle.gd")
	var ActionRunScript = load("res://scripts/player/states/actions/action_run.gd")
	var ActionAttackScript = load("res://scripts/player/states/actions/action_attack.gd")
	var ActionSpecialScript = load("res://scripts/player/states/actions/action_special.gd")
	
	_action_sm.add_action(&"Idle", ActionIdleScript.new())
	_action_sm.add_action(&"Run", ActionRunScript.new())
	
	var attack_action = ActionAttackScript.new()
	attack_action.attack_animations = PRIMARY_ATTACK_ANIMATIONS
	attack_action.attack_window_timing = Vector2(0.06, 0.2)
	_action_sm.add_action(&"Attack", attack_action)
	
	var special_action = ActionSpecialScript.new()
	special_action.special_animation = &"bow_disengage"
	special_action.can_move_during = true
	special_action.duration = disengage_duration
	_action_sm.add_action(&"Special", special_action)
	
	_action_sm.set_action(&"Idle")

func _get_visuals_manager() -> Node:
	if _player and _player.has_method("_visuals_manager"):
		var vm = _player.get("_visuals_manager")
		if vm:
			return vm
	return null

func handle_action(action_name: StringName) -> bool:
	if is_locked:
		return false
	
	if not _action_sm:
		return false
	
	match action_name:
		&"primary_attack":
			_spawn_arrow_from_state()
			return _action_sm.set_action(&"Attack")
		&"special":
			_begin_disengage()
			return _action_sm.set_action(&"Special")
		_:
			return false

func can_accept_action(_action_name: StringName) -> bool:
	if is_locked:
		return false
	if _action_sm and not _action_sm.can_player_move():
		return false
	return true

func physics_update(delta: float) -> void:
	if _action_sm:
		_action_sm.physics_update(delta)
	_handle_disengage_physics(delta)

func update(delta: float) -> void:
	if _action_sm:
		_action_sm.update(delta)

func _handle_disengage_physics(delta: float) -> void:
	if _disengage_time_remaining <= 0.0:
		return

	_disengage_time_remaining -= delta
	if _player:
		_player.velocity.x = _disengage_direction * disengage_speed

	_trail_spawn_cooldown -= delta
	if _trail_spawn_cooldown <= 0.0:
		_spawn_slide_trail_fx()
		_trail_spawn_cooldown = max(slide_trail_interval, 0.01)

	if _disengage_time_remaining <= 0.0:
		_disengage_time_remaining = 0.0
		_trail_spawn_cooldown = 0.0
		_disengage_direction = 0.0
		is_busy = false

func _begin_disengage() -> void:
	_disengage_time_remaining = max(disengage_duration, 0.01)
	_trail_spawn_cooldown = 0.0
	_disengage_direction = _get_backward_x_direction()
	is_busy = true
	_spawn_disengage_fx()

func _get_backward_x_direction() -> float:
	if not _player:
		return -1.0
	var guardian_sprite := _player.get_node_or_null("GuardianSprite") as AnimatedSprite2D
	if guardian_sprite and guardian_sprite.flip_h:
		return 1.0
	return -1.0

func _spawn_disengage_fx() -> void:
	if not _player:
		return
	var particles := CPUParticles2D.new()
	particles.name = "BowDisengageFx"
	particles.one_shot = true
	particles.emitting = false
	particles.amount = disengage_particle_amount
	particles.lifetime = 0.22
	particles.explosiveness = 1.0
	particles.spread = 28.0
	particles.direction = Vector2(-_disengage_direction, 0.0)
	particles.initial_velocity_min = 65.0
	particles.initial_velocity_max = 120.0
	particles.scale_amount_min = 1.1
	particles.scale_amount_max = 1.8
	particles.modulate = Color(0.65, 0.95, 1.0, 0.85)
	particles.position = Vector2(-_disengage_direction * 10.0, 0.0)
	_player.add_child(particles)
	particles.emitting = true
	var cleanup_timer: SceneTreeTimer = _player.get_tree().create_timer(particles.lifetime + 0.2)
	cleanup_timer.timeout.connect(_cleanup_disengage_fx)

func _cleanup_disengage_fx() -> void:
	var fx = _player.get_node_or_null("BowDisengageFx")
	if fx and is_instance_valid(fx):
		fx.queue_free()

func _spawn_slide_trail_fx() -> void:
	if not _player:
		return
	var guardian_sprite := _player.get_node_or_null("GuardianSprite") as AnimatedSprite2D
	if not guardian_sprite:
		return
	if not guardian_sprite.sprite_frames:
		return
	var current_animation: StringName = guardian_sprite.animation
	if not guardian_sprite.sprite_frames.has_animation(current_animation):
		return
	var frame_count: int = guardian_sprite.sprite_frames.get_frame_count(current_animation)
	if frame_count <= 0:
		return
	var frame_index: int = int(clamp(guardian_sprite.frame, 0, frame_count - 1))
	var frame_texture: Texture2D = guardian_sprite.sprite_frames.get_frame_texture(current_animation, frame_index)
	if not frame_texture:
		return
	var trail_node := Sprite2D.new()
	trail_node.texture = frame_texture
	trail_node.flip_h = guardian_sprite.flip_h
	trail_node.scale = guardian_sprite.scale
	trail_node.global_position = guardian_sprite.global_position
	trail_node.z_index = guardian_sprite.z_index - 1
	trail_node.modulate = Color(0.6, 0.95, 1.0, clamp(slide_trail_alpha, 0.0, 1.0))
	var host: Node = _player.get_parent()
	if host:
		host.add_child(trail_node)
	else:
		_player.add_child(trail_node)
	var trail_tween: Tween = trail_node.create_tween()
	trail_tween.set_parallel(true)
	trail_tween.tween_property(trail_node, "modulate:a", 0.0, max(slide_trail_lifetime, 0.01))
	trail_tween.tween_property(trail_node, "scale", trail_node.scale * 1.05, max(slide_trail_lifetime, 0.01))
	trail_tween.finished.connect(func(): 
		if is_instance_valid(trail_node):
			trail_node.queue_free()
	)

func _spawn_arrow_from_state() -> void:
	if not _player:
		return
	if not arrow_scene:
		return
	var timer: SceneTreeTimer = _player.get_tree().create_timer(0.06)
	timer.timeout.connect(_spawn_arrow_delayed)

func _spawn_arrow_delayed() -> void:
	if not _player:
		return
	var arrow: Node = arrow_scene.instantiate()
	if not arrow:
		return
	var host: Node = _player.get_parent()
	if host:
		host.add_child(arrow)
	else:
		_player.add_child(arrow)
	if arrow.has_method("launch"):
		var direction = _player.get_facing_direction() if _player.has_method("get_facing_direction") else Vector2.RIGHT
		var spawn_position = _player.get_arrow_spawn_position() if _player.has_method("get_arrow_spawn_position") else _player.global_position
		arrow.launch(spawn_position, direction)