extends Area2D
class_name HurtboxComponent

## Emitted when a matching damage source enters this hurtbox.
## [param source] is the attacking node (Area2D or PhysicsBody2D).
## [param hit_position] is where the collision happened.
signal hurtbox_hit(source: Node, hit_position: Vector2)

## Groups that this hurtbox considers "damage sources".
## Anything in these groups will trigger hurtbox_hit.
@export var damage_source_groups: Array[StringName] = [
	&"player_attack",
	&"projectile",
]

## When true, all damage is ignored.
@export var invulnerable: bool = false

## Duration of invulnerability after taking a hit (0 = disabled).
@export var invulnerability_duration: float = 0.0

var _invulnerability_generation: int = 0


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func make_invulnerable() -> void:
	invulnerable = true
	_invulnerability_generation += 1
	var gen: int = _invulnerability_generation
	if invulnerability_duration > 0.0:
		var timer: SceneTreeTimer = get_tree().create_timer(invulnerability_duration)
		timer.timeout.connect(func() -> void:
			if gen == _invulnerability_generation:
				invulnerable = false
		)


func make_vulnerable() -> void:
	invulnerable = false
	_invulnerability_generation += 1


func _on_body_entered(body: Node) -> void:
	if invulnerable:
		return
	if _is_damage_source(body):
		hurtbox_hit.emit(body, global_position)


func _on_area_entered(area: Area2D) -> void:
	if invulnerable:
		return
	if _is_damage_source(area):
		hurtbox_hit.emit(area, global_position)


func _is_damage_source(node: Node) -> bool:
	for group: StringName in damage_source_groups:
		if node.is_in_group(group):
			return true
	return false
