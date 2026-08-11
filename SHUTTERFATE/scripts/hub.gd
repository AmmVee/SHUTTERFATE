extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera_desk: Area2D = $CameraDesk
@onready var npc_area: Area2D = $NPCArea

var player_scene = preload("res://scenes/player.tscn")
var player: Node2D = null

func _ready():
	# Sync relics from GameManager
	RelicManager.owned_relics = GameManager.owned_relics.duplicate()
	RelicManager.equipped_relics = GameManager.equipped_relics.duplicate()

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
	create_relic_ui()

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

var upgrade_panel_open: bool = false
var shop_panel_open: bool = false
var npc_menu_open: bool = false

func talk_to_npc():
	if upgrade_panel_open or shop_panel_open or npc_menu_open:
		return
	create_npc_menu()

func create_npc_menu():
	npc_menu_open = true
	var canvas = get_node_or_null("CanvasLayer")
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "CanvasLayer"
		add_child(canvas)

	var panel = ColorRect.new()
	panel.name = "NPCMenuPanel"
	panel.color = Color(0.05, 0.05, 0.08, 0.95)
	panel.position = Vector2(660, 350)
	panel.size = Vector2(600, 300)
	canvas.add_child(panel)

	var title = Label.new()
	title.text = "ТЁМНАЯ КОМНАТА"
	title.position = Vector2(0, 20)
	title.size = Vector2(600, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6, 1))
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Отпечатки: %d" % GameManager.photo_prints
	subtitle.position = Vector2(0, 60)
	subtitle.size = Vector2(600, 25)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6, 1))
	panel.add_child(subtitle)

	var btn_y = 110
	var btn_w = 400
	var btn_h = 50
	var btn_x = (600 - btn_w) / 2

	var btn_upg = Button.new()
	btn_upg.text = "АПГРЕЙДЫ КАМЕРЫ"
	btn_upg.position = Vector2(btn_x, btn_y)
	btn_upg.size = Vector2(btn_w, btn_h)
	btn_upg.add_theme_font_size_override("font_size", 16)
	btn_upg.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 1))
	btn_upg.pressed.connect(func(): close_npc_menu(); create_upgrade_ui())
	panel.add_child(btn_upg)

	var btn_shop = Button.new()
	btn_shop.text = "МАГАЗИН РЕЛИКВИЙ"
	btn_shop.position = Vector2(btn_x, btn_y + 60)
	btn_shop.size = Vector2(btn_w, btn_h)
	btn_shop.add_theme_font_size_override("font_size", 16)
	btn_shop.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1))
	btn_shop.pressed.connect(func(): close_npc_menu(); create_shop_ui())
	panel.add_child(btn_shop)

	var btn_close = Button.new()
	btn_close.text = "УЙТИ"
	btn_close.position = Vector2(btn_x, btn_y + 130)
	btn_close.size = Vector2(btn_w, btn_h)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1))
	btn_close.pressed.connect(close_npc_menu)
	panel.add_child(btn_close)

func close_npc_menu():
	npc_menu_open = false
	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		var panel = canvas.get_node_or_null("NPCMenuPanel")
		if panel:
			panel.queue_free()

