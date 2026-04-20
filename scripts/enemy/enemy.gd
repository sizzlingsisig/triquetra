extends CharacterBody2D
class_name Enemy

@export var enemy_data: EnemyData

@export var is_shielded: bool = false
@export var is_arrow_skeleton: bool = false
@export var enable_knight_attacks: bool = false
@export var attack_interval: float = 1.6
@export var attack_telegraph_time: float = 0.08
@export var attack_active_time: float = 0.22
@export var arrow_speed: float = 420.0
@export var arrow_lifetime: float = 1.2
@export var max_health: int = 2
@export var enable_chase: bool = true
@export var chase_speed: float = 90.0
@export var chase_acceleration: float = 480.0
@export var chase_stop_distance: float = 28.0
@export var match_player_speed: bool = true
@export var enable_patrol: bool = true
@export var patrol_distance: float = 120.0
@export var patrol_speed: float = 60.0
@export var patrol_acceleration: float = 300.0
@export var patrol_arrive_threshold: float = 8.0
@export var patrol_wait_time: float = 0.35
@export var attack_range: float = 40.0
@export var post_attack_patrol_hold_time: float = 0.55
@export var sprite_faces_left_when_not_flipped: bool = false
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 1200.0
@export var target_player_path: NodePath
@export var vision_range: float = 190.0
@export var vision_y_offset: float = 0.0
@export var target_retry_delay: float = 0.4

const DEFAULT_ATTACK_ANIMATIONS: Array[StringName] = [
	&"knight_attack1",
	&"knight_attack2",
	&"knight_attack3",
]

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _vision_raycast: RayCast2D = get_node_or_null("AnimatedSprite2D/RayCast2D") as RayCast2D
@onready var _enemy_attack_area: Area2D = $EnemyAttackArea
@onready var _attack_timer: Timer = $AttackTimer
@onready var _projectile_spawn: Node2D = get_node_or_null("ProjectileSpawn") as Node2D
@onready var _health_component: EnemyHealthComponent = get_node_or_null("HealthComponent") as EnemyHealthComponent
@onready var _combat_component: EnemyCombatComponent = get_node_or_null("CombatComponent") as EnemyCombatComponent
@onready var _animation_component: EnemyAnimationComponent = get_node_or_null("AnimationComponent") as EnemyAnimationComponent
@onready var _fx_component: EnemyFxComponent = get_node_or_null("FxComponent") as EnemyFxComponent
@onready var _target_component: EnemyTargetComponent = get_node_or_null("TargetComponent") as EnemyTargetComponent
@onready var _movement_component: EnemyMovementComponent = get_node_or_null("MovementComponent") as EnemyMovementComponent
@onready var _projectile_component: EnemyProjectileComponent = get_node_or_null("ProjectileComponent") as EnemyProjectileComponent
@onready var _event_component: EnemyEventComponent = get_node_or_null("EventComponent") as EnemyEventComponent
@onready var _runtime_fsm: EnemyRuntimeFsm = get_node_or_null("RuntimeFsm") as EnemyRuntimeFsm

var _attack_animations: Array[StringName] = []
var _melee_hit_applied_this_window: bool = false

