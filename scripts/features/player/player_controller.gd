extends CharacterBody2D
class_name PlayerController

@export var form_id: StringName = &"Sword"
@export var move_speed: float = 180.0
@export var jump_velocity: float = -350.0
@export var gravity: float = 980.0
@export var max_fall_speed: float = 1200.0
@export var attack_offset: Vector2 = Vector2(24, -10)
@export var hitbox_lifetime: float = 0.15
@export var sprite_scale: float = 1.5

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _health_component: HealthComponent = $HealthComponent
@onready var _hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
var _input_buffer: Node

func get_input_buffer() -> Node:
	return _input_buffer
@onready var _fsm: PlayerRuntimeFsm = $Fsm

var _facing: Vector2 = Vector2.RIGHT

var form_manager: FormManager

var _facing_left: bool = false

## Emitted when the active guardian form changes.
@warning_ignore("unused_signal")
signal form_changed(form_id: StringName)
## Emitted when a guardian form becomes permanently locked (death).
@warning_ignore("unused_signal")
signal form_locked(form_id: StringName)

var runtime_fsm:
	get: return _fsm

var health_component: HealthComponent:
	get: return _health_component

func _ready() -> void:
	_health_component.set_max_health(_get_form_max_health())
	_health_component.died.connect(_on_health_depleted)
	_set_collision_layers()
	_configure_hurtbox()
	if _sprite:
		_sprite.scale = Vector2(sprite_scale, sprite_scale)
	if _collision_shape and _collision_shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = _collision_shape.shape
		rect.size = rect.size * sprite_scale
	if _fsm:
		_fsm.setup(self)
	_input_buffer = get_node_or_null("InputBuffer")
	if _input_buffer:
		_input_buffer.setup(self)
	var movement: Node = get_node_or_null("MovementComponent")
	if movement and movement.has_method("setup"):
		movement.setup(self)
	add_to_group("player")

func _set_collision_layers() -> void:
	collision_layer = 1
	collision_mask = 70



func _physics_process(delta: float) -> void:
	_apply_movement_physics(delta)
	if _input_buffer:
		_input_buffer.process_buffer(delta)

func _apply_movement_physics(delta: float) -> void:
	if _fsm:
		_fsm.physics_update(delta)
	move_and_slide()
	_clamp_to_screen()

func _clamp_to_screen() -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	var half_width: float = 16.0
	var half_height: float = 26.0
	if _collision_shape and _collision_shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = _collision_shape.shape
		half_width = rect.size.x * 0.5
		half_height = rect.size.y * 0.5
	global_position.x = clampf(global_position.x, half_width, screen_size.x - half_width)
	global_position.y = clampf(global_position.y, half_height, screen_size.y - half_height)

func _try_execute_command(cmd: StringName) -> bool:
	return _fsm.execute_command(cmd)

func play_animation(anim_name: StringName) -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(String(anim_name)):
		_sprite.play(anim_name)

func get_sprite() -> AnimatedSprite2D:
	return _sprite

const MELEE_HITBOX: PackedScene = preload("res://scenes/player/player_hitbox.tscn")

func spawn_hitbox() -> void:
	var hitbox: Hitbox = MELEE_HITBOX.instantiate() as Hitbox
	if not hitbox:
		return
	hitbox.position = Vector2(absf(attack_offset.x) * signf(_facing.x), attack_offset.y)
	hitbox.damage = 1
	hitbox.active_duration = hitbox_lifetime
	add_child(hitbox)
	hitbox.enable_for_duration()
	var vfx := _get_vfx()
	if vfx:
		vfx.trigger_camera_shake(2.0, 0.08)
	
	var tree: SceneTree = get_tree()
	if tree:
		var remove_timer: SceneTreeTimer = tree.create_timer(hitbox_lifetime + 0.05)
		remove_timer.timeout.connect(hitbox.queue_free)

func spawn_arrow() -> void:
	var arrow_scene: PackedScene = preload("res://scenes/player/arrow_projectile.tscn")
	if arrow_scene:
		var arrow: Node = arrow_scene.instantiate()
		get_parent().add_child(arrow)
		var marker: Node2D = get_node_or_null("ArrowSpawnMarker")
		if marker:
			arrow.global_position = marker.global_position
		else:
			arrow.global_position = global_position + Vector2(_facing.x * 30, -15)
		if arrow.has_method("initialize"):
			arrow.initialize(_facing, form_id)

func jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity



func _on_health_depleted() -> void:
	if _fsm:
		_fsm.force_state(PlayerRuntimeFsm.PlayerStates.DEAD, &"health_depleted")
	else:
		play_death_animation()
		lock_guardian()

func play_death_animation() -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("dead"):
		_sprite.play("dead")

func lock_guardian() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("lock_guardian"):
		game_manager.lock_guardian(form_id)
	_request_run_reset()

func _request_run_reset() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("request_timeline_reset"):
		await get_tree().create_timer(1.2).timeout
		game_manager.request_timeline_reset(&"player_death")

func take_damage(amount: int) -> void:
	_health_component.apply_damage(amount)


func _get_form_max_health() -> int:
	return 1


func _configure_hurtbox() -> void:
	if _hurtbox_component:
		_hurtbox_component.damage_source_groups = [&"enemy_attack", &"projectile"]
		_hurtbox_component.invulnerability_duration = 0.5
		if not _hurtbox_component.hurtbox_hit.is_connected(_on_hurtbox_hit):
			_hurtbox_component.hurtbox_hit.connect(_on_hurtbox_hit)


func _on_hurtbox_hit(_source: Node, hit_position: Vector2) -> void:
	if not can_process_combat():
		return
	var knockback_dir: float = signf(global_position.x - hit_position.x) if hit_position.x != global_position.x else _facing.x
	velocity.x = knockback_dir * 380.0
	velocity.y = -100.0
	_health_component.apply_damage(1)


func is_game_over_state() -> bool:
	if _fsm:
		var state = _fsm.get_state()
		return state == PlayerRuntimeFsm.PlayerStates.DEAD
	return false

func can_process_combat() -> bool:
	if _fsm:
		var state = _fsm.get_state()
		return state != PlayerRuntimeFsm.PlayerStates.DEAD and state != PlayerRuntimeFsm.PlayerStates.STUNNED
	return true

func set_sprite_facing(facing_left: bool) -> void:
	_facing_left = facing_left
	_facing = Vector2.LEFT if facing_left else Vector2.RIGHT
	if _sprite:
		_sprite.flip_h = facing_left

func is_special_state() -> bool:
	if _fsm:
		return _fsm.get_state() == PlayerRuntimeFsm.PlayerStates.SPECIAL
	return false

func swap_to_next_form() -> void:
	if is_game_over_state() or not form_manager:
		return
	form_manager.swap_to_next(self)

func swap_to_prev_form() -> void:
	if is_game_over_state() or not form_manager:
		return
	form_manager.swap_to_prev(self)

func spawn_spear_lunge() -> void:
	var hitbox: Hitbox = MELEE_HITBOX.instantiate() as Hitbox
	if not hitbox:
		return
	hitbox.position = Vector2(50.0 * signf(_facing.x), -5.0)
	hitbox.damage = 2
	hitbox.active_duration = 0.35
	add_child(hitbox)
	hitbox.enable_for_duration()
	var tree: SceneTree = get_tree()
	if tree:
		var remove_timer: SceneTreeTimer = tree.create_timer(0.4)
		remove_timer.timeout.connect(hitbox.queue_free)

func _get_vfx() -> PlayerVFXComponent:
	return get_node_or_null("VFXComponent") as PlayerVFXComponent


func enter_idle() -> void:
	if _fsm:
		_fsm._state = PlayerRuntimeFsm.PlayerStates.IDLE
		var idle_state: PlayerStateNode = _fsm._states.get(PlayerRuntimeFsm.PlayerStates.IDLE)
		if idle_state:
			idle_state.enter(-1)

func is_facing_left() -> bool:
	return _facing_left

func get_facing_direction() -> Vector2:
	return _facing

func set_facing(left: bool) -> void:
	_facing_left = left
	_facing = Vector2.LEFT if left else Vector2.RIGHT
	if _sprite:
		_sprite.flip_h = left


# UNUSED_SIGNAL warnings for form_changed/form_locked are false positives.
# Both are connected dynamically in player_state_tracker.gd
