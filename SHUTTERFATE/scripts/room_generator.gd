extends Node2D

@export var grid_width: int = 12
@export var grid_height: int = 8
@export var cell_size: Vector2 = Vector2(64, 32)

var tile_w: float = 64.0
var tile_h: float = 32.0

func _ready():
	generate_room()

func iso_to_screen(ix: int, iy: int) -> Vector2:
	var sx = (ix - iy) * (tile_w * 0.5)
	var sy = (ix + iy) * (tile_h * 0.5)
	return Vector2(sx, sy)

func get_center() -> Vector2:
	var offset_x = -(grid_width * tile_w * 0.5)
	var offset_y = -(grid_height * tile_h * 0.5)
	var cx = grid_width / 2
	var cy = grid_height / 2
	return iso_to_screen(cx, cy) + Vector2(offset_x, offset_y)

func generate_room():
	var offset_x = -(grid_width * tile_w * 0.5)
	var offset_y = -(grid_height * tile_h * 0.5)

	# Floor tiles
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = iso_to_screen(x, y)
			place_floor(pos + Vector2(offset_x, offset_y))

	# Walls around perimeter
	for x in range(grid_width):
		place_wall(iso_to_screen(x, 0) + Vector2(offset_x, offset_y - tile_h * 0.5))
		place_wall(iso_to_screen(x, grid_height - 1) + Vector2(offset_x, offset_y - tile_h * 0.5))

	for y in range(1, grid_height - 1):
		place_wall(iso_to_screen(0, y) + Vector2(offset_x, offset_y - tile_h * 0.5))
		place_wall(iso_to_screen(grid_width - 1, y) + Vector2(offset_x, offset_y - tile_h * 0.5))

	# Random inner obstacles (avoid center 3x3)
	var obstacle_count = randi_range(3, 6)
	for i in range(obstacle_count):
		var ox = randi_range(2, grid_width - 3)
		var oy = randi_range(2, grid_height - 3)
		if abs(ox - grid_width/2) <= 1 and abs(oy - grid_height/2) <= 1:
			continue
		var pos = iso_to_screen(ox, oy) + Vector2(offset_x, offset_y - tile_h * 0.5)
		place_wall(pos)

func place_wall(pos: Vector2):
	var wall = StaticBody2D.new()
	wall.position = pos
	wall.z_index = clamp(int(pos.y), -4000, 4000)

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
	tile.modulate = Color(1, 1, 1, 0.4)
	add_child(tile)

func get_random_floor_position() -> Vector2:
	var offset_x = -(grid_width * tile_w * 0.5)
	var offset_y = -(grid_height * tile_h * 0.5)
	var x = randi_range(2, grid_width - 3)
	var y = randi_range(2, grid_height - 3)
	return iso_to_screen(x, y) + Vector2(offset_x, offset_y)
