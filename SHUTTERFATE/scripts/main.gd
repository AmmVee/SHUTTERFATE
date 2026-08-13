extends Node2D

@export var enemy_scene: PackedScene
@export var enemy_grain_scene: PackedScene
@export var enemy_smear_aoe_scene: PackedScene
@export var enemy_fader_scene: PackedScene
@export var enemy_ghost_scene: PackedScene

var floor_gen: Node2D = null
var enemies_alive: int = 0
var current_room_enemies: Array = []
var door_nodes: Array = []
var exit_node: Area2D = null
var camera: Camera2D = null
var player: Node2D = null
var teleport_cooldown: float = 0.0

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

	var dev_menu = load("res://scripts/dev_menu.gd")
	if dev_menu:
		var dm = CanvasLayer.new()
		dm.set_script(dev_menu)
		dm.name = "DevMenu"
		add_child(dm)
		print("Dev menu loaded (F1)")

	var pause_menu = load("res://scripts/pause_menu.gd")
	if pause_menu:
		var pm = CanvasLayer.new()
		pm.set_script(pause_menu)
		pm.name = "PauseMenu"
		pm.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(pm)
		print("Pause menu loaded (ESC)")

func generate_floor():
	_cleanup_room()

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

func _cleanup_room():
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
	elif room_type == "treasure":
		spawn_treasure_room(room)
	else:
		var enemy_count = 3 + int(GameManager.current_floor * 1.5)
		if room_type == "elite":
			enemy_count += 3
		enemy_count = min(enemy_count, 15)
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

func _pick_enemy_scene() -> PackedScene:
	var floor_num = GameManager.current_floor
	var roll = randf()

	# Ghost: floor 7+, 10% chance
	if floor_num >= 7 and enemy_ghost_scene != null and roll < 0.10:
		return enemy_ghost_scene
	roll -= 0.10

	# Fader: floor 5+, 12% chance
	if floor_num >= 5 and enemy_fader_scene != null and roll < 0.12:
		return enemy_fader_scene
	roll -= 0.12

	# Smear AOE: floor 3+, 15% chance
	if floor_num >= 3 and enemy_smear_aoe_scene != null and roll < 0.15:
		return enemy_smear_aoe_scene
	roll -= 0.15

	# Default: smear or grain
	if enemy_grain_scene != null and randf() < 0.3 + (floor_num * 0.05):
		return enemy_grain_scene
	return enemy_scene

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

	var scene = _pick_enemy_scene()
	if scene == null:
		print("ERROR: enemy scene is null!")
		return

	var enemy = scene.instantiate()
	enemy.global_position = spawn_pos
	if randf() < 0.08 + (GameManager.current_floor * 0.02):
		enemy.is_elite = true
		enemy.max_hp *= 1.5
		enemy.hp = enemy.max_hp
		enemy.attack_damage = int(enemy.attack_damage * 1.2)
		if enemy.has_node("Sprite2D"):
			enemy.get_node("Sprite2D").modulate = Color(1.0, 0.85, 0.2, 1.0)
			enemy.get_node("Sprite2D").scale *= 1.3
		print("ELITE spawned!")
	add_child(enemy)
	current_room_enemies.append(enemy)
	enemies_alive += 1
	enemy.tree_exited.connect(_on_enemy_died)

func spawn_treasure_room(room):
	print("TREASURE ROOM")
	if room == null:
		return
	var chest = Area2D.new()
	chest.set_script(load("res://scripts/treasure_chest.gd"))
	var chest_pos = room.global_position + room.get_center()
	if room.has_method("is_position_inside_floor") and not room.is_position_inside_floor(chest_pos):
		chest_pos = room.global_position + room.get_random_floor_position(3)
	chest.global_position = chest_pos

	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/floor_iso.png")
	sprite.modulate = Color(1.0, 0.85, 0.2, 1.0)
	sprite.scale = Vector2(1.2, 1.2)
	chest.add_child(sprite)

	var coll = CollisionShape2D.new()
	coll.shape = RectangleShape2D.new()
	coll.shape.size = Vector2(50, 50)
	chest.add_child(coll)

	var label = Label.new()
	label.name = "Label"
	label.text = "[E] Открыть"
	label.position = Vector2(-40, -50)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1))
	label.add_theme_constant_override("outline_size", 2)
	chest.add_child(label)

	add_child(chest)
	print("Chest spawned at: ", chest.global_position)

func spawn_boss_room(room):
	print("BOSS ROOM")
	_spawn_boss(room)
	for i in range(2 + randi() % 3):
		spawn_enemy_in_room(room)

