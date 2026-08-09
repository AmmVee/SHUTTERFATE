extends Node2D

@export var enemy_scene: PackedScene
@export var enemy_grain_scene: PackedScene

var floor_gen: Node2D = null
var enemies_alive: int = 0
var current_room_enemies: Array = []
var door_nodes: Array = []
var exit_node: Area2D = null
var camera: Camera2D = null
var player: Node2D = null

func _ready():
	player = get_node_or_null("Player")
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		print("ERROR: No player found!")
		return

	camera = Camera2D.new()
	camera.name = "MainCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.zoom = Vector2(1.0, 1.0)
	player.add_child(camera)

	if GameManager.current_room == 0:
		GameManager.current_room = 1
		GameManager.current_floor = 1

	generate_floor()

func generate_floor():
	if floor_gen != null and is_instance_valid(floor_gen):
		floor_gen.queue_free()
	for e in current_room_enemies:
		if is_instance_valid(e):
			e.queue_free()
	current_room_enemies.clear()
	enemies_alive = 0
	for d in door_nodes:
		if is_instance_valid(d):
			d.queue_free()
	door_nodes.clear()
	if exit_node != null and is_instance_valid(exit_node):
		exit_node.queue_free()
		exit_node = null

	floor_gen = Node2D.new()
	floor_gen.name = "FloorGenerator"
	floor_gen.set_script(load("res://scripts/floor_generator.gd"))
	add_child(floor_gen)

	await get_tree().process_frame
	await get_tree().process_frame

	if player and floor_gen:
		var start_pos = floor_gen.get_room_center(Vector2i.ZERO)
		if start_pos != Vector2.ZERO:
			player.global_position = start_pos
			print("Player at: ", start_pos)
		else:
			print("WARNING: start_pos ZERO")

	enter_current_room()
	update_floor_ui()

func enter_current_room():
	for e in current_room_enemies:
		if is_instance_valid(e):
			e.queue_free()
	current_room_enemies.clear()
	enemies_alive = 0
	for d in door_nodes:
		if is_instance_valid(d):
			d.queue_free()
	door_nodes.clear()
	if exit_node != null and is_instance_valid(exit_node):
		exit_node.queue_free()
		exit_node = null

	var room_data = floor_gen.get_current_room_data()
	var room_type = room_data.get("type", "combat")
	var room = floor_gen.get_current_room()

	print("=== Room: ", floor_gen.current_room_pos, " | Type: ", room_type, " ===")

	if room_type == "start":
		print("Safe room")
	elif room_type == "boss":
		spawn_boss_room(room)
	else:
		var enemy_count = 2 + GameManager.current_floor
		if room_type == "elite":
			enemy_count += 2
		enemy_count = min(enemy_count, 12)
		print("Spawning ", enemy_count, " enemies")
		for i in range(enemy_count):
			spawn_enemy_in_room(room)

	var connections = room_data.get("connections", {})
	print("Connections: ", connections.keys())
	for dir_name in connections.keys():
		var target_pos = connections[dir_name]
		create_transition_door(room, dir_name, target_pos)

	if room_type == "boss":
		create_exit(room)

	if room_type == "start":
		room_data["cleared"] = true
		unlock_doors()

func spawn_enemy_in_room(room):
	if enemies_alive >= 20:
		return
	if room == null or not room.has_method("get_random_floor_position"):
		return
	var spawn_pos = room.global_position + room.get_random_floor_position(2)
	if room.has_method("is_position_inside_floor"):
		if not room.is_position_inside_floor(spawn_pos):
			spawn_pos = room.global_position + room.get_center() + Vector2(randf_range(-40, 40), randf_range(-20, 20))
	if player and spawn_pos.distance_to(player.global_position) < 120:
		spawn_pos += Vector2(140, 0)
	var scene = enemy_scene
	if enemy_grain_scene != null and randf() < 0.3 + (GameManager.current_floor * 0.05):
		scene = enemy_grain_scene
	if scene == null:
		print("ERROR: enemy_scene is null!")
		return
	var enemy = scene.instantiate()
	enemy.global_position = spawn_pos
	add_child(enemy)
	current_room_enemies.append(enemy)
	enemies_alive += 1
	enemy.tree_exited.connect(_on_enemy_died)

func spawn_boss_room(room):
	print("BOSS ROOM")
	for i in range(3):
		spawn_enemy_in_room(room)

func _on_enemy_died():
	enemies_alive = max(enemies_alive - 1, 0)
	if enemies_alive <= 0:
		unlock_doors()
		var room_data = floor_gen.get_current_room_data()
		room_data["cleared"] = true

func unlock_doors():
	for d in door_nodes:
		if is_instance_valid(d):
			d.set_meta("locked", false)
			var sprite = d.get_node_or_null("DoorSprite")
			if sprite:
				sprite.modulate = Color(0.3, 1.0, 0.3, 1.0)
			var label = d.get_node_or_null("DoorLabel")
			if label:
				label.text = "[E] Перейти"
				label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
	if exit_node != null and is_instance_valid(exit_node):
		exit_node.set_meta("locked", false)
		var sprite = exit_node.get_node_or_null("ExitSprite")
		if sprite:
			sprite.modulate = Color(1.0, 0.9, 0.2, 1.0)
		var label = exit_node.get_node_or_null("ExitLabel")
		if label:
			label.text = "[E] Следующий этаж"
			label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1))
	print("Room cleared! Doors unlocked.")

