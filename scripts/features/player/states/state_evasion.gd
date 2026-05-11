class_name StateEvasion
extends PlayerStateNode

const Fsm = preload("res://scripts/features/player/player_fsm.gd")

const DASH_SPEED: float = 400.0

var _animation_finished: bool = false
var _motion_blur: ShaderMaterial

func _ready() -> void:
	state_id = Fsm.PlayerStateNode.EVASION
	_motion_blur = ShaderMaterial.new()
	_motion_blur.shader = preload("res://shaders/motion_blur.gdshader")

func enter(_prev: int) -> void:
	_animation_finished = false

	# Apply motion blur shader to sprite
	var sprite: AnimatedSprite2D = _controller.get_sprite()
	if sprite:
		sprite.material = _motion_blur
		_motion_blur.set_shader_parameter(&"intensity", 0.8)
		if not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)

	# Dash in opposite facing direction
	var dash_dir: float = 1.0 if _controller.is_facing_left() else -1.0
	_controller.velocity.x = dash_dir * DASH_SPEED
	_motion_blur.set_shader_parameter(&"direction", Vector2(dash_dir, 0.0))

	_controller.play_animation(&"evasion")

func exit(_next: int) -> void:
	var sprite: AnimatedSprite2D = _controller.get_sprite()
	if sprite:
		sprite.material = null
		if sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.disconnect(_on_animation_finished)

func can_accept_command(_cmd: StringName) -> bool:
	return false

func handle_action(_cmd: StringName) -> bool:
	return false

func _on_animation_finished() -> void:
	_animation_finished = true

func physics_update(delta: float) -> void:
	if _animation_finished:
		_controller.velocity.x = move_toward(_controller.velocity.x, 0.0, DASH_SPEED * delta)
		_fsm.force_state(Fsm.PlayerStateNode.IDLE, &"animation_finished")