func _spawn_boss(room):
	if room == null:
		return
	var spawn_pos = room.global_position + room.get_center()
	if room.has_method("is_position_inside_floor") and not room.is_position_inside_floor(spawn_pos):
		spawn_pos = room.global_position + room.get_random_floor_position(3)

	var floor_num = GameManager.current_floor
	var boss_script = _get_boss_for_floor(floor_num)
	if boss_script == null:
		print("ERROR: boss script not found!")
		return

	var boss_node = CharacterBody2D.new()
	boss_node.set_script(boss_script)
	boss_node.global_position = spawn_pos

	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/enemy_iso.png")
	add_child(boss_node)
	boss_node.add_child(sprite)

	var coll = CollisionShape2D.new()
	coll.shape = RectangleShape2D.new()
	coll.shape.size = Vector2(40, 40)
	boss_node.add_child(coll)

	current_room_enemies.append(boss_node)
	enemies_alive += 1
	boss_node.tree_exited.connect(_on_enemy_died)
	print("BOSS SPAWNED: ", boss_node.name, " at floor ", floor_num)

func _get_boss_for_floor(floor: int):
	if floor >= 15:
		return load("res://scripts/boss_aberration.gd")
	elif floor >= 12:
		return load("res://scripts/boss_curator.gd")
	elif floor >= 9:
		return load("res://scripts/boss_photojournalist.gd")
	elif floor >= 6:
		return load("res://scripts/boss_developer.gd")
	else:
		return load("res://scripts/boss_portraitist.gd")

func _on_enemy_died():
	enemies_alive = max(enemies_alive - 1, 0)
	if enemies_alive <= 0:
		unlock_doors()
		var room_data = floor_gen.get_current_room_data()
		room_data["cleared"] = true

func unlock_doors():
	GameManager.photo_prints += 10
	print("Room cleared! +10 prints")
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
	door.set_meta("direction", direction)
	door.set_meta("locked", true)

	var door_pos: Vector2
	if room.has_method("get_door_global_position"):
		door_pos = room.get_door_global_position(direction)
	else:
		var center = room.global_position
		if room.has_method("get_center"):
			center += room.get_center()
		match direction:
			"north": door_pos = center + Vector2(0, -280)
			"south": door_pos = center + Vector2(0, 280)
			"west": door_pos = center + Vector2(-520, 0)
			"east": door_pos = center + Vector2(520, 0)

	door.position = door_pos

	var sprite = Sprite2D.new()
	sprite.name = "DoorSprite"
	sprite.texture = load("res://assets/hub_door.png")
	sprite.scale = Vector2(2.5, 2.5)
	match direction:
		"north": sprite.modulate = Color(0.2, 0.6, 1.0, 1.0)
		"south": sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
		"west": sprite.modulate = Color(0.2, 1.0, 0.3, 1.0)
		"east": sprite.modulate = Color(1.0, 0.9, 0.2, 1.0)
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
	print(" >>> DOOR ", direction, " at ", door_pos, " -> room ", target_pos)

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
	sprite.modulate = Color(1.0, 0.5, 0.0, 1.0)
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
	print(" >>> EXIT at ", exit_pos)

func _on_door_entered(body, door: Area2D):
	if not body.is_in_group("player"):
		return
	if teleport_cooldown > 0:
		return
	if door.get_meta("locked", true):
		var label = door.get_node_or_null("DoorLabel")
		if label:
			label.text = "УБЕЙТЕ ВСЕХ!"
			label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		return
	var target = door.get_meta("target_pos", Vector2i.ZERO)
	var direction = door.get_meta("direction", "")
	print("Entering door to: ", target, " via ", direction)
	call_deferred("move_to_room", target, direction)

func move_to_room(target_pos: Vector2i, from_direction: String = ""):
	if floor_gen and floor_gen.move_to_room(target_pos):
		if player:
			var enter_direction = ""
			match from_direction:
				"north": enter_direction = "south"
				"south": enter_direction = "north"
				"east": enter_direction = "west"
				"west": enter_direction = "east"

			var spawn_pos = Vector2.ZERO
			var current_room = floor_gen.get_current_room()
			if enter_direction != "" and current_room and current_room.has_method("get_door_global_position"):
				spawn_pos = current_room.get_door_global_position(enter_direction)
				var offset = Vector2.ZERO
				match enter_direction:
					"north": offset = Vector2(0, 90)
					"south": offset = Vector2(0, -90)
					"west": offset = Vector2(90, 0)
					"east": offset = Vector2(-90, 0)
				spawn_pos += offset
			else:
				spawn_pos = floor_gen.get_room_center(target_pos)

			player.global_position = spawn_pos
			teleport_cooldown = 0.6
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

func _physics_process(delta):
	if teleport_cooldown > 0:
		teleport_cooldown = max(teleport_cooldown - delta, 0.0)
	if player and camera:
		camera.global_position = player.global_position
	if player and player.global_position.distance_to(Vector2.ZERO) > 15000:
		if floor_gen:
			var center = floor_gen.get_room_center(floor_gen.current_room_pos)
			if center != Vector2.ZERO:
				player.global_position = center