func _ready() -> void:
	_ensure_components()
	_apply_enemy_data()

	if is_in_group("arrow_skeleton"):
		is_arrow_skeleton = true

	if _health_component:
		if not _health_component.died.is_connected(_on_health_died):
			_health_component.died.connect(_on_health_died)
		_health_component.setup(max_health)

	if _combat_component:
		if not _combat_component.counter_attack_triggered.is_connected(_counter_attack_player):
			_combat_component.counter_attack_triggered.connect(_counter_attack_player)
		_combat_component.setup(self, _enemy_attack_area, _attack_timer, attack_interval, enable_knight_attacks)

	if _animation_component:
		_animation_component.setup(_sprite)
	if _fx_component:
		_fx_component.setup(self, _sprite)
	if _movement_component:
		_movement_component.setup(_sprite, _enemy_attack_area, sprite_faces_left_when_not_flipped)
		if not _movement_component.facing_changed.is_connected(_on_movement_facing_changed):
			_movement_component.facing_changed.connect(_on_movement_facing_changed)
	if _target_component:
		_target_component.setup(
			self,
			_vision_raycast,
			target_player_path,
			vision_range,
			vision_y_offset,
			target_retry_delay,
			Callable(self, "_is_player_target")
		)
	if _projectile_component:
		_projectile_component.setup(self, _sprite, _projectile_spawn)
		if not _projectile_component.projectile_hit_target.is_connected(_on_arrow_projectile_hit):
			_projectile_component.projectile_hit_target.connect(_on_arrow_projectile_hit)
	if _event_component:
		_event_component.setup()
	if _runtime_fsm == null:
		_runtime_fsm = EnemyRuntimeFsm.new()
		_runtime_fsm.name = "RuntimeFsm"
		add_child(_runtime_fsm)
	_runtime_fsm.setup(self, _combat_component, _animation_component, _fx_component)
	_sync_speed_with_player()
	_update_vision_raycast_target()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta
		velocity.y = minf(velocity.y, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if _target_component:
		_target_component.physics_update()
	_sync_speed_with_player()
	_update_vision_raycast_target()
	if _runtime_fsm:
		_runtime_fsm.physics_update(delta)
	move_and_slide()

func _ensure_components() -> void:
	if _health_component == null:
		_health_component = EnemyHealthComponent.new()
		_health_component.name = "HealthComponent"
		add_child(_health_component)

	if _combat_component == null:
		_combat_component = EnemyCombatComponent.new()
		_combat_component.name = "CombatComponent"
		add_child(_combat_component)

	if _animation_component == null:
		_animation_component = EnemyAnimationComponent.new()
		_animation_component.name = "AnimationComponent"
		add_child(_animation_component)

	if _fx_component == null:
		_fx_component = EnemyFxComponent.new()
		_fx_component.name = "FxComponent"
		add_child(_fx_component)

	if _target_component == null:
		_target_component = EnemyTargetComponent.new()
		_target_component.name = "TargetComponent"
		add_child(_target_component)

	if _movement_component == null:
		_movement_component = EnemyMovementComponent.new()
		_movement_component.name = "MovementComponent"
		add_child(_movement_component)

	if _projectile_component == null:
		_projectile_component = EnemyProjectileComponent.new()
		_projectile_component.name = "ProjectileComponent"
		add_child(_projectile_component)

	if _event_component == null:
		_event_component = EnemyEventComponent.new()
		_event_component.name = "EventComponent"
		add_child(_event_component)

	if _runtime_fsm == null:
		_runtime_fsm = EnemyRuntimeFsm.new()
		_runtime_fsm.name = "RuntimeFsm"
		add_child(_runtime_fsm)

func _apply_enemy_data() -> void:
	if enemy_data:
		is_shielded = enemy_data.is_shielded
		is_arrow_skeleton = enemy_data.is_arrow_skeleton
		# Keep explicit scene-level enable flag if set, while still allowing data-driven enable.
		enable_knight_attacks = enemy_data.enable_attacks or enable_knight_attacks
		max_health = enemy_data.max_health
		attack_interval = enemy_data.attack_interval
		attack_active_time = enemy_data.attack_active_time
		arrow_speed = enemy_data.arrow_speed
		arrow_lifetime = enemy_data.arrow_lifetime
		attack_range = enemy_data.attack_range
		_attack_animations = enemy_data.attack_animations.duplicate()
	else:
		_attack_animations = DEFAULT_ATTACK_ANIMATIONS.duplicate()

	if _attack_animations.is_empty():
		_attack_animations = DEFAULT_ATTACK_ANIMATIONS.duplicate()

func _on_attack_hitbox_body_entered(body: Node) -> void:
	if not _is_player_attack(body):
		return

	var attack_form: StringName = &"Sword"
	if body and body.is_in_group("projectile"):
		attack_form = &"Bow"
	# fallback: melee hits are assumed Sword if no explicit form
	receive_player_hit(attack_form)

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if not _is_player_attack(area):
		return

	var attack_form: StringName = &"Sword"
	if area and area.is_in_group("projectile"):
		attack_form = &"Bow"
	receive_player_hit(attack_form)

func receive_player_hit(attacker_form: StringName = &"Sword") -> void:
	var damage: int = 0
	var current_health: int = _health_component.get_current_health() if _health_component else max_health

	if is_shielded:
		match attacker_form:
			&"Sword":
				damage = 1
			&"Spear":
				damage = current_health
			&"Bow":
				damage = 1
			_:
				damage = 1
	else:
		damage = 1

	if damage <= 0:
		if _runtime_fsm:
			_runtime_fsm.on_damage_blocked(_get_defend_recover_time())
		return

	_play_enemy_hit_fx()
	if _event_component:
		_event_component.emit_hit_stop(0.05)

	var new_health: int = current_health
	if _health_component:
		new_health = _health_component.apply_damage(damage)
	else:
		new_health = max(current_health - damage, 0)

	if new_health <= 0:
		return

	if _runtime_fsm:
		_runtime_fsm.on_damage_hurt(_get_hurt_recover_time())

	if _combat_component and _combat_component.is_attack_window_active():
		if _runtime_fsm:
			_runtime_fsm.on_counter_attack()
		_combat_component.trigger_counter_attack()

func _play_enemy_hit_fx() -> void:
	var hit_position: Vector2 = _get_combat_origin_position(self)
	if _fx_component:
		_fx_component.spawn_hit_impact_fx(hit_position)
	if _sprite == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var original_modulate: Color = _sprite.modulate
	_sprite.modulate = Color(1.0, 0.65, 0.65, 1.0)
	var timer: SceneTreeTimer = tree.create_timer(0.06)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_sprite):
			_sprite.modulate = original_modulate
	)

