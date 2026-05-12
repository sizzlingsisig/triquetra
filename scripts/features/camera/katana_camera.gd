extends Camera2D
class_name KatanaCamera

@export var follow_speed: float = 6.0
@export var look_ahead_base: float = 30.0
@export var look_ahead_max: float = 100.0
@export var look_ahead_speed_curve: float = 400.0
@export var vertical_bias: float = -25.0

var _target: PlayerController
var _form_manager: FormManager

func _ready() -> void:
	# Give one frame for FormManager._initialize() to run
	set_physics_process(false)
	_find_form_manager()

func _find_form_manager() -> void:
	_form_manager = get_parent().get_node_or_null("FormManager") as FormManager
	if _form_manager:
		_form_manager.active_player_changed.connect(_on_active_player_changed)
		# Check if FormManager already initialized
		if _form_manager._active_player:
			_on_active_player_changed(_form_manager._active_player)
	# Enable processing next frame regardless
	set_physics_process(true)

func _on_active_player_changed(player: PlayerController) -> void:
	_target = player
	# Snap to target immediately on swap
	if _target:
		var facing_dir: float = -1.0 if _target.is_facing_left() else 1.0
		global_position = Vector2(
			_target.global_position.x + look_ahead_base * facing_dir,
			_target.global_position.y + vertical_bias
		)

func _physics_process(delta: float) -> void:
	if not _target:
		if _form_manager and _form_manager._active_player:
			_on_active_player_changed(_form_manager._active_player)
		return

	var speed: float = absf(_target.velocity.x)
	var facing_dir: float = -1.0 if _target.is_facing_left() else 1.0
	var t: float = clampf(speed / look_ahead_speed_curve, 0.0, 1.0)
	var look_x: float = lerpf(look_ahead_base, look_ahead_max, t) * facing_dir

	var target_pos: Vector2 = Vector2(
		_target.global_position.x + look_x,
		_target.global_position.y + vertical_bias
	)
	global_position = global_position.lerp(target_pos, follow_speed * delta)
