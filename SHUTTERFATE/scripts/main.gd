extends Node2D

@export var enemy_scene: PackedScene
@export var enemy_grain_scene: PackedScene
@export var enemy_smear_aoe_scene: PackedScene
@export var enemy_fader_scene: PackedScene
@export var enemy_ghost_scene: PackedScene

var floor_gen: Node2D = null
var enemies_alive: int = 0
var puzzle_active: bool = false
var current_puzzle_object: Node = null
var current_room_enemies: Array = []
var door_nodes: Array = []
var exit_node: Area2D = null
var camera: Camera2D = null
var player: Node2D = null
var teleport_cooldown: float = 0.0

func _ready():
	add_to_group("main")
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

	# Hotbar system
	GameManager.reset_hotbar()
	var hotbar_ui = preload("res://scripts/hotbar_ui.gd").new()
	add_child(hotbar_ui)
	print("Hotbar UI loaded")

	var pause_menu = load("res://scripts/pause_menu.gd")
	if pause_menu:
		var pm = CanvasLayer.new()
		pm.set_script(pause_menu)
		pm.name = "PauseMenu"
		pm.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(pm)
		print("Pause menu loaded (ESC)")

func generate_floor():
	current_puzzle_object = null
	puzzle_active = false
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

	match room_type:
		"start":
			print("Safe room")
		"boss":
			spawn_boss_room(room)
		"treasure":
			spawn_treasure_room(room)
		"trap":
			spawn_trap_room(room)
		"puzzle":
			spawn_puzzle_room(room)
		"rest":
			spawn_rest_room(room)
		"miniboss":
			spawn_miniboss_room(room)
		"gallery":
			spawn_gallery_room(room)
		_:
			# combat / elite — revisit scaling
			var visits = room_data.get("visits", 0)
			visits += 1
			room_data["visits"] = visits
			room_data["cleared"] = false
			print("Room visits: ", visits)
			
			# NPC encounter chance (8% per combat room, only unmet NPCs)
			if randf() < 0.08:
				spawn_npc_encounter(room)
			
			var enemy_count = 3 + int(GameManager.current_floor * 1.5)
			if room_type == "elite":
				enemy_count += 3
			enemy_count = min(enemy_count, 15)
			print("Spawning ", enemy_count, " enemies (visit #", visits, ")")
			for i in range(enemy_count):
				spawn_enemy_in_room(room, visits)

	var connections = room_data.get("connections", {})
	print("Connections: ", connections.keys())
	for dir_name in connections.keys():
		var target_pos = connections[dir_name]
		create_transition_door(room, dir_name, target_pos)

	if room_type == "boss":
		create_exit(room)

	if room_type == "treasure":
		room_data["cleared"] = true
		unlock_doors()

	if room_type == "trap":
		room_data["cleared"] = true
		unlock_doors()

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


func spawn_npc_encounter(room):
	var unmet = []
	for npc_id in GameManager.NPCS.keys():
		if not GameManager.has_met_npc(npc_id):
			unmet.append(npc_id)
	if unmet.size() == 0:
		return

	var npc_id = unmet[randi() % unmet.size()]
	var data = GameManager.NPCS[npc_id]

	var npc = Area2D.new()
	npc.name = "NPCEncounter_" + npc_id
	npc.set_meta("npc_id", npc_id)
	var pos = room.global_position + room.get_center() + Vector2(randf_range(-60, 60), randf_range(-40, 40))
	npc.global_position = pos

	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/floor_iso.png")
	sprite.modulate = data.color
	sprite.scale = Vector2(0.9, 0.9)
	npc.add_child(sprite)

	var coll = CollisionShape2D.new()
	coll.shape = CircleShape2D.new()
	coll.shape.radius = 40.0
	npc.add_child(coll)

	var label = Label.new()
	label.name = "Label"
	label.text = "[E] " + data.name
	label.position = Vector2(-60, -60)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", data.color)
	label.add_theme_constant_override("outline_size", 2)
	npc.add_child(label)

	npc.body_entered.connect(_on_npc_encounter_entered.bind(npc))
	npc.body_exited.connect(_on_npc_encounter_exited.bind(npc))
	add_child(npc)
	current_room_enemies.append(npc)
	print("NPC ENCOUNTER: ", data.name, " at ", pos)

func _on_npc_encounter_entered(body, npc):
	if not body.is_in_group("player"):
		return
	npc.set_meta("player_near", true)
	var label = npc.get_node_or_null("Label")
	if label:
		label.visible = true

