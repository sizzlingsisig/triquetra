extends CanvasLayer
class_name PlayerDebugWidget

@export var refresh_rate: float = 0.15

@onready var _label: Label = get_node_or_null("DebugLabel")

var _player: PlayerController
var _game_manager: Node
var _time_to_refresh: float = 0.0

func setup(player: PlayerController, game_manager: Node) -> void:
	_player = player
	_game_manager = game_manager
	if _player:
		if not _player.form_changed.is_connected(_on_player_state_changed):
			_player.form_changed.connect(_on_player_state_changed)
		if not _player.form_locked.is_connected(_on_player_state_changed):
			_player.form_locked.connect(_on_player_state_changed)
	_refresh(true)

func _process(delta: float) -> void:
	_time_to_refresh = max(_time_to_refresh - delta, 0.0)
	if _time_to_refresh <= 0.0:
		_refresh(false)

func _on_player_state_changed(_value: StringName) -> void:
	_refresh(true)

func _refresh(force: bool) -> void:
	if not _label or not _player:
		return
	if not force and _time_to_refresh > 0.0:
		return

	_time_to_refresh = max(refresh_rate, 0.02)
	var locked_forms: PackedStringArray = _player.get_locked_forms_for_debug()
	var buffered_command: String = _player.get_buffered_command_for_debug()
	var reset_reason: String = _player.get_last_reset_reason_for_debug()
	if reset_reason.is_empty() and _game_manager and _game_manager.has_method("get_last_reset_reason"):
		reset_reason = String(_game_manager.get_last_reset_reason())
	if reset_reason.is_empty():
		reset_reason = "<none>"

	_label.text = "Form: %s\nLocked: %s\nBuffered Command: %s\nLast Reset: %s" % [
		String(_player.get_active_form_id()),
		", ".join(locked_forms) if not locked_forms.is_empty() else "<none>",
		buffered_command,
		reset_reason
	]
