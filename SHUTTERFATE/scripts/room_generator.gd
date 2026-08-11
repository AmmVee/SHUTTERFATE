extends Node2D

@export var grid_width: int = 20
@export var grid_height: int = 14
@export var cell_size: Vector2 = Vector2(64, 32)

var tile_w: float = 64.0
var tile_h: float = 32.0

var has_door_west: bool = false
var has_door_east: bool = false
var has_door_north: bool = false
var has_door_south: bool = false
var is_safe_room: bool = false
var room_cleared: bool = false

func _ready():
	y_sort_enabled = true
	generate_room()

func iso_to_screen(ix: int, iy: int) -> Vector2:
	var sx = (ix - iy) * (tile_w * 0.5)
	var sy = (ix + iy) * (tile_h * 0.5)
	return Vector2(sx, sy)

func get_center() -> Vector2:
	var offset_x = -(grid_width * tile_w * 0.5)
	var offset_y = -(grid_height * tile_h * 0.5)
	var cx = float(grid_width) / 2.0
	var cy = float(grid_height) / 2.0
	return iso_to_screen(int(cx), int(cy)) + Vector2(offset_x, offset_y)

func get_bounds() -> Rect2:
	var center = get_center()
	var half_w = grid_width * tile_w * 0.5
	var half_h = grid_height * tile_h * 0.5
	return Rect2(center.x - half_w, center.y - half_h, half_w * 2, half_h * 2)

func is_position_inside_floor(pos: Vector2) -> bool:
	var local_pos = to_local(pos)
	var bounds = get_bounds()
	var margin = 40.0
	return bounds.grow(-margin).has_point(local_pos)

func get_random_floor_position(margin: int = 2) -> Vector2:
	var offset_x = -(grid_width * tile_w * 0.5)
	var offset_y = -(grid_height * tile_h * 0.5)
	var x = randi_range(margin, grid_width - 1 - margin)
	var y = randi_range(margin, grid_height - 1 - margin)
	return iso_to_screen(x, y) + Vector2(offset_x, offset_y)

# NEW: Get the exact local position of a door gap on the room wall
func get_door_local_position(direction: String) -> Vector2:
	var offset_x = -(grid_width * tile_w * 0.5)
	var offset_y = -(grid_height * tile_h * 0.5)
	var half_w = float(grid_width) / 2.0
	var half_h = float(grid_height) / 2.0

	match direction:
		"north":
			# Top edge, center (y=0, x=half_w)
			var dx = int(half_w)
			return iso_to_screen(dx, 0) + Vector2(offset_x, offset_y - tile_h * 0.5)
		"south":
			# Bottom edge, center (y=grid_height-1, x=half_w)
			var dx = int(half_w)
			return iso_to_screen(dx, grid_height - 1) + Vector2(offset_x, offset_y - tile_h * 0.5)
		"west":
			# Left edge, center (x=0, y=half_h)
			var dy = int(half_h)
			return iso_to_screen(0, dy) + Vector2(offset_x, offset_y - tile_h * 0.5)
		"east":
			# Right edge, center (x=grid_width-1, y=half_h)
			var dy = int(half_h)
			return iso_to_screen(grid_width - 1, dy) + Vector2(offset_x, offset_y - tile_h * 0.5)
	return Vector2.ZERO

# NEW: Get global position of the door
func get_door_global_position(direction: String) -> Vector2:
	return global_position + get_door_local_position(direction)

func generate_room():
	var offset_x = -(grid_width * tile_w * 0.5)
	var offset_y = -(grid_height * tile_h * 0.5)
	var half_h = float(grid_height) / 2.0
	var half_w = float(grid_width) / 2.0

	# Floor
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = iso_to_screen(x, y)
			place_floor(pos + Vector2(offset_x, offset_y))

	# Walls with door gaps
	for x in range(grid_width):
		var is_door_north = has_door_north and (x >= int(half_w) - 1 and x <= int(half_w))
		var is_door_south = has_door_south and (x >= int(half_w) - 1 and x <= int(half_w))
		if not is_door_north:
			place_wall(iso_to_screen(x, 0) + Vector2(offset_x, offset_y - tile_h * 0.5))
		if not is_door_south:
			place_wall(iso_to_screen(x, grid_height - 1) + Vector2(offset_x, offset_y - tile_h * 0.5))

	for y in range(1, grid_height - 1):
		var is_door_west = has_door_west and (y >= int(half_h) - 1 and y <= int(half_h))
		var is_door_east = has_door_east and (y >= int(half_h) - 1 and y <= int(half_h))
		if not is_door_west:
			place_wall(iso_to_screen(0, y) + Vector2(offset_x, offset_y - tile_h * 0.5))
		if not is_door_east:
			place_wall(iso_to_screen(grid_width - 1, y) + Vector2(offset_x, offset_y - tile_h * 0.5))

	# Inner obstacles
	var obstacle_count = randi_range(4, 8)
	for i in range(obstacle_count):
		var ox = randi_range(2, grid_width - 3)
		var oy = randi_range(2, grid_height - 3)
		if abs(ox - int(half_w)) <= 1 and abs(oy - int(half_h)) <= 1:
			continue
		if has_door_west and ox <= 2:
			continue
		if has_door_east and ox >= grid_width - 3:
			continue
		if has_door_north and oy <= 2:
			continue
		if has_door_south and oy >= grid_height - 3:
			continue
		var pos = iso_to_screen(ox, oy) + Vector2(offset_x, offset_y - tile_h * 0.5)
		place_wall(pos)

func place_wall(pos: Vector2):
	var wall = StaticBody2D.new()
	wall.set_script(load("res://scripts/wall.gd"))
	wall.position = pos
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/wall_iso.png")
	wall.add_child(sprite)
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(48, 24)
	shape.position = Vector2(0, -8)
	wall.add_child(shape)
	wall.add_to_group("walls")
	add_child(wall)

func place_floor(pos: Vector2):
	var tile = Sprite2D.new()
	tile.texture = load("res://assets/floor_iso.png")
	tile.position = pos
	tile.z_index = -100
	tile.modulate = Color(1, 1, 1, 0.5)
	add_child(tile)
