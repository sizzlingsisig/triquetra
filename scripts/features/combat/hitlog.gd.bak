class_name HitLog extends RefCounted

var _hit_entities: Array[int] = []

func has_hit(entity: Node) -> bool:
    return entity.get_instance_id() in _hit_entities

func record_hit(entity: Node) -> void:
    _hit_entities.append(entity.get_instance_id())