func _on_npc_encounter_exited(body, npc):
	if not body.is_in_group("player"):
		return
	npc.set_meta("player_near", false)
	var label = npc.get_node_or_null("Label")
	if label:
		label.visible = false

func _interact_npc_encounter(npc):
	var npc_id = npc.get_meta("npc_id", "")
	if npc_id == "":
		return
	var data = GameManager.NPCS[npc_id]
	GameManager.meet_npc(npc_id)

	var dialog = Label.new()
	dialog.text = data.name + "\n\"" + data.desc + "\"\n\nТеперь этот персонаж будет ждать вас в Тёмной комнате."
	dialog.position = Vector2(560, 400)
	dialog.size = Vector2(800, 120)
	dialog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_theme_font_size_override("font_size", 16)
	dialog.add_theme_color_override("font_color", data.color)
	dialog.add_theme_constant_override("outline_size", 3)
	dialog.z_index = 200
	add_child(dialog)

	var tween = get_tree().create_tween()
	tween.tween_property(dialog, "modulate:a", 0.0, 3.0)
	tween.tween_callback(func(): dialog.queue_free())

	current_room_enemies.erase(npc)
	npc.queue_free()
	print("NPC encounter resolved: ", npc_id)

func spawn_enemy_in_room(room, visit_count: int = 1):
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

	# Pact: Double Exposure (+50% enemy HP)
	var pact_hp = GameManager.get_pact_hp_mult()
	if pact_hp > 1.0:
		enemy.max_hp = int(enemy.max_hp * pact_hp)
		enemy.hp = enemy.max_hp

	# Scale enemies by revisit count
	var scale_mult = 1.0 + (visit_count - 1) * 0.25
	if scale_mult > 1.0:
		enemy.max_hp = int(enemy.max_hp * scale_mult)
		enemy.hp = enemy.max_hp
		enemy.attack_damage = int(enemy.attack_damage * scale_mult)
		enemy.move_speed = enemy.move_speed * (1.0 + (visit_count - 1) * 0.1)
		print("Enemy scaled x", scale_mult, " (visit #", visit_count, ")")

	if randf() < 0.08 + (GameManager.current_floor * 0.02):
		enemy.is_elite = true
		enemy.max_hp = int(enemy.max_hp * 1.5)
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
	var room_data = floor_gen.get_current_room_data()
	if room_data.get("chest_spawned", false):
		print("Chest already spawned in this room")
		return
	room_data["chest_spawned"] = true
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

func _get_boss_name() -> String:
	match GameManager.current_floor:
		1,2,3,4,5: return "ПОРТРЕТИСТ"
		6,7,8: return "ПРОЯВЩИК"
		9,10,11: return "ФОТОЖУРНАЛИСТ"
		12,13,14: return "КУРАТОР"
		_: return "АБЕРРАЦИЯ"

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
	boss_node.tree_exited.connect(_on_boss_died)
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
	current_puzzle_object = null
	puzzle_active = false
	GameManager.current_floor += 1
	GameManager.current_room = 1
	print("=== NEW FLOOR: ", GameManager.current_floor, " ===")
	AchievementManager.set_max_floor(GameManager.current_floor)
	AchievementManager.check_old_lens_floor5(GameManager.current_floor)
	generate_floor()

func _find_room_of_type(room_type: String) -> Vector2i:
	if floor_gen == null:
		return Vector2i.ZERO
	for pos in floor_gen.floor_map.keys():
		var data = floor_gen.floor_map[pos]
		if data.get("type", "") == room_type:
			return pos
	return Vector2i.ZERO

func _on_boss_died(boss = null):
	print("BOSS DIED")
	_on_boss_defeated()

func _on_boss_defeated():
	print("BOSS DEFEATED on floor ", GameManager.current_floor)
	AchievementManager.unlock("boss_slayer")
	if GameManager.current_floor >= 15:
		_game_victory()
	else:
		next_floor()