func create_transition_door(room, direction: String, target_pos: Vector2i):
	var door = Area2D.new()
	door.name = "Door_%s" % direction
	door.set_meta("target_pos", target_pos)
	door.set_meta("locked", true)

	var door_pos: Vector2
	if room.has_method("get_center"):
		var center = room.get_center()
		var off_x = 520.0
		var off_y = 280.0
		if "grid_width" in room and "tile_w" in room:
			off_x = room.grid_width * room.tile_w * 0.58
		if "grid_height" in room and "tile_h" in room:
			off_y = room.grid_height * room.tile_h * 0.58

		match direction:
			"north": door_pos = room.global_position + center + Vector2(0, -off_y)
			"south": door_pos = room.global_position + center + Vector2(0, off_y)
			"west":  door_pos = room.global_position + center + Vector2(-off_x, 0)
			"east":  door_pos = room.global_position + center + Vector2(off_x, 0)
	else:
		match direction:
			"north": door_pos = room.global_position + Vector2(0, -400)
			"south": door_pos = room.global_position + Vector2(0, 400)
			"west":  door_pos = room.global_position + Vector2(-600, 0)
			"east":  door_pos = room.global_position + Vector2(600, 0)

	door.position = door_pos

	# HUGE colored marker so it's impossible to miss
	var sprite = Sprite2D.new()
	sprite.name = "DoorSprite"
	sprite.texture = load("res://assets/hub_door.png")
	sprite.scale = Vector2(2.5, 2.5)

	# Bright color per direction
	match direction:
		"north": sprite.modulate = Color(0.2, 0.6, 1.0, 1.0)   # Blue
		"south": sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)   # Red
		"west":  sprite.modulate = Color(0.2, 1.0, 0.3, 1.0)   # Green
		"east":  sprite.modulate = Color(1.0, 0.9, 0.2, 1.0)   # Yellow

	door.add_child(sprite)

	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(80, 80)
	shape.position = Vector2(0, -8)
	door.add_child(shape)

	var label = Label.new()
	label.name = "DoorLabel"
	label.text = "[ЗАБЛОКИРОВАНО]"
	label.position = Vector2(-60, -70)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_constant_override("outline_size", 3)
	door.add_child(label)

	door.body_entered.connect(_on_door_entered.bind(door))
	door_nodes.append(door)
	add_child(door)
	print("  >>> DOOR ", direction, " at ", door_pos, " -> room ", target_pos)

func create_exit(room):
	exit_node = Area2D.new()
	exit_node.name = "ExitLadder"
	exit_node.set_meta("locked", true)

	var exit_pos = room.global_position
	if room.has_method("get_center"):
		exit_pos = room.global_position + room.get_center() + Vector2(250, 0)
	else:
		exit_pos = room.global_position + Vector2(400, 0)

	exit_node.position = exit_pos

	var sprite = Sprite2D.new()
	sprite.name = "ExitSprite"
	sprite.texture = load("res://assets/hub_door.png")
	sprite.scale = Vector2(3.0, 3.0)
	sprite.modulate = Color(1.0, 0.5, 0.0, 1.0)  # Orange
	exit_node.add_child(sprite)

	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(80, 80)
	shape.position = Vector2(0, -8)
	exit_node.add_child(shape)

	var label = Label.new()
	label.name = "ExitLabel"
	label.text = "[ЗАБЛОКИРОВАНО]"
	label.position = Vector2(-70, -80)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3, 1))
	label.add_theme_constant_override("outline_size", 3)
	exit_node.add_child(label)

	exit_node.body_entered.connect(_on_exit_entered)
	add_child(exit_node)
	print("  >>> EXIT at ", exit_pos)

func _on_door_entered(body, door: Area2D):
	if not body.is_in_group("player"):
		return
	if door.get_meta("locked", true):
		var label = door.get_node_or_null("DoorLabel")
		if label:
			label.text = "УБЕЙТЕ ВСЕХ!"
			label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		return
	var target = door.get_meta("target_pos", Vector2i.ZERO)
	print("Entering door to: ", target)
	call_deferred("move_to_room", target)

func move_to_room(target_pos: Vector2i):
	if floor_gen and floor_gen.move_to_room(target_pos):
		if player:
			player.global_position = floor_gen.get_room_center(target_pos)
			print("Moved to: ", player.global_position)
		enter_current_room()
		update_floor_ui()

func _on_exit_entered(body):
	if not body.is_in_group("player"):
		return
	if exit_node and exit_node.get_meta("locked", true):
		var label = exit_node.get_node_or_null("ExitLabel")
		if label:
			label.text = "УБЕЙТЕ ВСЕХ!"
			label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		return
	call_deferred("next_floor")

func next_floor():
	GameManager.current_floor += 1
	GameManager.current_room = 1
	print("=== NEW FLOOR: ", GameManager.current_floor, " ===")
	generate_floor()

func update_floor_ui():
	var ui = get_node_or_null("FloorUI")
	if ui:
		var label = ui.get_node_or_null("FloorLabel")
		if label and floor_gen:
			var room_data = floor_gen.get_current_room_data()
			var room_type = room_data.get("type", "combat")
			var type_names = {"start": "Старт", "combat": "Бой", "elite": "Элита", "boss": "БОСС", "treasure": "Сокровище"}
			var type_str = type_names.get(room_type, "Бой")
			label.text = "Этаж: %d | %s" % [GameManager.current_floor, type_str]

func _physics_process(_delta):
	if player and camera:
		camera.global_position = player.global_position
	if player and player.global_position.distance_to(Vector2.ZERO) > 15000:
		if floor_gen:
			var center = floor_gen.get_room_center(floor_gen.current_room_pos)
			if center != Vector2.ZERO:
				player.global_position = center
