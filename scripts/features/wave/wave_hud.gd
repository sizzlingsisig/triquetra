extends CanvasLayer
class_name WaveHUD

@onready var _wave_label: Label = $WaveLabel
@onready var _enemies_label: Label = $EnemiesLabel
@onready var _overlay: ColorRect = $Overlay
@onready var _result_label: Label = $Overlay/ResultLabel
@onready var _restart_label: Label = $Overlay/RestartLabel

var _restart_allowed: bool = false


func _ready() -> void:
	_overlay.hide()
	_restart_label.hide()
	_wave_label.hide()
	_enemies_label.hide()


func show_wave_label(wave_number: int) -> void:
	_wave_label.text = "Wave %d" % wave_number
	_wave_label.show()
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(_wave_label.hide)


func update_enemies_label(count: int) -> void:
	_enemies_label.show()
	_enemies_label.text = "Enemies: %d" % count


func show_victory() -> void:
	_show_overlay(&"VICTORY", Color.GREEN)
	_enemies_label.hide()


func show_game_over() -> void:
	_show_overlay(&"GAME OVER", Color.RED)
	_enemies_label.hide()


func _show_overlay(text: String, color: Color) -> void:
	_overlay.show()
	_result_label.text = text
	_result_label.modulate = color
	_restart_label.hide()
	_restart_allowed = false
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func() -> void:
		_restart_label.show()
		_restart_allowed = true
	)


func _unhandled_input(event: InputEvent) -> void:
	if not _restart_allowed:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()