func _is_player_attack(node: Node) -> bool:
	if not node:
		return false
	return node.is_in_group("attack") or node.is_in_group("projectile")

func _on_attack_timer_timeout() -> void:
	if not enable_knight_attacks:
		return
	if _runtime_fsm:
		_runtime_fsm.request_attack()

func _on_enemy_attack_area_body_entered(body: Node) -> void:
	if not _is_player_target(body):
		return
	_emit_melee_hit_once(body.global_position)

func _play_next_attack_animation() -> void:
	if _animation_component:
		if _animation_component.play_next_attack_animation(_attack_animations):
			return
	if _sprite == null or _sprite.sprite_frames == null or _attack_animations.is_empty():
		return
	for animation_name: StringName in _attack_animations:
		if _sprite.sprite_frames.has_animation(animation_name):
			_sprite.play(animation_name)
			return

func _activate_attack_area_window() -> void:
	if _combat_component == null:
		return
	_melee_hit_applied_this_window = false
	_combat_component.open_attack_window(attack_active_time)
	# Fallback for cases where monitoring is enabled while already overlapping the player.
	var tree: SceneTree = get_tree()
	if tree:
		tree.physics_frame.connect(_apply_attack_overlap_fallback, CONNECT_ONE_SHOT)
	else:
		call_deferred("_apply_attack_overlap_fallback")

func _apply_attack_overlap_fallback() -> void:
	if _enemy_attack_area == null:
		_apply_direct_target_melee_fallback()
		return
	for body: Node2D in _enemy_attack_area.get_overlapping_bodies():
		if _is_player_target(body):
			_emit_melee_hit_once(body.global_position)
			return
	_apply_direct_target_melee_fallback()

func _apply_direct_target_melee_fallback() -> void:
	var target: Node2D = _get_detected_player()
	if target == null:
		target = _get_target_player()
	if target == null:
		return
	if not _is_player_target(target):
		return
	var self_x: float = _get_combat_origin_x(self)
	var target_x: float = _get_combat_origin_x(target)
	var distance_x: float = absf(target_x - self_x)
	var effective_melee_range: float = maxf(attack_range, chase_stop_distance)
	if distance_x > effective_melee_range:
		return
	# Keep a vertical sanity limit to avoid hitting targets on distant floors.
	var self_y: float = _get_combat_origin_y(self)
	var target_y: float = _get_combat_origin_y(target)
	var distance_y: float = absf(target_y - self_y)
	if distance_y > 96.0:
		return
	_emit_melee_hit_once(target.global_position)

func _get_combat_origin_x(node: Node2D) -> float:
	if node == null:
		return 0.0
	var shape: CollisionShape2D = node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and not shape.disabled:
		return shape.global_position.x
	return node.global_position.x