func _game_victory():
	print("=== VICTORY ===")
	AchievementManager.unlock("shutter_fate")
	# Create simple victory screen programmatically
	var victory_layer = CanvasLayer.new()
	victory_layer.name = "VictoryScreen"
	add_child(victory_layer)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.size = Vector2(1920, 1080)
	victory_layer.add_child(bg)
	
	var title = Label.new()
	title.text = "ПОБЕДА"
	title.position = Vector2(0, 200)
	title.size = Vector2(1920, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
	title.add_theme_constant_override("outline_size", 4)
	victory_layer.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Вы прошли все 15 этажей и победили Фотографа!"
	subtitle.position = Vector2(0, 320)
	subtitle.size = Vector2(1920, 60)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	victory_layer.add_child(subtitle)
	
	var stats = Label.new()
	stats.text = "Отпечатков: %d | Убийств: %d | Смертей: %d" % [GameManager.photo_prints, AchievementManager.total_kills, GameManager.total_deaths]
	stats.position = Vector2(0, 400)
	stats.size = Vector2(1920, 40)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1))
	victory_layer.add_child(stats)
	
	var hint = Label.new()
	hint.text = "[ESC] — Вернуться в Хаб"
	hint.position = Vector2(0, 500)
	hint.size = Vector2(1920, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	victory_layer.add_child(hint)
	
	# Pause game
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.1).timeout
	# Wait for ESC to return to hub
	while true:
		await get_tree().create_timer(0.1).timeout
		if Input.is_action_just_pressed("ui_cancel"):
			break
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/hub.tscn")

func update_floor_ui():
	var ui = get_node_or_null("FloorUI")
	if ui:
		var label = ui.get_node_or_null("FloorLabel")
		if label and floor_gen:
			var room_data = floor_gen.get_current_room_data()
			var room_type = room_data.get("type", "combat")
			var type_names = {"start": "Старт", "combat": "Бой", "elite": "Элита", "boss": "БОСС", "treasure": "Сокровище", "trap": "Ловушка", "puzzle": "Головоломка", "rest": "Отдых", "miniboss": "Минибосс", "gallery": "Галерея", "shop": "Магазин"}
			var type_str = type_names.get(room_type, "Бой")
			label.text = "Этаж: %d | %s" % [GameManager.current_floor, type_str]

func _is_near_any(pos: Vector2, positions: Array, min_dist: float) -> bool:
	for p in positions:
		if pos.distance_to(p) < min_dist:
			return true
	return false

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


func spawn_trap_room(room):
	print("TRAP ROOM")
	if room == null:
		return
	var room_data = floor_gen.get_current_room_data()
	if room_data.get("traps_spawned", false):
		return
	room_data["traps_spawned"] = true
	room_data["cleared"] = false

	# Create a labyrinth of traps
	var trap_count = 8 + randi() % 6
	var used_positions = []
	for i in range(trap_count):
		var trap = Area2D.new()
		trap.name = "Trap_%d" % i
		var pos = room.global_position + room.get_random_floor_position(2)
		while _is_near_any(pos, used_positions, 60):
			pos = room.global_position + room.get_random_floor_position(2)
		used_positions.append(pos)
		trap.global_position = pos

		var sprite = Sprite2D.new()
		sprite.name = "TrapSprite"
		sprite.texture = load("res://assets/floor_iso.png")
		sprite.modulate = Color(1.0, 0.15, 0.15, 0.9)
		sprite.scale = Vector2(0.7, 0.7)
		trap.add_child(sprite)

		var coll = CollisionShape2D.new()
		coll.shape = RectangleShape2D.new()
		coll.shape.size = Vector2(35, 35)
		trap.add_child(coll)

		trap.body_entered.connect(_on_trap_entered.bind(trap))
		add_child(trap)
		current_room_enemies.append(trap)

	# Deactivation terminal - spawn away from doors and traps
	var terminal = Area2D.new()
	terminal.name = "TrapTerminal"
	terminal.set_meta("deactivated", false)
	var term_pos = room.global_position
	if room.has_method("get_center"):
		term_pos += room.get_center() + Vector2(200, -100)
	else:
		term_pos += Vector2(200, -100)
	# Ensure terminal is not too close to any door or trap
	var min_door_dist = 150.0
	var min_trap_dist = 80.0
	var attempts = 0
	while attempts < 30:
		var too_close = false
		# Check distance to all doors
		for child in room.get_children():
			if child.name.begins_with("Door_"):
				if term_pos.distance_to(child.global_position) < min_door_dist:
					too_close = true
					break
		# Check distance to all traps
		if not too_close:
			for trap_pos in used_positions:
				if term_pos.distance_to(trap_pos) < min_trap_dist:
					too_close = true
					break
		if not too_close:
			break
		# Pick new position
		if room.has_method("get_random_floor_position"):
			term_pos = room.global_position + room.get_random_floor_position(2)
		else:
			term_pos = room.global_position + room.get_center() + Vector2(randf_range(-100, 100), randf_range(-80, 80))
		attempts += 1
	terminal.global_position = term_pos

	var term_sprite = Sprite2D.new()
	term_sprite.name = "TermSprite"
	term_sprite.texture = load("res://assets/floor_iso.png")
	term_sprite.modulate = Color(0.2, 0.8, 1.0, 1.0)
	term_sprite.scale = Vector2(1.0, 1.0)
	terminal.add_child(term_sprite)

	var term_coll = CollisionShape2D.new()
	term_coll.shape = RectangleShape2D.new()
	term_coll.shape.size = Vector2(50, 50)
	terminal.add_child(term_coll)

	var term_label = Label.new()
	term_label.name = "TermLabel"
	term_label.text = "[E] Деактивировать"
	term_label.position = Vector2(-60, -55)
	term_label.add_theme_font_size_override("font_size", 12)
	term_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0, 1))
	term_label.add_theme_constant_override("outline_size", 2)
	term_label.visible = false
	terminal.add_child(term_label)

	terminal.body_entered.connect(_on_terminal_entered.bind(terminal))
	terminal.body_exited.connect(_on_terminal_exited.bind(terminal))
	add_child(terminal)
	current_room_enemies.append(terminal)
	print("Trap room: ", trap_count, " traps + terminal spawned")

