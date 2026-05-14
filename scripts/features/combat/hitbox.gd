class_name Hitbox extends Area2D

@export var damage: int = 1
@export var attack_form: StringName = &"Sword"

## Duration in seconds the hitbox stays active when enabled. 0 = no auto-disable.
@export var active_duration: float = 0.15

## Duration of hit-stop freeze in seconds. 0 = no hit stop.
@export var hit_stop_duration: float = 0.06

var _enable_generation: int = 0

const HIT_SPARK: PackedScene = preload("res://scenes/effects/hit_spark.tscn")
const IMPACT_RING: PackedScene = preload("res://scenes/effects/impact_ring.tscn")


func _ready() -> void:
	add_to_group("player_attack")
	monitorable = true
	monitoring = false
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
	set_collision_layer_value(4, false)
	set_collision_mask_value(2, true)
	set_collision_mask_value(4, true)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


## Enable the hitbox for a single swing. Uses generation-counter pattern
## so rapid re-enables invalidate stale timers.
func enable_for_duration() -> void:
	_enable_generation += 1
	var gen: int = _enable_generation
	monitoring = true
	if active_duration > 0.0:
		var tree: SceneTree = get_tree()
		if tree:
			var timer: SceneTreeTimer = tree.create_timer(active_duration)
			timer.timeout.connect(func() -> void:
				if gen == _enable_generation:
					monitoring = false
			)


func _on_area_entered(area: Area2D) -> void:
	var tree: SceneTree = get_tree()
	# New system: emit the HurtboxComponent's signal to trigger damage.
	if area is HurtboxComponent:
		# Hit stop
		if hit_stop_duration > 0.0:
			Engine.time_scale = 0.0
			if tree:
				var stop_timer := tree.create_timer(hit_stop_duration, true, false, true)
				stop_timer.timeout.connect(func(): Engine.time_scale = 1.0)
		# Hit spark
		if tree:
			var spark := HIT_SPARK.instantiate() as GPUParticles2D
			if spark:
				spark.global_position = global_position
				tree.root.add_child(spark)
				spark.emitting = true
				spark.finished.connect(spark.queue_free)
			# Impact ring
			var ring := IMPACT_RING.instantiate() as Node2D
			if ring:
				ring.global_position = global_position
				tree.root.add_child(ring)
		# Damage
		area.hurtbox_hit.emit(self, global_position)