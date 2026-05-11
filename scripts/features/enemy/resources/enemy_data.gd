extends Resource
class_name EnemyData

@export var is_shielded: bool = false
@export var is_arrow_skeleton: bool = false
@export var enable_attacks: bool = false

@export var max_health: int = 2
@export var attack_interval: float = 1.6
@export var attack_active_time: float = 0.22
@export var attack_range: float = 40.0
@export var arrow_speed: float = 420.0
@export var arrow_lifetime: float = 1.2

@export var idle_animation: StringName = &"knight_idle"
@export var run_animation: StringName = &"knight_run"
@export var defend_animation: StringName = &"knight_defend"
@export var hurt_animation: StringName = &"knight_hurt"
@export var dead_animation: StringName = &"knight_dead"
@export var attack_animations: Array[StringName] = [
	&"knight_attack1",
	&"knight_attack2",
	&"knight_attack3",
]

@export var defend_recover_time: float = 0.22
@export var hurt_recover_time: float = 0.18
@export var attack_recover_time: float = 0.35
@export var death_cleanup_delay: float = 0.28