func create_shop_ui():
	shop_panel_open = true

	# Regenerate shop if needed
	if not GameManager.shop_regenerated or GameManager.shop_inventory.size() == 0:
		GameManager.regenerate_shop()

	var canvas = get_node_or_null("CanvasLayer")
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "CanvasLayer"
		add_child(canvas)

	var panel = ColorRect.new()
	panel.name = "ShopPanel"
	panel.color = Color(0.05, 0.05, 0.08, 0.95)
	panel.position = Vector2(460, 200)
	panel.size = Vector2(1000, 700)
	canvas.add_child(panel)

	var title = Label.new()
	title.text = "МАГАЗИН РЕЛИКВИЙ"
	title.position = Vector2(0, 20)
	title.size = Vector2(1000, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
	title.add_theme_constant_override("outline_size", 4)
	panel.add_child(title)

	var prints = Label.new()
	prints.text = "Отпечатки: %d" % GameManager.photo_prints
	prints.position = Vector2(0, 70)
	prints.size = Vector2(1000, 30)
	prints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prints.add_theme_font_size_override("font_size", 18)
	prints.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6, 1))
	panel.add_child(prints)

	# Show 3 shop slots
	var start_x = 120
	var gap = 300
	for i in range(3):
		var slot_x = start_x + i * gap

		if i < GameManager.shop_inventory.size():
			var id = GameManager.shop_inventory[i]
			var relic = RelicManager.get_relic(id)
			var price = GameManager.get_relic_price(relic.rarity) if relic else 0
			var can_afford = GameManager.photo_prints >= price

			var btn = Button.new()
			btn.name = "ShopSlot_%d" % i
			btn.position = Vector2(slot_x, 150)
			btn.size = Vector2(260, 400)
			btn.add_theme_font_size_override("font_size", 13)
			btn.text = "%s

%s

Редкость: %s
Цена: %d" % [
				relic.display_name, relic.description, relic.rarity, price
			]
			if can_afford:
				btn.add_theme_color_override("font_color", relic.rarity_color)
			else:
				btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
				btn.disabled = true
			btn.pressed.connect(_on_buy_relic.bind(i))
			panel.add_child(btn)
		else:
			var empty = Label.new()
			empty.text = "ПУСТО"
			empty.position = Vector2(slot_x + 80, 300)
			empty.size = Vector2(100, 30)
			empty.add_theme_font_size_override("font_size", 14)
			empty.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
			panel.add_child(empty)

	# Regenerate button
	var regen = Button.new()
	regen.text = "ОБНОВИТЬ АССОРТИМЕНТ (100 отпечатков)"
	regen.position = Vector2(250, 580)
	regen.size = Vector2(500, 40)
	regen.add_theme_font_size_override("font_size", 14)
	if GameManager.photo_prints >= 100:
		regen.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
		regen.pressed.connect(_on_regen_shop)
	else:
		regen.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		regen.disabled = true
	panel.add_child(regen)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "ЗАКРЫТЬ"
	close_btn.position = Vector2(350, 640)
	close_btn.size = Vector2(300, 40)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1))
	close_btn.pressed.connect(close_shop_ui)
	panel.add_child(close_btn)

func _on_buy_relic(index: int):
	if GameManager.buy_relic_from_shop(index):
		close_shop_ui()
		create_shop_ui()  # Refresh
		print("Bought relic from shop")

func _on_regen_shop():
	if GameManager.photo_prints >= 100:
		GameManager.photo_prints -= 100
		GameManager.regenerate_shop()
		close_shop_ui()
		create_shop_ui()
		print("Shop regenerated")

func close_shop_ui():
	shop_panel_open = false
	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		var panel = canvas.get_node_or_null("ShopPanel")
		if panel:
			panel.queue_free()

