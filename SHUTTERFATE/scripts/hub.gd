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

	if camera_desk:
		camera_desk.body_entered.connect(_on_camera_desk_entered)
		camera_desk.body_exited.connect(_on_camera_desk_exited)

	if npc_area:
		npc_area.body_entered.connect(_on_npc_entered)
		npc_area.body_exited.connect(_on_npc_exited)

	show_hub_ui()

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

	stats.text = "Отпечатки: %d
Смертей: %d
Убийств: %d" % [GameManager.prints, GameManager.total_deaths, GameManager.total_kills]
