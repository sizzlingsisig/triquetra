extends CharacterBody2D
class_name PlayerController

@export var form_id: StringName = &"Sword"
@export var move_speed: float = 180.0
@export var jump_velocity: float = -350.0
@export var gravity: float = 980.0
@export var max_fall_speed: float = 1200.0
@export var attack_offset: Vector2 = Vector2(24, -10)
@export var hitbox_lifetime: float = 0.15

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _movement: PlayerMovementComponent = $MovementComponent
var _input_buffer: Node

func get_input_buffer() -> Node:
	return _input_buffer
@onready var _fsm = $Fsm

var _facing: Vector2 = Vector2.RIGHT
var _stats: Stats
var _invulnerable_remaining: float = 1.0

var _facing_left: bool = false

## Emitted when the active guardian form changes.
signal form_changed(form_id: StringName)
## Emitted when a guardian form becomes permanently locked (death).
signal form_locked(form_id: StringName)

var runtime_fsm:
	get: return _fsm

var stats:
	get: return _stats

func _ready() -> void:
	_stats = Stats.new()
	_stats.health_depleted.connect(_on_health_depleted)
	_stats.health_changed.connect(_on_health_changed)
	_set_collision_layers()
	_connect_event_bus()

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

	if _hurtbox:
		_hurtbox.faction = Stats.Faction.PLAYER

func _connect_event_bus() -> void:
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("enemy_hit_player"):
		event_bus.enemy_hit_player.connect(_on_enemy_hit_player)

func _physics_process(delta: float) -> void:
	if _movement:
		_apply_movement_physics(delta)
	else:
		_apply_simple_physics(delta)
	
	if _input_buffer:
		_input_buffer.process_buffer(delta)

func _apply_movement_physics(delta: float) -> void:
	if _fsm:
		_fsm.physics_update(delta)
	move_and_slide()

func _apply_simple_physics(delta: float) -> void:
	if _fsm:
		_fsm.physics_update(delta)
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
	else:
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
			play_animation("jump")
		var direction := Input.get_axis("move_left", "move_right")
		if direction != 0.0:
			velocity.x = direction * move_speed
			_facing = Vector2(direction, 0).normalized()
			if _sprite:
				_sprite.flip_h = direction < 0
			if is_on_floor():
				play_animation("run")
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			if is_on_floor() and absf(velocity.x) <= 4.0:
				play_animation("idle")
		move_and_slide()
func _unhandled_input(_event: InputEvent) -> void:
	pass

func _try_execute_command(cmd: StringName) -> bool:
	return _fsm.execute_command(cmd)

func play_animation(name: StringName) -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(String(name)):
		_sprite.play(name)

func get_sprite() -> AnimatedSprite2D:
	return _sprite

func spawn_hitbox() -> void:
	var hitlog := HitLog.new()
	var hitbox := Hitbox.new()
	hitbox.setup(_stats.current_attack, form_id, hitlog, hitbox_lifetime)
	hitbox.global_position = global_position + (_facing * attack_offset)
	add_child(hitbox)

func spawn_arrow() -> void:
	var arrow_scene: PackedScene = preload("res://scenes/player/arrow_projectile.tscn")
	if arrow_scene:
		var arrow: Node = arrow_scene.instantiate()
		get_parent().add_child(arrow)
		arrow.global_position = global_position + (_facing * Vector2(30, -15))
		if arrow.has_method("initialize"):
			arrow.initialize(_facing, form_id)

func jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity

func _on_enemy_hit_player(hit_position: Vector2, _camera_intensity: float, _camera_duration: float) -> void:
	if _invulnerable_remaining > 0.0:
		return

	var knockback_force: float = 380.0
	var knockback_dir: float = signf(global_position.x - hit_position.x) if hit_position.x != global_position.x else _facing.x
	velocity.x = knockback_dir * knockback_force
	velocity.y = -100.0

	_stats.take_damage(1)

func _on_health_depleted() -> void:
	if _fsm:
		_fsm.force_state(PlayerRuntimeFsm.PlayerStateNode.DEAD, &"health_depleted")
	else:
		play_death_animation()
		lock_guardian()

func _on_health_changed(_new_health: int, _max_health: int) -> void:
	pass

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
	_stats.take_damage(amount)

func _is_game_over_state() -> bool:
	if _fsm:
		var state = _fsm.get_state()
		return state == PlayerRuntimeFsm.PlayerStateNode.DEAD
	return false

func _can_process_combat() -> bool:
	if _fsm:
		var state = _fsm.get_state()
		return state != PlayerRuntimeFsm.PlayerStateNode.DEAD and state != PlayerRuntimeFsm.PlayerStateNode.STUNNED
	return true

func _set_sprite_facing(facing_left: bool) -> void:
	_facing_left = facing_left
	if _sprite:
		_sprite.flip_h = facing_left

func _is_special_state() -> bool:
	if _fsm:
		return _fsm.get_state() == PlayerRuntimeFsm.PlayerStateNode.SPECIAL
	return false

func swap_to_next_form() -> void:
	if _fsm and (_fsm.get_state() == PlayerRuntimeFsm.PlayerStateNode.DEAD or _fsm.get_state() == PlayerRuntimeFsm.PlayerStateNode.STUNNED):
		return
	push_warning("swap_to_next_form() called but form swapping is not yet implemented")

func swap_to_prev_form() -> void:
	if _fsm and (_fsm.get_state() == PlayerRuntimeFsm.PlayerStateNode.DEAD or _fsm.get_state() == PlayerRuntimeFsm.PlayerStateNode.STUNNED):
		return
	push_warning("swap_to_prev_form() called but form swapping is not yet implemented")