func create_upgrade_ui():
	upgrade_panel_open = true
	var canvas = get_node_or_null("CanvasLayer")
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "CanvasLayer"
		add_child(canvas)

	# Background panel
	var panel = ColorRect.new()
	panel.name = "UpgradePanel"
	panel.color = Color(0.05, 0.05, 0.08, 0.95)
	panel.position = Vector2(460, 200)
	panel.size = Vector2(1000, 700)
	canvas.add_child(panel)

	# Title
	var title = Label.new()
	title.name = "UpgradeTitle"
	title.text = "АПГРЕЙДЫ КАМЕРЫ"
	title.position = Vector2(0, 20)
	title.size = Vector2(1000, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6, 1))
	title.add_theme_constant_override("outline_size", 4)
	panel.add_child(title)

	# Prints count
	var prints_label = Label.new()
	prints_label.name = "UpgradePrints"
	prints_label.text = "Отпечатки: %d" % GameManager.photo_prints
	prints_label.position = Vector2(0, 70)
	prints_label.size = Vector2(1000, 30)
	prints_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prints_label.add_theme_font_size_override("font_size", 18)
	prints_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6, 1))
	panel.add_child(prints_label)

	# Upgrade buttons
	var ids = ["damage", "hp", "reload", "frames", "speed", "range"]
	var positions = [
		Vector2(80, 120), Vector2(370, 120), Vector2(660, 120),
		Vector2(80, 340), Vector2(370, 340), Vector2(660, 340)
	]

	for i in range(ids.size()):
		var id = ids[i]
		var up = GameManager.camera_upgrades[id]
		var btn = Button.new()
		btn.name = "UpgradeBtn_%s" % id
		btn.position = positions[i]
		btn.size = Vector2(260, 200)
		btn.add_theme_font_size_override("font_size", 14)

		var level = up.level
		var max_level = up.max
		var can_buy = GameManager.can_upgrade(id)

		btn.text = "%s
Уровень: %d/%d
%s
" % [up.name, level, max_level, up.desc]
		if level < max_level:
			btn.text += "Стоимость: %d отпечатков" % up.costs[level]
		else:
			btn.text += "МАКСИМУМ"

		if can_buy:
			btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3, 1))
		elif level >= max_level:
			btn.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1))
		else:
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
			btn.disabled = true

		btn.pressed.connect(_on_upgrade_pressed.bind(id))
		panel.add_child(btn)

	# Close button
	var close_btn = Button.new()
	close_btn.name = "UpgradeCloseBtn"
	close_btn.text = "ЗАКРЫТЬ"
	close_btn.position = Vector2(350, 620)
	close_btn.size = Vector2(300, 50)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1))
	close_btn.pressed.connect(close_upgrade_ui)
	panel.add_child(close_btn)

func _on_upgrade_pressed(id: String):
	if GameManager.buy_upgrade(id):
		close_upgrade_ui()
		create_upgrade_ui()  # Refresh
		print("Purchased upgrade: ", id)

func close_upgrade_ui():
	upgrade_panel_open = false
	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		var panel = canvas.get_node_or_null("UpgradePanel")
		if panel:
			panel.queue_free()
	# Return to NPC menu
	create_npc_menu()

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
		if child.name.begins_with("FilmBtn") or child.name == "FilmTitle" or child.name == "FilmSelector" or child.name.begins_with("FilmDesc") or child.name.begins_with("FilmRarity"):
			child.queue_free()

	var title = Label.new()
	title.name = "FilmTitle"
	title.text = "ВЫБЕРИТЕ ПЛЁНКУ"
	title.position = Vector2(760, 680)
	title.size = Vector2(400, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6, 1))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.05, 1))
	title.add_theme_constant_override("outline_size", 4)
	canvas.add_child(title)

	var films = GameManager.unlocked_films
	var btn_width = 140
	var gap = 20
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
		btn.position = Vector2(start_x + i * (btn_width + gap), 730)
		btn.size = Vector2(btn_width, 55)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))

		# Rarity border color
		var rarity_col = film.rarity_color if film else Color.WHITE
		btn.add_theme_color_override("font_color", rarity_col)

		if FilmManager.current_film and FilmManager.current_film.film_id == film_id:
			btn.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
			btn.add_theme_color_override("font_pressed_color", Color(1, 0.7, 0.1, 1))

		btn.pressed.connect(_on_film_selected.bind(film_id))
		canvas.add_child(btn)

		# Rarity label below button
		var rarity_label = Label.new()
		rarity_label.name = "FilmRarity_%d" % i
		rarity_label.text = _rarity_name(film.rarity)
		rarity_label.position = Vector2(start_x + i * (btn_width + gap), 790)
		rarity_label.size = Vector2(btn_width, 20)
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_label.add_theme_font_size_override("font_size", 11)
		rarity_label.add_theme_color_override("font_color", film.rarity_color)
		rarity_label.add_theme_constant_override("outline_size", 2)
		canvas.add_child(rarity_label)

		# Description label
		var desc_label = Label.new()
		desc_label.name = "FilmDesc_%d" % i
		desc_label.text = "%d кадр. | %s" % [film.max_frames, film.description]
		desc_label.position = Vector2(start_x + i * (btn_width + gap), 812)
		desc_label.size = Vector2(btn_width, 50)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		canvas.add_child(desc_label)

