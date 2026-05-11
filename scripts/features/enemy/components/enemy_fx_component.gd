extends Node
class_name EnemyFxComponent

var _owner_node: Node
var _sprite: AnimatedSprite2D

func setup(owner_node: Node, sprite: AnimatedSprite2D) -> void:
	_owner_node = owner_node
	_sprite = sprite

func spawn_guard_fx() -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
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
	if _owner_node:
		_owner_node.add_child(particles)
	particles.emitting = true
	_queue_free_after(particles, particles.lifetime + 0.2)

func spawn_attack_fx() -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = 14
	particles.lifetime = 0.16
	particles.explosiveness = 1.0
	particles.spread = 30.0
	var facing_left: bool = _sprite.flip_h if _sprite else false
	particles.direction = Vector2(1.0 if not facing_left else -1.0, -0.1)
	particles.initial_velocity_min = 95.0
	particles.initial_velocity_max = 165.0
	particles.modulate = Color(1.0, 0.72, 0.55, 0.8)
	particles.position = Vector2(-18.0 if facing_left else 18.0, -10.0)
	if _owner_node:
		_owner_node.add_child(particles)
	particles.emitting = true
	_queue_free_after(particles, particles.lifetime + 0.2)

func spawn_hit_impact_fx(hit_position: Vector2) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
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

	var host: Node = _owner_node.get_parent() if _owner_node else null
	if host:
		host.add_child(particles)
	elif _owner_node:
		_owner_node.add_child(particles)
	particles.emitting = true
	_queue_free_after(particles, particles.lifetime + 0.2)

func _queue_free_after(target: Node, delay_seconds: float) -> void:
	if target == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(max(delay_seconds, 0.0))
	timer.timeout.connect(func() -> void:
		if is_instance_valid(target):
			target.queue_free()
	)
