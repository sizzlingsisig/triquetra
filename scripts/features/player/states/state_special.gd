class_name StateSpecial
extends PlayerStateNode

var _animation_finished: bool = false
var _timer: float = 0.0
var _motion_blur: ShaderMaterial
var _blur_tween: Tween

const SPECIAL_DURATION: float = 1.2
const THRUST_SPEED: float = 750.0
const THRUST_FRICTION: float = 1000.0

func _ready() -> void:
	state_id = Fsm.PlayerStates.SPECIAL
	_motion_blur = ShaderMaterial.new()
	_motion_blur.shader = preload("res://shaders/motion_blur.gdshader")

func enter(_prev: int) -> void:
	_animation_finished = false
	_timer = 0.0
	var sprite: AnimatedSprite2D = _controller.get_sprite()
	if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

	if _controller.form_id == &"Spear":
		_controller.play_animation(&"run_attack")
		_controller.spawn_spear_lunge()
		var dir: float = 1.0 if _controller.is_facing_left() else -1.0
		var forward_dir: float = -dir
		_controller.velocity.x = forward_dir * THRUST_SPEED
		if sprite:
			sprite.material = _motion_blur
			_motion_blur.set_shader_parameter(&"intensity", 1.0)
			_motion_blur.set_shader_parameter(&"direction", Vector2(forward_dir, 0.0))
			# Animate blur from strong to none over the thrust
			_blur_tween = create_tween()
			_blur_tween.tween_method(func(v: float): _motion_blur.set_shader_parameter(&"intensity", v), 1.0, 0.0, 0.35)
		# Camera shake
		var vfx := _controller.get_node_or_null("VFXComponent") as PlayerVFXComponent
		if vfx:
			vfx.trigger_camera_shake(3.0, 0.12)
			vfx.spawn_speed_trail(forward_dir)
	elif _controller.form_id == &"Sword":
		_controller.play_animation(&"block")
		if sprite:
			# Brief white flash then settle to blue shield tint
			sprite.self_modulate = Color.WHITE
			var flash_tween: Tween = create_tween()
			flash_tween.tween_property(sprite, "self_modulate", Color(0.6, 0.7, 1.0), 0.1)
		var vfx := _controller.get_node_or_null("VFXComponent") as PlayerVFXComponent
		if vfx:
			vfx.spawn_shield_ring()

func exit(_next: int) -> void:
	if _blur_tween:
		_blur_tween.kill()
		_blur_tween = null
	var sprite: AnimatedSprite2D = _controller.get_sprite()
	if sprite:
		_motion_blur.set_shader_parameter(&"intensity", 0.0)
		sprite.self_modulate = Color.WHITE
		if sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.disconnect(_on_animation_finished)

func can_accept_command(_cmd: StringName) -> bool:
	return false

func handle_action(_cmd: StringName) -> bool:
	return false

func _on_animation_finished() -> void:
	_animation_finished = true

func physics_update(delta: float) -> void:
	_timer += delta

	if _controller.form_id == &"Spear":
		_controller.velocity.x = move_toward(_controller.velocity.x, 0.0, THRUST_FRICTION * delta)
		if _movement:
			_movement.apply_gravity(delta)
		if _animation_finished or _timer >= 0.5:
			_controller.velocity.x = 0.0
			_fsm.force_state(Fsm.PlayerStates.IDLE, &"thrust_finished")
	else:
		# Lock horizontal movement during block, but keep gravity
		_controller.velocity.x = 0.0
		if not _controller.is_on_floor() and _movement:
			_movement.apply_gravity(delta)
		if _timer >= SPECIAL_DURATION:
			_controller.velocity.x = 0.0
			_fsm.force_state(Fsm.PlayerStates.IDLE, &"timeout")
		elif _animation_finished:
			_controller.velocity.x = 0.0
			_fsm.force_state(Fsm.PlayerStates.IDLE, &"animation_finished")