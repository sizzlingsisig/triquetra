extends CharacterBody2D

@export var is_shielded: bool = false
@export var is_arrow_skeleton: bool = false
@export var enable_knight_attacks: bool = false
@export var attack_interval: float = 1.6
@export var attack_active_time: float = 0.22
@export var arrow_speed: float = 420.0
@export var arrow_lifetime: float = 1.2

const ATTACK_ANIMATIONS: Array[StringName] = [
	&"knight_attack1",
	&"knight_attack2",
	&"knight_attack3"
]

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _enemy_attack_area: Area2D = $EnemyAttackArea
@onready var _attack_timer: Timer = $AttackTimer
@onready var _projectile_spawn: Node2D = get_node_or_null("ProjectileSpawn")

var _attack_index: int = 0
@export var max_health: int = 2
var _current_health: int = 2
var _attack_window_active: bool = false

func _ready() -> void:
	if is_in_group("arrow_skeleton"):
		is_arrow_skeleton = true
	_current_health = max(max_health, 1)

	if _attack_timer:
		_attack_timer.wait_time = max(attack_interval, 0.2)
		if enable_knight_attacks and _attack_timer.is_stopped():
			_attack_timer.start()
		if not enable_knight_attacks:
			_attack_timer.stop()

	if _enemy_attack_area:
		_enemy_attack_area.monitoring = false
		_enemy_attack_area.monitorable = enable_knight_attacks

	_play_idle()

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

	if is_shielded:
		match attacker_form:
			&"Sword":
				damage = 1
			&"Spear":
				damage = _current_health
			&"Bow":
				damage = 1
			_:
				damage = 1
	else:
		damage = 1

	if damage <= 0:
		_play_defend()
		return

	_current_health = max(_current_health - damage, 0)
	if _current_health <= 0:
		_die()
		return

	_play_hurt()

	if _attack_window_active:
		_counter_attack_player()

func _is_player_attack(node: Node) -> bool:
	if not node:
		return false
	return node.is_in_group("attack") or node.is_in_group("projectile")

func _on_attack_timer_timeout() -> void:
	if not enable_knight_attacks:
		return

	_play_next_attack_animation()
	_spawn_attack_fx()
	if is_arrow_skeleton:
		_spawn_arrow_projectile()
		return
	_activate_attack_area_window()

func _on_enemy_attack_area_body_entered(body: Node) -> void:
	if not _is_player_target(body):
		return

	_spawn_hit_impact_fx(body.global_position)
	if body.has_method("shake_camera"):
		body.shake_camera(4.0, 0.08)
	if body.has_method("receive_enemy_hit"):
		body.receive_enemy_hit()

func _play_idle() -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"knight_idle"):
		_sprite.play(&"knight_idle")

func _play_defend() -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"knight_defend"):
		_sprite.play(&"knight_defend")
	_run_after(0.22, _play_idle)

func _play_hurt() -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"knight_hurt"):
		_sprite.play(&"knight_hurt")
	_run_after(0.18, _play_idle)

func _play_next_attack_animation() -> void:
	if not _sprite or not _sprite.sprite_frames:
		return

	for _attempt in range(ATTACK_ANIMATIONS.size()):
		var animation_name: StringName = ATTACK_ANIMATIONS[_attack_index]
		_attack_index = (_attack_index + 1) % ATTACK_ANIMATIONS.size()
		if _sprite.sprite_frames.has_animation(animation_name):
			_sprite.play(animation_name)
			_run_after(0.35, _play_idle)
			return

func _activate_attack_area_window() -> void:
	if not _enemy_attack_area:
		return

	_attack_window_active = true
	_enemy_attack_area.monitoring = true
	_run_after(max(attack_active_time, 0.05), _on_attack_area_window_timeout)

func _spawn_guard_fx() -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.14
	particles.explosiveness = 1.0
	particles.spread = 55.0
	particles.direction = Vector2(0.0, -1.0)
	particles.initial_velocity_min = 65.0
	particles.initial_velocity_max = 120.0
	particles.modulate = Color(0.8, 0.92, 1.0, 0.85)
	particles.position = Vector2(0.0, -12.0)
	add_child(particles)
	particles.emitting = true
	_queue_free_after(particles, particles.lifetime + 0.2)

func _spawn_attack_fx() -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = 14
	particles.lifetime = 0.16
	particles.explosiveness = 1.0
	particles.spread = 30.0
	particles.direction = Vector2(1.0 if not _sprite.flip_h else -1.0, -0.1)
	particles.initial_velocity_min = 95.0
	particles.initial_velocity_max = 165.0
	particles.modulate = Color(1.0, 0.72, 0.55, 0.8)
	particles.position = Vector2(-18.0 if _sprite.flip_h else 18.0, -10.0)
	add_child(particles)
	particles.emitting = true
	_queue_free_after(particles, particles.lifetime + 0.2)

