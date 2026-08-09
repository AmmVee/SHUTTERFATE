extends Node2D

@export var room_spacing: Vector2 = Vector2(1200, 900)

var floor_map: Dictionary = {}
var room_instances: Dictionary = {}
var current_room_pos: Vector2i = Vector2i.ZERO

const ROOM_START = "start"
const ROOM_COMBAT = "combat"
const ROOM_ELITE = "elite"
const ROOM_BOSS = "boss"
const ROOM_TREASURE = "treasure"

func _ready():
	generate_floor()

func generate_floor():
	for inst in room_instances.values():
		if is_instance_valid(inst):
			inst.queue_free()
	room_instances.clear()
	floor_map.clear()

	var depth = 3 + int(float(GameManager.current_floor) / 2.0)
	depth = clamp(depth, 3, 6)

	floor_map[Vector2i.ZERO] = {"type": ROOM_START, "connections": {}, "cleared": true}

	var current = Vector2i.ZERO
	var path = [current]

	for i in range(depth):
		var neighbors = _get_free_neighbors(current)
		if neighbors.size() == 0:
			print("No free neighbors for ", current, " — stopping path generation")
			break
		var next = neighbors[randi() % neighbors.size()]
		floor_map[next] = {"type": ROOM_COMBAT, "connections": {}, "cleared": false}
		_connect_rooms(current, next)
		current = next
		path.append(current)

	if path.size() > 1:
		floor_map[current]["type"] = ROOM_BOSS
		print("Boss room at: ", current)

	var side_count = randi_range(1, 3)
	for i in range(side_count):
		var candidates = []
		for pos in floor_map.keys():
			if floor_map[pos]["type"] in [ROOM_COMBAT, ROOM_START]:
				var free = _get_free_neighbors(pos)
				for f in free:
					if f not in floor_map:
						candidates.append({"from": pos, "to": f})
		if candidates.size() > 0:
			var choice = candidates[randi() % candidates.size()]
			var rtype = ROOM_TREASURE if randf() < 0.5 else ROOM_ELITE
			floor_map[choice.to] = {"type": rtype, "connections": {}, "cleared": false}
			_connect_rooms(choice.from, choice.to)
			print("Side room ", rtype, " at ", choice.to, " connected from ", choice.from)

	print("Floor map has ", floor_map.size(), " rooms")
	for pos in floor_map.keys():
		print("  Room ", pos, " | type: ", floor_map[pos]["type"], " | connections: ", floor_map[pos]["connections"].keys())

	for pos in floor_map.keys():
		var room = Node2D.new()
		room.name = "Room_%d_%d" % [pos.x, pos.y]
		room.position = Vector2(pos.x * room_spacing.x, pos.y * room_spacing.y)
		room.y_sort_enabled = true

		var data = floor_map[pos]
		if pos == Vector2i.ZERO:
			room.set("is_safe_room", true)

		for dir_name in data["connections"].keys():
			match dir_name:
				"north": room.set("has_door_north", true)
				"south": room.set("has_door_south", true)
				"east": room.set("has_door_east", true)
				"west": room.set("has_door_west", true)

		room.set_script(load("res://scripts/room_generator.gd"))
		add_child(room)
		room_instances[pos] = room

	create_corridors()

	current_room_pos = Vector2i.ZERO

func create_corridors():
	for pos in floor_map.keys():
		var connections = floor_map[pos]["connections"]
		for dir_name in connections.keys():
			var target = connections[dir_name]
			if pos.x < target.x or (pos.x == target.x and pos.y < target.y):
				_draw_corridor(pos, target)

func _draw_corridor(a: Vector2i, b: Vector2i):
	var center_a = get_room_center(a)
	var center_b = get_room_center(b)
	var dist = center_a.distance_to(center_b)
	var steps = max(int(dist / 60), 6)

	for i in range(1, steps):
		var t = float(i) / float(steps)
		var pos = center_a.lerp(center_b, t)
		var tile = Sprite2D.new()
		tile.texture = load("res://assets/floor_iso.png")
		tile.position = pos
		tile.z_index = -150
		tile.modulate = Color(0.6, 0.6, 0.7, 0.25)
		tile.scale = Vector2(0.8, 0.8)
		add_child(tile)

func _get_free_neighbors(pos: Vector2i) -> Array:
	var dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var free = []
	for d in dirs:
		var n = pos + d
		if n not in floor_map:
			# Only exclude positions that would overlap (same or diagonal to existing)
			var too_close = false
			for other in floor_map.keys():
				if n != other:
					var dx = float(n.x - other.x)
					var dy = float(n.y - other.y)
					var dist_sq = dx * dx + dy * dy
					# Distance < 1 means same cell (shouldn't happen)
					# Distance 1 = direct neighbor (VALID for connections)
					# Distance 2 = diagonal (too close, would overlap visually)
					if dist_sq < 1.0:
						too_close = true
						break
			if not too_close:
				free.append(n)
	return free

func _connect_rooms(a: Vector2i, b: Vector2i):
	var diff = b - a
	if diff == Vector2i.UP:
		floor_map[a]["connections"]["north"] = b
		floor_map[b]["connections"]["south"] = a
	elif diff == Vector2i.DOWN:
		floor_map[a]["connections"]["south"] = b
		floor_map[b]["connections"]["north"] = a
	elif diff == Vector2i.RIGHT:
		floor_map[a]["connections"]["east"] = b
		floor_map[b]["connections"]["west"] = a
	elif diff == Vector2i.LEFT:
		floor_map[a]["connections"]["west"] = b
		floor_map[b]["connections"]["east"] = a

func get_current_room() -> Node2D:
	return room_instances.get(current_room_pos, null)

func get_room(pos: Vector2i) -> Node2D:
	return room_instances.get(pos, null)

func get_room_center(pos: Vector2i) -> Vector2:
	var room = get_room(pos)
	if room and room.has_method("get_center"):
		return room.global_position + room.get_center()
	return Vector2.ZERO

func move_to_room(pos: Vector2i) -> bool:
	if pos in floor_map:
		current_room_pos = pos
		return true
	return false

func get_room_data(pos: Vector2i) -> Dictionary:
	return floor_map.get(pos, {})

func get_current_room_data() -> Dictionary:
	return get_room_data(current_room_pos)

func is_boss_room(pos: Vector2i) -> bool:
	return get_room_data(pos).get("type", "") == ROOM_BOSS
