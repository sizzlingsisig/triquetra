extends Area2D
class_name DetectionComponent

## Emitted when a valid target enters detection range.
signal target_entered(target: Node2D)

## Emitted when a valid target leaves detection range.
signal target_exited(target: Node2D)

## Groups this area considers valid targets.
@export var target_groups: Array[StringName] = [&"player"]


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if _is_target(body):
		target_entered.emit(body as Node2D)


func _on_body_exited(body: Node) -> void:
	if _is_target(body):
		target_exited.emit(body as Node2D)


func _is_target(node: Node) -> bool:
	for group: StringName in target_groups:
		if node.is_in_group(group):
			return true
	return false