func _spawn_hit_impact_fx(hit_position: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = 12
	particles.lifetime = 0.12
	particles.explosiveness = 1.0
	particles.spread = 70.0
	particles.direction = Vector2(0.0, -1.0)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 145.0
	particles.modulate = Color(1.0, 0.54, 0.42, 0.85)
	particles.global_position = hit_position

	var host: Node = get_parent()
	if host:
		host.add_child(particles)
	else:
		add_child(particles)
	particles.emitting = true
	_queue_free_after(particles, particles.lifetime + 0.2)

func _die() -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"knight_dead"):
		_sprite.play(&"knight_dead")
	if _enemy_attack_area:
		_enemy_attack_area.monitoring = false
		_enemy_attack_area.monitorable = false
	if _attack_timer:
		_attack_timer.stop()
	_run_after(0.28, _queue_free_self)

func _counter_attack_player() -> void:
	var root_parent: Node = get_parent()
	if not root_parent:
		return
	var player = root_parent.get_node_or_null("Player")
	if player and player.has_method("receive_enemy_hit"):
		player.receive_enemy_hit()
		_spawn_hit_impact_fx(player.global_position)
		if player.has_method("shake_camera"):
			player.shake_camera(5.0, 0.1)

func _spawn_arrow_projectile() -> void:
	var arrow := Area2D.new()
	arrow.name = "ArrowProjectile"
	arrow.collision_layer = 32
	arrow.collision_mask = 1
	arrow.monitoring = true
	arrow.monitorable = true
	arrow.add_to_group("projectile")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18.0, 5.0)
	shape.shape = rect
	arrow.add_child(shape)

	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([
		Vector2(-9.0, -2.5),
		Vector2(7.0, -2.5),
		Vector2(10.0, 0.0),
		Vector2(7.0, 2.5),
		Vector2(-9.0, 2.5)
	])
	marker.color = Color(0.9, 0.85, 0.72, 0.95)
	arrow.add_child(marker)

	var direction: Vector2 = Vector2.LEFT if _sprite.flip_h else Vector2.RIGHT
	arrow.rotation = direction.angle()
	arrow.global_position = _get_arrow_spawn_position(direction)

	var host := get_parent()
	if host:
		host.add_child(arrow)
	else:
		add_child(arrow)

	arrow.body_entered.connect(_on_arrow_body_entered.bind(weakref(arrow)))

	var travel_distance = arrow_speed * max(arrow_lifetime, 0.2)
	var target = arrow.global_position + (direction * travel_distance)
	var travel_time = travel_distance / max(arrow_speed, 1.0)

	var tween: Tween = arrow.create_tween()
	tween.tween_property(arrow, "global_position", target, travel_time)
	tween.finished.connect(_queue_free_weak.bind(weakref(arrow)))

func _get_arrow_spawn_position(direction: Vector2) -> Vector2:
	# Keep enemy arrow muzzle placement consistent with player bow spawn offsets.
	if _projectile_spawn:
		return _projectile_spawn.global_position
	if _sprite:
		return _sprite.global_position + Vector2(direction.x * 20.0, -8.0)
	return global_position + Vector2(direction.x * 20.0, -8.0)

func _on_attack_area_window_timeout() -> void:
	if _enemy_attack_area:
		_enemy_attack_area.monitoring = false
	_attack_window_active = false

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

func _queue_free_after(target: Node, delay_seconds: float) -> void:
	if not target:
		return
	_run_after(delay_seconds, _queue_free_weak.bind(weakref(target)))

func _queue_free_weak(target_ref: WeakRef) -> void:
	var target: Object = target_ref.get_ref()
	if target and is_instance_valid(target) and target is Node:
		(target as Node).queue_free()

func _queue_free_self() -> void:
	if is_instance_valid(self):
		queue_free()

func _on_arrow_body_entered(body: Node, arrow_ref: WeakRef) -> void:
	if not _is_player_target(body):
		return

	_spawn_hit_impact_fx(body.global_position)
	if body.has_method("shake_camera"):
		body.shake_camera(5.0, 0.1)
	if body.has_method("receive_enemy_hit"):
		body.receive_enemy_hit()

	var arrow: Area2D = arrow_ref.get_ref() as Area2D
	if arrow and is_instance_valid(arrow):
		arrow.queue_free()