func _get_combat_origin_position(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO
	var shape: CollisionShape2D = node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and not shape.disabled:
		return shape.global_position
	return node.global_position

func _get_combat_origin_y(node: Node2D) -> float:
	if node == null:
		return 0.0
	var shape: CollisionShape2D = node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and not shape.disabled:
		return shape.global_position.y
	return node.global_position.y

func _emit_melee_hit_once(hit_position: Vector2) -> void:
	if _melee_hit_applied_this_window:
		return
	_melee_hit_applied_this_window = true
	if _fx_component:
		_fx_component.spawn_hit_impact_fx(hit_position)
	_emit_player_hit_event(hit_position, 4.0, 0.08)

func _die() -> void:
	if _combat_component:
		_combat_component.set_attack_enabled(false)
	else:
		if _enemy_attack_area:
			_enemy_attack_area.monitoring = false
			_enemy_attack_area.monitorable = false
		if _attack_timer:
			_attack_timer.stop()
	_run_after(_get_death_cleanup_delay(), _queue_free_self)

func _on_health_died() -> void:
	if _runtime_fsm:
		_runtime_fsm.on_died()
	_die()

func _counter_attack_player() -> void:
	var hit_position: Vector2 = global_position
	if _fx_component:
		_fx_component.spawn_hit_impact_fx(hit_position)
	_emit_player_hit_event(hit_position, 5.0, 0.1)

func _spawn_arrow_projectile() -> void:
	if _projectile_component == null:
		return
	_projectile_component.spawn_arrow(_is_facing_left(), arrow_speed, arrow_lifetime)

func _on_attack_area_window_timeout() -> void:
	if _combat_component:
		_combat_component.close_attack_window()

func _is_player_target(node: Node) -> bool:
	if not node:
		return false
	if node.is_in_group("player"):
		return true
	return node.has_method("receive_enemy_hit")

func _run_after(delay_seconds: float, callback: Callable) -> void:
	if delay_seconds < 0.0:
		delay_seconds = 0.0
	var tree: SceneTree = get_tree()
	if not tree:
		return
	var timer: SceneTreeTimer = tree.create_timer(delay_seconds)
	timer.timeout.connect(callback)

func _queue_free_self() -> void:
	if is_instance_valid(self):
		queue_free()

func _update_vision_raycast_target() -> void:
	if _target_component:
		_target_component.set_facing_left(_is_facing_left())

func _has_line_of_sight_to_player() -> bool:
	if _target_component == null:
		return false
	return _target_component.has_line_of_sight()

func _get_detected_player() -> Node2D:
	if _target_component == null:
		return null
	return _target_component.get_detected_player()

func _get_target_player() -> Node2D:
	if _target_component == null:
		return null
	return _target_component.get_target_player()

func _set_enemy_facing_from_direction(direction: float) -> void:
	if _movement_component:
		_movement_component.set_facing_from_direction(direction)
	_update_vision_raycast_target()

func _sync_speed_with_player() -> void:
	if not match_player_speed or _movement_component == null or _target_component == null:
		return
	var target_player: Node2D = _target_component.get_target_player()
	if not is_instance_valid(target_player):
		return
	var synced_speed: float = _movement_component.try_get_player_move_speed(target_player)
	if synced_speed > 0.0:
		chase_speed = synced_speed
		patrol_speed = synced_speed

func _is_facing_left() -> bool:
	if _movement_component == null:
		return false
	return _movement_component.is_facing_left()

func _on_arrow_projectile_hit(body: Node, hit_position: Vector2) -> void:
	if not _is_player_target(body):
		return

	if _fx_component:
		_fx_component.spawn_hit_impact_fx(hit_position)
	_emit_player_hit_event(hit_position, 5.0, 0.1)

func _emit_player_hit_event(hit_position: Vector2, camera_intensity: float, camera_duration: float) -> void:
	if _event_component:
		_event_component.emit_player_hit(hit_position, camera_intensity, camera_duration)

func _on_movement_facing_changed(_is_left: bool) -> void:
	_update_vision_raycast_target()

func _get_defend_recover_time() -> float:
	return enemy_data.defend_recover_time if enemy_data else 0.22

func _get_hurt_recover_time() -> float:
	return enemy_data.hurt_recover_time if enemy_data else 0.18

func _get_attack_recover_time() -> float:
	return enemy_data.attack_recover_time if enemy_data else 0.35

func _get_death_cleanup_delay() -> float:
	return enemy_data.death_cleanup_delay if enemy_data else 0.28
