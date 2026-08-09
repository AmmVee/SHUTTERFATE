extends Node2D

@export var enemy_scene: PackedScene
@export var enemy_grain_scene: PackedScene
@export var rooms_per_floor: int = 3

var room_gen: Node2D = null
var enemies_alive: int = 0
var door_open: bool = false
var door_node: Area2D = null
var current_room_enemies: Array = []
var door_label: Label = null

func _ready():
	# Init GameManager on first run
	if GameManager.current_room == 0:
		GameManager.current_room = 1
		GameManager.current_floor = 1

	generate_current_room()

func generate_current_room():
	# Clear old room
	if room_gen != null and is_instance_valid(room_gen):
		room_gen.queue_free()
		room_gen = null

	# Clear old enemies
	for e in current_room_enemies:
		if is_instance_valid(e):
			e.queue_free()
	current_room_enemies.clear()
	enemies_alive = 0

	# Clear old door
	if door_node != null and is_instance_valid(door_node):
		door_node.queue_free()
		door_node = null

	door_open = false

	# Generate new room
	room_gen = Node2D.new()
	room_gen.name = "RoomGenerator"
	room_gen.set_script(load("res://scripts/room_generator.gd"))
	add_child(room_gen)

	# Wait for room generation
	await get_tree().process_frame

	# Move player to room center
	var player = get_tree().get_first_node_in_group("player")
	if player and room_gen and room_gen.has_method("get_center"):
		player.global_position = room_gen.get_center()
	elif player:
		player.global_position = Vector2.ZERO

	# Spawn enemies
	var is_boss_room = (GameManager.current_floor % 5 == 0) and (GameManager.current_room == rooms_per_floor)
	if is_boss_room:
		spawn_boss_room()
	else:
		var enemy_count = 3 + GameManager.current_floor
		for i in range(enemy_count):
			spawn_enemy()

	# Create door at random position inside room
	create_door()

	# Update UI
	update_floor_ui()

func spawn_boss_room():
	print("BOSS ROOM — Floor ", GameManager.current_floor, " | Room ", GameManager.current_room)
	# Placeholder: spawn stronger enemies for now
	for i in range(2):
		spawn_enemy()
	# TODO: Spawn actual boss

func spawn_enemy():
	if enemies_alive >= 20:
		return

	var pos = Vector2.ZERO
	if room_gen and room_gen.has_method("get_random_floor_position"):
		pos = room_gen.get_random_floor_position()
	else:
		pos = Vector2(randf_range(-200, 200), randf_range(-150, 150))

	# Keep away from player spawn
	var player = get_tree().get_first_node_in_group("player")
	if player and pos.distance_to(player.global_position) < 120:
		pos = player.global_position + Vector2(randf_range(150, 300) * (1 if randf() > 0.5 else -1), randf_range(100, 250) * (1 if randf() > 0.5 else -1))

	var scene = enemy_scene
	if enemy_grain_scene != null and randf() < 0.3:
		scene = enemy_grain_scene

	if scene == null:
		return

	var enemy = scene.instantiate()
	enemy.global_position = pos
	add_child(enemy)
	current_room_enemies.append(enemy)
	enemies_alive += 1
	enemy.tree_exited.connect(_on_enemy_died)

func _on_enemy_died():
	enemies_alive = max(enemies_alive - 1, 0)
	check_door()

func create_door():
	door_node = Area2D.new()
	door_node.name = "DoorArea"

	# Random position inside room, near top edge
	var door_pos = Vector2(randf_range(-120, 120), -180)
	if room_gen and room_gen.has_method("get_random_floor_position"):
		door_pos = room_gen.get_random_floor_position()
		# Push to upper area of room
		door_pos.y = -180 + randf_range(-20, 20)
		door_pos.x = clamp(door_pos.x, -180, 180)

	door_node.position = door_pos

	var sprite = Sprite2D.new()
	sprite.name = "DoorSprite"
	sprite.texture = load("res://assets/hub_door.png")
	sprite.offset = Vector2(0, -16)
	sprite.modulate = Color(0.3, 0.8, 0.3, 0.5)
	door_node.add_child(sprite)

	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(48, 32)
	shape.position = Vector2(0, -8)
	door_node.add_child(shape)

	# Door label as child of door
	door_label = Label.new()
	door_label.name = "DoorLabel"
	door_label.text = "[Враги живы]"
	door_label.position = Vector2(-40, -50)
	door_label.add_theme_font_size_override("font_size", 14)
	door_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5, 1))
	door_label.add_theme_constant_override("outline_size", 2)
	door_node.add_child(door_label)

	door_node.body_entered.connect(_on_door_entered)
	add_child(door_node)

func check_door():
	if enemies_alive <= 0 and not door_open:
		door_open = true
		if door_node:
			var sprite = door_node.get_node_or_null("DoorSprite")
			if sprite:
				# Flash green
				var tween = create_tween()
				tween.tween_property(sprite, "modulate", Color(0.5, 1.0, 0.5, 1.0), 0.4)
				tween.tween_property(sprite, "modulate", Color(0.3, 0.9, 0.3, 1.0), 0.4)
				tween.set_loops(4)

			var label = door_node.get_node_or_null("DoorLabel")
			if label:
				label.text = "[E] Следующая комната"
				label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))

		print("Door opened! All enemies defeated.")

func _on_door_entered(body):
	if body.is_in_group("player") and door_open:
		# Use call_deferred to avoid physics callback crash
		call_deferred("advance_room")

func advance_room():
	GameManager.current_room += 1
	if GameManager.current_room > rooms_per_floor:
		GameManager.current_floor += 1
		GameManager.current_room = 1
		print("=== NEW FLOOR: ", GameManager.current_floor, " ===")

	print("Advancing to Floor ", GameManager.current_floor, " Room ", GameManager.current_room)

	# Regenerate room (player will be moved to center)
	generate_current_room()

func update_floor_ui():
	var ui = get_node_or_null("FloorUI")
	if ui:
		var label = ui.get_node_or_null("FloorLabel")
		if label:
			label.text = "Этаж: %d | Комната: %d" % [GameManager.current_floor, GameManager.current_room]

func _physics_process(_delta):
	# Safety: if player falls too far, teleport back
	var player = get_tree().get_first_node_in_group("player")
	if player and player.global_position.distance_to(Vector2.ZERO) > 3000:
		if room_gen and room_gen.has_method("get_center"):
			player.global_position = room_gen.get_center()
		else:
			player.global_position = Vector2.ZERO