func spawn_puzzle_room(room):
	print("PUZZLE ROOM")
	if room == null:
		return
	var puzzle = Area2D.new()
	puzzle.set_meta("solved", false)
	var pos = room.global_position + room.get_center()
	if room.has_method("is_position_inside_floor") and not room.is_position_inside_floor(pos):
		pos = room.global_position + room.get_random_floor_position(3)
	puzzle.global_position = pos
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/floor_iso.png")
	sprite.modulate = Color(0.2, 0.7, 1.0, 1.0)
	sprite.scale = Vector2(1.2, 1.2)
	puzzle.add_child(sprite)
	var coll = CollisionShape2D.new()
	coll.shape = RectangleShape2D.new()
	coll.shape.size = Vector2(50, 50)
	puzzle.add_child(coll)
	var label = Label.new()
	label.name = "Label"
	label.text = "[E] Головоломка"
	label.position = Vector2(-50, -50)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0, 1))
	puzzle.add_child(label)
	puzzle.body_entered.connect(_on_puzzle_area_entered.bind(puzzle))
	puzzle.body_exited.connect(_on_puzzle_area_exited.bind(puzzle))
	add_child(puzzle)
	current_puzzle_object = puzzle

func _on_terminal_entered(body, terminal):
	if not body.is_in_group("player"):
		return
	var label = terminal.get_node_or_null("TermLabel")
	if label:
		label.visible = true
	terminal.set_meta("player_near", true)

func _on_terminal_exited(body, terminal):
	if not body.is_in_group("player"):
		return
	var label = terminal.get_node_or_null("TermLabel")
	if label:
		label.visible = false
	terminal.set_meta("player_near", false)

func _process(delta):
	# Trap terminal interaction
	for child in get_children():
		if child.name == "TrapTerminal" and child.get_meta("player_near", false):
			if not child.get_meta("deactivated", false) and (Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_E)):
				_deactivate_trap_room(child)
	# Puzzle interaction
	if current_puzzle_object and current_puzzle_object.get_meta("player_near", false):
		if not puzzle_active and not current_puzzle_object.get_meta("solved", false):
			if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
				_open_puzzle_ui(current_puzzle_object)
	# NPC encounter interaction
	for child in get_children():
		if child.name.begins_with("NPCEncounter_") and child.get_meta("player_near", false):
			if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
				_interact_npc_encounter(child)

func _deactivate_trap_room(terminal):
	terminal.set_meta("deactivated", true)
	var label = terminal.get_node_or_null("TermLabel")
	if label:
		label.text = "ДЕАКТИВИРОВАНО"
		label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3, 1))
	var sprite = terminal.get_node_or_null("TermSprite")
	if sprite:
		sprite.modulate = Color(0.2, 1.0, 0.3, 1.0)
	for child in get_children():
		if child.name.begins_with("Trap_"):
			var trap_sprite = child.get_node_or_null("TrapSprite")
			if trap_sprite:
				trap_sprite.modulate = Color(0.3, 0.3, 0.3, 0.3)
			child.body_entered.disconnect(_on_trap_entered)
	var room_data = floor_gen.get_current_room_data()
	room_data["cleared"] = true
	unlock_doors()
	print("Trap room deactivated!")

