extends Node

signal enemy_hit_player(hit_position: Vector2, camera_intensity: float, camera_duration: float)
signal enemy_hit_stop_requested(duration: float)

func emit_enemy_hit_player(hit_position: Vector2, camera_intensity: float = 4.0, camera_duration: float = 0.08) -> void:
	enemy_hit_player.emit(hit_position, camera_intensity, camera_duration)

func emit_enemy_hit_stop(duration: float = 0.06) -> void:
	enemy_hit_stop_requested.emit(maxf(duration, 0.01))
