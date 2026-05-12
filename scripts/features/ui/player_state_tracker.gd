extends CanvasLayer
class_name PlayerStateTracker

@onready var _health_bar: ProgressBar = $Panel/HealthBar
@onready var _health_label: Label = $Panel/HealthLabel
@onready var _sword_label: Label = $Panel/FormSword
@onready var _spear_label: Label = $Panel/FormSpear
@onready var _bow_label: Label = $Panel/FormBow
@onready var _state_label: Label = $Panel/StateLabel

var _player: PlayerController
var _game_manager: Node
var _guardian_labels: Array[Label] = []
var _setup_done: bool = false

func _ready() -> void:
	if _sword_label:
		_guardian_labels.append(_sword_label)
	if _spear_label:
		_guardian_labels.append(_spear_label)
	if _bow_label:
		_guardian_labels.append(_bow_label)

	_auto_setup()

func _auto_setup() -> void:
	if _setup_done:
		return

	var tree := get_tree()
	if not tree:
		return

	var player_nodes: Array[Node] = tree.get_nodes_in_group("player")
	if not player_nodes.is_empty():
		_player = player_nodes[0] as PlayerController

	_game_manager = get_node_or_null("/root/GameManager")

	setup(_player, _game_manager)

	# Connect to FormManager for swap reconnection
	var form_manager: FormManager = get_node_or_null("/root/Main/Player/FormManager")
	if form_manager:
		form_manager.active_player_changed.connect(_on_active_player_changed)

	_setup_done = true

func setup(player: PlayerController, game_manager: Node) -> void:
	_player = player
	_game_manager = game_manager

	if _player:
		if not _player.health_component.health_changed.is_connected(_on_health_changed):
			_player.health_component.health_changed.connect(_on_health_changed)
		if not _player.form_changed.is_connected(_on_form_changed):
			_player.form_changed.connect(_on_form_changed)
		if not _player.form_locked.is_connected(_on_form_locked):
			_player.form_locked.connect(_on_form_locked)

		var fsm: PlayerRuntimeFsm = _player.runtime_fsm as PlayerRuntimeFsm
		if fsm and not fsm.state_changed.is_connected(_on_state_changed):
			fsm.state_changed.connect(_on_state_changed)

	if _game_manager:
		if not _game_manager.guardian_pool_changed.is_connected(_on_guardian_pool_changed):
			_game_manager.guardian_pool_changed.connect(_on_guardian_pool_changed)

	_refresh_all()

func _on_active_player_changed(player: PlayerController) -> void:
	# Disconnect old FSM and health
	if _player:
		var old_fsm: PlayerRuntimeFsm = _player.runtime_fsm as PlayerRuntimeFsm
		if old_fsm and old_fsm.state_changed.is_connected(_on_state_changed):
			old_fsm.state_changed.disconnect(_on_state_changed)
		if _player.health_component.health_changed.is_connected(_on_health_changed):
			_player.health_component.health_changed.disconnect(_on_health_changed)

	# Connect new player
	_player = player
	var new_fsm: PlayerRuntimeFsm = _player.runtime_fsm as PlayerRuntimeFsm
	if new_fsm and not new_fsm.state_changed.is_connected(_on_state_changed):
		new_fsm.state_changed.connect(_on_state_changed)
	if not _player.health_component.health_changed.is_connected(_on_health_changed):
		_player.health_component.health_changed.connect(_on_health_changed)
	_refresh_all()

func _on_health_changed(new_health: int) -> void:
	var max_health: int = _player.health_component.max_health
	if _health_bar:
		_health_bar.max_value = max_health
		_health_bar.value = new_health
	if _health_label:
		_health_label.text = "%d / %d" % [new_health, max_health]

func _on_form_changed(_form_id: StringName) -> void:
	_refresh_form_labels()

func _on_form_locked(_form_id: StringName) -> void:
	_refresh_form_labels()

func _on_guardian_pool_changed(_active_count: int) -> void:
	_refresh_form_labels()

func _on_state_changed(from: int, to: int, _reason: StringName) -> void:
	_refresh_state_label()

func _refresh_all() -> void:
	_refresh_health()
	_refresh_form_labels()
	_refresh_state_label()

func _refresh_health() -> void:
	if not _player:
		return
	var current_health: int = _player.health_component.get_current_health()
	var max_health: int = _player.health_component.max_health
	if _health_bar:
		_health_bar.max_value = max_health
		_health_bar.value = current_health
	if _health_label:
		_health_label.text = "%d / %d" % [current_health, max_health]

func _refresh_form_labels() -> void:
	if not _game_manager:
		return
	for label: Label in _guardian_labels:
		if label == null:
			continue
		var form_name: StringName = StringName(label.name.trim_prefix("Form"))
		var is_locked: bool = _game_manager.is_guardian_locked(form_name)
		if is_locked:
			label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		else:
			label.remove_theme_color_override("font_color")

func _refresh_state_label() -> void:
	if not _state_label or not _player:
		return
	var fsm: PlayerRuntimeFsm = _player.runtime_fsm as PlayerRuntimeFsm
	var state_name: String = "?"
	if fsm:
		state_name = String(fsm.get_state_name())
	_state_label.text = "STATE: %s" % state_name
