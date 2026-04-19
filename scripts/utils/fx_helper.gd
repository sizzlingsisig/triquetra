class_name FXHelper

## Centralized utility for spawning particle effects and visual feedback.
## Use this instead of inline particle code to reduce duplication.
## All methods are static - no need to instantiate.

const DEFAULT_PARTICLE_CONFIG: Dictionary = {
	"amount": 10,
	"lifetime": 0.2,
	"explosiveness": 1.0,
	"spread": 45.0,
	"direction": Vector2.UP,
	"vel_min": 50.0,
	"vel_max": 100.0,
	"scale_min": 1.0,
	"scale_max": 2.0,
	"color": Color.WHITE,
	"local_pos": Vector2.ZERO,
	"global_pos": null
}

static func spawn_particles(parent: Node, config: Dictionary = {}) -> void:
	var p: Dictionary = DEFAULT_PARTICLE_CONFIG.duplicate()
	for k in config:
		p[k] = config[k]
	
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = p.amount
	particles.lifetime = p.lifetime
	particles.explosiveness = p.explosiveness
	particles.spread = p.spread
	particles.direction = p.direction
	particles.initial_velocity_min = p.vel_min
	particles.initial_velocity_max = p.vel_max
	particles.scale_amount_min = p.scale_min
	particles.scale_amount_max = p.scale_max
	particles.modulate = p.color
	particles.position = p.local_pos
	
	parent.add_child(particles)
	if p.global_pos != null:
		particles.global_position = p.global_pos
	else:
		particles.global_position = parent.global_position
	
	particles.emitting = true
	
	var timer := parent.get_tree().create_timer(p.lifetime + 0.1)
	timer.timeout.connect(func(): 
		if is_instance_valid(particles):
			particles.queue_free()
	)

static func spawn_hit_fx(parent: Node, position: Vector2, color: Color = Color(1.0, 0.2, 0.2, 0.9)) -> void:
	spawn_particles(parent, {
		"amount": 15,
		"lifetime": 0.2,
		"spread": 180.0,
		"vel_min": 50.0,
		"vel_max": 150.0,
		"scale_min": 2.0,
		"scale_max": 4.0,
		"color": color,
		"global_pos": position
	})

static func spawn_guard_fx(parent: Node, position: Vector2) -> void:
	spawn_particles(parent, {
		"amount": 10,
		"lifetime": 0.14,
		"spread": 55.0,
		"direction": Vector2.UP,
		"vel_min": 65.0,
		"vel_max": 120.0,
		"scale_min": 1.5,
		"scale_max": 3.5,
		"color": Color(0.8, 0.85, 0.95, 0.9),
		"global_pos": position
	})

static func spawn_attack_fx(parent: Node, position: Vector2, direction: Vector2) -> void:
	spawn_particles(parent, {
		"amount": 8,
		"lifetime": 0.15,
		"explosiveness": 0.9,
		"spread": 30.0,
		"direction": direction,
		"vel_min": 100.0,
		"vel_max": 200.0,
		"scale_min": 1.5,
		"scale_max": 3.0,
		"color": Color(0.9, 0.9, 0.9, 0.8),
		"global_pos": position
	})

static func spawn_block_fx(parent: Node, local_pos: Vector2 = Vector2(0, -8)) -> void:
	spawn_particles(parent, {
		"amount": 10,
		"lifetime": 0.18,
		"spread": 38.0,
		"direction": Vector2.UP,
		"vel_min": 80.0,
		"vel_max": 140.0,
		"scale_min": 1.0,
		"scale_max": 1.3,
		"color": Color(0.9, 0.9, 1.0, 0.7),
		"local_pos": local_pos
	})

static func spawn_impale_fx(parent: Node, local_pos: Vector2 = Vector2(0, -10)) -> void:
	spawn_particles(parent, {
		"amount": 12,
		"lifetime": 0.16,
		"spread": 24.0,
		"direction": Vector2.UP,
		"vel_min": 90.0,
		"vel_max": 160.0,
		"scale_min": 1.0,
		"scale_max": 1.2,
		"color": Color(0.8, 1.0, 0.8, 0.7),
		"local_pos": local_pos
	})

static func spawn_disengage_fx(parent: Node, direction: float, local_pos: Vector2 = Vector2.ZERO) -> void:
	spawn_particles(parent, {
		"amount": 14,
		"lifetime": 0.22,
		"explosiveness": 1.0,
		"spread": 28.0,
		"direction": Vector2(-direction, 0.0),
		"vel_min": 65.0,
		"vel_max": 120.0,
		"scale_min": 1.1,
		"scale_max": 1.8,
		"color": Color(0.65, 0.95, 1.0, 0.85),
		"local_pos": Vector2(-direction * 10.0, 0.0) + local_pos
	})

static func spawn_trail(parent: Node, position: Vector2, config: Dictionary = {}) -> void:
	var p: Dictionary = {
		"amount": 4,
		"lifetime": 0.1,
		"spread": 15.0,
		"direction": Vector2.ZERO,
		"vel_min": 0.0,
		"vel_max": 0.0,
		"scale_min": 0.6,
		"scale_max": 1.0,
		"color": Color(0.6, 0.95, 1.0, 0.5),
		"global_pos": position
	}
	for k in config:
		p[k] = config[k]
	
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = p.amount
	particles.lifetime = p.lifetime
	particles.explosiveness = 0.0
	particles.spread = p.spread
	particles.direction = p.direction
	particles.initial_velocity_min = p.vel_min
	particles.initial_velocity_max = p.vel_max
	particles.scale_amount_min = p.scale_min
	particles.scale_amount_max = p.scale_max
	particles.modulate = p.color
	
	var host := parent.get_parent() if parent.get_parent() else parent
	host.add_child(particles)
	particles.global_position = p.global_pos
	particles.z_index = parent.z_index - 1
	
	particles.emitting = true
	var timer := parent.get_tree().create_timer(p.lifetime + 0.05)
	timer.timeout.connect(func(): 
		if is_instance_valid(particles):
			particles.queue_free()
	)

static func spawn_sprite_trail(parent: Node, sprite: Sprite2D, lifetime: float = 0.12, alpha: float = 0.5) -> void:
	if not sprite or not sprite.texture:
		return
	
	var trail := Sprite2D.new()
	trail.texture = sprite.texture
	trail.flip_h = sprite.flip_h
	trail.scale = sprite.scale
	trail.global_position = sprite.global_position
	trail.z_index = sprite.z_index - 1
	trail.modulate = Color(1, 1, 1, alpha)
	
	var host := parent.get_parent() if parent.get_parent() else parent
	host.add_child(trail)
	
	var tween := trail.create_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, lifetime)
	tween.tween_property(trail, "scale", trail.scale * 1.05, lifetime)
	tween.finished.connect(func(): 
		if is_instance_valid(trail):
			trail.queue_free()
	)
