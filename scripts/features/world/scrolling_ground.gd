extends TileMapLayer
class_name ScrollingGround

## How many times to repeat the tile pattern left and right.
## Each copy doubles as a full tile-data-width extension of the ground.
@export var repeat_copies: int = 3

var _base_position: Vector2
var _tile_width_px: float
var _initialized: bool = false

# TODO: This reads all existing cells and calls set_cell() per tile which is
#  fine for small tile counts (<10k) but won't scale. For a truly infinite
#  world (procedural chunks, streaming), replace with chunk-based generation
#  that only creates/destroys cells near the camera.

func _ready() -> void:
	_base_position = position
	_tile_width_px = 16.0 * scale.x

	var rect: Rect2i = get_used_rect()
	var template: Dictionary = {}

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var coords := Vector2i(x, y)
			var src: int = get_cell_source_id(coords)
			if src != -1:
				template[coords] = {
					"src": src,
					"atlas": get_cell_atlas_coords(coords),
					"alt": get_cell_alternative_tile(coords)
				}

	var pattern_w: int = rect.size.x
	if pattern_w <= 0:
		push_error("ScrollingGround: no tiles found in TileMapLayer")
		_initialized = true
		return

	for direction in [-1, 1]:
		for copy in range(1, repeat_copies + 1):
			var offset_x: int = copy * pattern_w * direction
			for cell_coords: Vector2i in template.keys():
				var entry: Dictionary = template[cell_coords]
				var new_coords: Vector2i = cell_coords + Vector2i(offset_x, 0)
				set_cell(new_coords, entry["src"], entry["atlas"], entry["alt"])

	_initialized = true

func _physics_process(_delta: float) -> void:
	if not _initialized:
		return

	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return

	var rect: Rect2i = get_used_rect()
	var center_col: float = rect.position.x + rect.size.x * 0.5
	position.x = camera.global_position.x - center_col * _tile_width_px
	position.y = _base_position.y
