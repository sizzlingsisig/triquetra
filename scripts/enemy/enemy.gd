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

func _ready() -> void:
	if is_in_group("arrow_skeleton"):
		is_arrow_skeleton = true

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

	receive_player_hit()

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if not _is_player_attack(area):
		return

	receive_player_hit()

func receive_player_hit() -> void:
	_play_hurt()

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
	if not body:
		return
	if body.name != "Player":
		return

	_spawn_hit_impact_fx(body.global_position)
	if body.has_method("shake_camera"):
		body.shake_camera(4.0, 0.08)

func _play_idle() -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"knight_idle"):
		_sprite.play(&"knight_idle")

func _play_defend() -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"knight_defend"):
		_sprite.play(&"knight_defend")

	var timer: SceneTreeTimer = get_tree().create_timer(0.22)
	timer.timeout.connect(func() -> void:
		_play_idle()
	)

func _play_hurt() -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"knight_hurt"):
		_sprite.play(&"knight_hurt")

	var timer: SceneTreeTimer = get_tree().create_timer(0.18)
	timer.timeout.connect(func() -> void:
		_play_idle()
	)

func _play_next_attack_animation() -> void:
	if not _sprite or not _sprite.sprite_frames:
		return

	for _attempt in range(ATTACK_ANIMATIONS.size()):
		var animation_name: StringName = ATTACK_ANIMATIONS[_attack_index]
		_attack_index = (_attack_index + 1) % ATTACK_ANIMATIONS.size()
		if _sprite.sprite_frames.has_animation(animation_name):
			_sprite.play(animation_name)
			var timer: SceneTreeTimer = get_tree().create_timer(0.35)
			timer.timeout.connect(func() -> void:
				_play_idle()
			)
			return

func _activate_attack_area_window() -> void:
	if not _enemy_attack_area:
		return

	_enemy_attack_area.monitoring = true
	var timer: SceneTreeTimer = get_tree().create_timer(max(attack_active_time, 0.05))
	timer.timeout.connect(func() -> void:
		if _enemy_attack_area:
			_enemy_attack_area.monitoring = false
	)

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

	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(particles.lifetime + 0.2)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)

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

	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(particles.lifetime + 0.2)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)

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

	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(particles.lifetime + 0.2)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)

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

	var direction := Vector2.LEFT if _sprite.flip_h else Vector2.RIGHT
	arrow.rotation = direction.angle()
	arrow.global_position = _projectile_spawn.global_position if _projectile_spawn else global_position + Vector2(direction.x * 24.0, -8.0)

	var host := get_parent()
	if host:
		host.add_child(arrow)
	else:
		add_child(arrow)

	arrow.body_entered.connect(func(body: Node) -> void:
		if not body:
			return
		if body.name != "Player":
			return
		_spawn_hit_impact_fx(body.global_position)
		if body.has_method("shake_camera"):
			body.shake_camera(5.0, 0.1)
		if is_instance_valid(arrow):
			arrow.queue_free()
	)

	var travel_distance = arrow_speed * max(arrow_lifetime, 0.2)
	var target = arrow.global_position + (direction * travel_distance)
	var travel_time = travel_distance / max(arrow_speed, 1.0)

	var tween: Tween = arrow.create_tween()
	tween.tween_property(arrow, "global_position", target, travel_time)
	tween.finished.connect(func() -> void:
		if is_instance_valid(arrow):
			arrow.queue_free()
	)
