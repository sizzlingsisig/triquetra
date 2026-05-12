extends Area2D
class_name HitboxComponent

## Emitted when a valid target enters this hitbox.
## [param target] is the Node2D that was hit.
## [param hit_position] is where the collision occurred.
signal hitbox_hit(target: Node2D, hit_position: Vector2)

## Groups this hitbox considers valid targets.
@export var target_groups: Array[StringName] = [&"player"]

## Damage value this hitbox applies. Set per enemy type.
@export var damage: int = 1


func _ready() -> void:
	monitoring = false  # Off by default — enabled during attack windows
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not _is_target(body):
		return
	hitbox_hit.emit(body, global_position)


func _is_target(node: Node) -> bool:
	for group: StringName in target_groups:
		if node.is_in_group(group):
			return true
	return false