func _rarity_name(rarity: String) -> String:
	match rarity:
		"white": return "Обычная"
		"green": return "Необычная"
		"blue": return "Редкая"
		"purple": return "Эпическая"
		"yellow": return "Легендарная"
		"red": return "Мифическая"
		"gold": return "Уникальная"
		_: return "???"

func _on_film_selected(film_id: String):
	FilmManager.set_film(film_id)
	create_film_selector()
	print("Selected film: ", film_id)

# ========== RELIC UI ==========

func create_relic_ui():
	var canvas = get_node_or_null("CanvasLayer")
	if canvas == null:
		return

	for child in canvas.get_children():
		if child.name.begins_with("Relic"):
			child.queue_free()

	var title = Label.new()
	title.name = "RelicTitle"
	title.text = "РЕЛИКВИИ (экипировано %d/%d)" % [RelicManager.equipped_relics.size(), RelicManager.MAX_EQUIPPED]
	title.position = Vector2(50, 880)
	title.size = Vector2(400, 30)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1))
	title.add_theme_constant_override("outline_size", 3)
	canvas.add_child(title)

	# Show equipped relics
	for i in range(RelicManager.equipped_relics.size()):
		var rid = RelicManager.equipped_relics[i]
		var r = RelicManager.get_relic(rid)
		if r == null:
			continue
		var label = Label.new()
		label.name = "RelicEquipped_%d" % i
		label.text = "• %s" % r.display_name
		label.position = Vector2(50, 910 + i * 22)
		label.size = Vector2(350, 20)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", r.rarity_color)
		label.add_theme_constant_override("outline_size", 2)
		canvas.add_child(label)

	# Show owned but not equipped
	var y_off = 910 + RelicManager.equipped_relics.size() * 22 + 10
	var unequipped = []
	for rid in RelicManager.owned_relics:
		if rid not in RelicManager.equipped_relics:
			unequipped.append(rid)

	if unequipped.size() > 0:
		var sub = Label.new()
		sub.name = "RelicSubTitle"
		sub.text = "В инвентаре:"
		sub.position = Vector2(50, y_off)
		sub.size = Vector2(300, 20)
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		canvas.add_child(sub)
		y_off += 20

		for i in range(unequipped.size()):
			var rid = unequipped[i]
			var r = RelicManager.get_relic(rid)
			if r == null:
				continue
			var btn = Button.new()
			btn.name = "RelicBtn_%d" % i
			btn.text = "+ %s" % r.display_name
			btn.position = Vector2(50, y_off + i * 28)
			btn.size = Vector2(200, 24)
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", r.rarity_color)
			btn.pressed.connect(_on_equip_relic.bind(rid))
			canvas.add_child(btn)

	# Unequip buttons
	if RelicManager.equipped_relics.size() > 0:
		var y_uneq = 910
		for i in range(RelicManager.equipped_relics.size()):
			var rid = RelicManager.equipped_relics[i]
			var btn = Button.new()
			btn.name = "RelicUnequip_%d" % i
			btn.text = "×"
			btn.position = Vector2(10, y_uneq + i * 22)
			btn.size = Vector2(30, 20)
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
			btn.pressed.connect(_on_unequip_relic.bind(rid))
			canvas.add_child(btn)

func _on_equip_relic(relic_id: String):
	RelicManager.equip(relic_id)
	create_relic_ui()

func _on_unequip_relic(relic_id: String):
	RelicManager.unequip(relic_id)
	create_relic_ui()
