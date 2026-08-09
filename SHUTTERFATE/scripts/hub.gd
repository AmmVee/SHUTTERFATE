extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera_desk: Area2D = $CameraDesk
@onready var npc_area: Area2D = $NPCArea

var player_scene = preload("res://scenes/player.tscn")
var player: Node2D = null

func _ready():
	player = player_scene.instantiate()
	player.global_position = player_spawn.global_position
	add_child(player)

	var player_canvas = player.get_node_or_null("CanvasLayer")
	if player_canvas:
		player_canvas.visible = false

	if camera_desk:
		camera_desk.body_entered.connect(_on_camera_desk_entered)
		camera_desk.body_exited.connect(_on_camera_desk_exited)
	if npc_area:
		npc_area.body_entered.connect(_on_npc_entered)
		npc_area.body_exited.connect(_on_npc_exited)

	show_hub_ui()
	create_film_selector()

var near_desk: bool = false
var near_npc: bool = false

func _physics_process(_delta):
	if near_desk and Input.is_action_just_pressed("ui_accept"):
		start_run()
	if near_npc and Input.is_action_just_pressed("ui_accept"):
		talk_to_npc()

func _on_camera_desk_entered(body):
	if body.is_in_group("player"):
		near_desk = true
		show_prompt("[E] Начать забег")

func _on_camera_desk_exited(body):
	if body.is_in_group("player"):
		near_desk = false
		hide_prompt()

func _on_npc_entered(body):
	if body.is_in_group("player"):
		near_npc = true
		show_prompt("[E] Поговорить")

func _on_npc_exited(body):
	if body.is_in_group("player"):
		near_npc = false
		hide_prompt()

func start_run():
	print("Entering the Obscura...")
	GameManager.start_run()

func talk_to_npc():
	print("NPC: 'Ты снова здесь? Плёнка ждёт. Не задерживайся в кадре слишком долго...'")

func show_prompt(text: String):
	var label = get_node_or_null("CanvasLayer/PromptLabel")
	if label:
		label.text = text
		label.visible = true

func hide_prompt():
	var label = get_node_or_null("CanvasLayer/PromptLabel")
	if label:
		label.visible = false

func show_hub_ui():
	var canvas = get_node_or_null("CanvasLayer")
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "CanvasLayer"
		add_child(canvas)

	var label = canvas.get_node_or_null("PromptLabel")
	if label == null:
		label = Label.new()
		label.name = "PromptLabel"
		label.anchors_preset = Control.PRESET_CENTER_BOTTOM
		label.offset_top = -80
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 4)
		label.visible = false
		canvas.add_child(label)

	var stats = canvas.get_node_or_null("StatsLabel")
	if stats == null:
		stats = Label.new()
		stats.name = "StatsLabel"
		stats.position = Vector2(20, 20)
		stats.add_theme_font_size_override("font_size", 16)
		stats.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		stats.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		stats.add_theme_constant_override("outline_size", 3)
		canvas.add_child(stats)

	stats.text = "Отпечатки: %d\nСмертей: %d\nУбийств: %d" % [GameManager.photo_prints, GameManager.total_deaths, GameManager.total_kills]

func create_film_selector():
	var canvas = get_node_or_null("CanvasLayer")
	if canvas == null:
		return

	for child in canvas.get_children():
		if child.name.begins_with("FilmBtn") or child.name == "FilmTitle" or child.name == "FilmSelector":
			child.queue_free()

	var title = Label.new()
	title.name = "FilmTitle"
	title.text = "ВЫБЕРИТЕ ПЛЁНКУ"
	title.position = Vector2(760, 720)
	title.size = Vector2(400, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6, 1))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.05, 1))
	title.add_theme_constant_override("outline_size", 4)
	canvas.add_child(title)

	var films = GameManager.unlocked_films
	var btn_width = 120
	var gap = 16
	var total_width = films.size() * btn_width + (films.size() - 1) * gap
	var start_x = (1920 - total_width) / 2.0

	for i in range(films.size()):
		var film_id = films[i]
		var film = FilmManager.get_film(film_id)
		if film == null:
			continue

		var btn = Button.new()
		btn.name = "FilmBtn_%d" % i
		btn.text = film.display_name
		btn.position = Vector2(start_x + i * (btn_width + gap), 770)
		btn.size = Vector2(btn_width, 65)
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))

		if FilmManager.current_film and FilmManager.current_film.film_id == film_id:
			btn.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
			btn.add_theme_color_override("font_pressed_color", Color(1, 0.7, 0.1, 1))

		btn.pressed.connect(_on_film_selected.bind(film_id))
		canvas.add_child(btn)

func _on_film_selected(film_id: String):
	FilmManager.set_film(film_id)
	create_film_selector()
	print("Selected film: ", film_id)