func spawn_rest_room(room):
	print("REST ROOM")
	if room == null:
		return
	var rest = Area2D.new()
	rest.set_meta("used", false)
	var pos = room.global_position + room.get_center()
	if room.has_method("is_position_inside_floor") and not room.is_position_inside_floor(pos):
		pos = room.global_position + room.get_random_floor_position(3)
	rest.global_position = pos
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/floor_iso.png")
	sprite.modulate = Color(0.2, 1.0, 0.3, 1.0)
	sprite.scale = Vector2(1.2, 1.2)
	rest.add_child(sprite)
	var coll = CollisionShape2D.new()
	coll.shape = RectangleShape2D.new()
	coll.shape.size = Vector2(50, 50)
	rest.add_child(coll)
	var label = Label.new()
	label.text = "[E] Отдохнуть"
	label.position = Vector2(-50, -50)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3, 1))
	rest.add_child(label)
	rest.body_entered.connect(_on_rest_entered.bind(rest))
	add_child(rest)

func spawn_miniboss_room(room):
	print("MINIBOSS ROOM")
	if room == null:
		return
	var spawn_pos = room.global_position + room.get_center()
	if room.has_method("is_position_inside_floor") and not room.is_position_inside_floor(spawn_pos):
		spawn_pos = room.global_position + room.get_random_floor_position(3)
	var scene = _pick_enemy_scene()
	if scene == null:
		print("ERROR: no enemy scene for miniboss")
		return
	var enemy = scene.instantiate()
	enemy.global_position = spawn_pos
	enemy.is_elite = true
	enemy.max_hp = int(enemy.max_hp * 2.5)
	enemy.hp = enemy.max_hp
	enemy.attack_damage = int(enemy.attack_damage * 1.5)
	if enemy.has_node("Sprite2D"):
		enemy.get_node("Sprite2D").modulate = Color(1.0, 0.2, 0.2, 1.0)
		enemy.get_node("Sprite2D").scale *= 1.5
	add_child(enemy)
	current_room_enemies.append(enemy)
	enemies_alive += 1
	enemy.tree_exited.connect(_on_enemy_died)
	print("MINIBOSS spawned")

func spawn_gallery_room(room):
	print("GALLERY ROOM")
	if room == null:
		return
	for i in range(2):
		spawn_enemy_in_room(room, 1)
	var chest = Area2D.new()
	var chest_pos = room.global_position + room.get_random_floor_position(3)
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
	print("Gallery chest spawned")

func _on_trap_entered(body, trap):
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(5)
		print("Trap hit! -5 HP")
	var sprite = trap.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(1.0, 0.5, 0.5, 0.4)

func _on_puzzle_area_entered(body, puzzle):
	if not body.is_in_group("player"):
		return
	puzzle.set_meta("player_near", true)
	var label = puzzle.get_node_or_null("Label")
	if label:
		label.visible = true

func _on_puzzle_area_exited(body, puzzle):
	if not body.is_in_group("player"):
		return
	puzzle.set_meta("player_near", false)
	var label = puzzle.get_node_or_null("Label")
	if label:
		label.visible = false

func _open_puzzle_ui(puzzle_obj):
	if puzzle_active:
		return
	if puzzle_obj.get_meta("solved", false):
		return
	puzzle_active = true
	var ui = load("res://scripts/puzzle_ui.gd").new()
	ui.puzzle_solved.connect(_on_puzzle_solved.bind(puzzle_obj))
	ui.puzzle_cancelled.connect(_on_puzzle_cancelled)
	add_child(ui)

func _on_puzzle_solved(puzzle_obj):
	puzzle_active = false
	puzzle_obj.set_meta("solved", true)
	var label = puzzle_obj.get_node_or_null("Label")
	if label:
		label.text = "РЕШЕНО!"
		label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3, 1))
	var sprite = puzzle_obj.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(0.2, 1.0, 0.3, 1.0)
	GameManager.photo_prints += 25
	AchievementManager.check_all()
	var room_data = floor_gen.get_current_room_data()
	room_data["cleared"] = true
	unlock_doors()
	print("Puzzle solved! +25 prints")

func _on_puzzle_cancelled():
	puzzle_active = false
	print("Puzzle cancelled")

func _on_rest_entered(body, rest):
	if not body.is_in_group("player"):
		return
	if rest.get_meta("used", false):
		return
	rest.set_meta("used", true)
	if "hp" in body and "max_hp" in body:
		body.hp = min(body.hp + 30, body.max_hp)
		if body.has_method("update_ui"):
			body.update_ui()
	var label = rest.get_node_or_null("Label")
	if label:
		label.text = "ВОССТАНОВЛЕНО"
		label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3, 1))
	print("Rest: +30 HP")
	var room_data = floor_gen.get_current_room_data()
	room_data["cleared"] = true
	unlock_doors()
