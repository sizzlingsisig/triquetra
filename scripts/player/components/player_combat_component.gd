extends Node
class_name PlayerCombatComponent

@export var enemy_hit_knockback_speed: float = 220.0
@export var enemy_hit_control_lock_time: float = 0.12

var _player: PlayerController
var _attack_window_hit_ids: Dictionary = {}

func setup(player: PlayerController) -> void:
    _player = player
    if _player._attack_area and not _player._attack_area.area_entered.is_connected(_on_attack_area_entered):
        _player._attack_area.area_entered.connect(_on_attack_area_entered)

func set_attack_area_active(is_active: bool) -> void:
    if not _player._attack_area:
        return

    _player._attack_area.set_deferred("monitoring", is_active)
    _player._attack_area.set_deferred("monitorable", is_active)

    var jump_offset := Vector2.ZERO
    if _player.movement_component:
        jump_offset = _player.movement_component.get_jump_offset()

    if is_active:
        _attack_window_hit_ids.clear()
        var forward_sign := -1.0 if _player._facing_left else 1.0
        _player._attack_area.position = _player._attack_area_base_position + Vector2(24.0 * forward_sign, 0.0) + jump_offset
    else:
        _player._attack_area.position = _player._attack_area_base_position + jump_offset

func apply_attack_overlap_hits() -> void:
    # Signal-driven hit handling replaces polling.
    pass

func _on_attack_area_entered(overlap: Area2D) -> void:
    if not _player._attack_area or not _player._attack_area.monitoring:
        return
    if not overlap:
        return
    if not overlap.is_in_group("enemy_hurtbox") and overlap.name != "AttackHitbox":
        return

    var enemy_node: Node = overlap.get_parent()
    if not enemy_node:
        return

    var enemy_id := enemy_node.get_instance_id()
    if _attack_window_hit_ids.get(enemy_id, false):
        return
    _attack_window_hit_ids[enemy_id] = true

    if enemy_node.has_method("receive_player_hit"):
        enemy_node.receive_player_hit(_player.form_manager.get_active_form_id() if _player.form_manager else &"")

func receive_enemy_hit(hit_position: Vector2 = Vector2.INF) -> void:
    _apply_enemy_hit_knockback(hit_position)
    if not _player.form_manager:
        return
    var active_state: Node = _player.form_manager.get_active_state()
    if active_state and active_state.has_method("receive_lethal_damage"):
        active_state.receive_lethal_damage()

func _apply_enemy_hit_knockback(hit_position: Vector2) -> void:
    if _player == null or _player.movement_component == null:
        return
    var direction_sign: float = 1.0
    if hit_position.is_finite():
        direction_sign = signf(_player.global_position.x - hit_position.x)
    if absf(direction_sign) <= 0.01:
        direction_sign = 1.0 if _player._facing_left else -1.0
    _player.movement_component.apply_hit_reaction(direction_sign * enemy_hit_knockback_speed, enemy_hit_control_lock_time)
