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

	# Dev menu
	var dev_menu = load("res://scripts/dev_menu.gd")
	if dev_menu:
		var dm = CanvasLayer.new()
		dm.set_script(dev_menu)
		dm.name = "DevMenu"
		add_child(dm)
		print("Dev menu loaded in hub (F1)")

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
	if GameManager.pacts_unlocked:
		create_pact_selector()
	else:
		GameManager.start_run()

var pact_selector_open: bool = false

func create_pact_selector():
	pact_selector_open = true
	var canvas = get_node_or_null("CanvasLayer")
	if canvas == null:
		return

	var panel = ColorRect.new()
	panel.name = "PactPanel"
	panel.color = Color(0.05, 0.05, 0.08, 0.95)
	panel.position = Vector2(460, 150)
	panel.size = Vector2(1000, 700)
	canvas.add_child(panel)

	var title = Label.new()
	title.text = "УСЛОВИЯ ЗАБЕГА"
	title.position = Vector2(0, 20)
	title.size = Vector2(1000, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
	title.add_theme_constant_override("outline_size", 4)
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Выберите до %d условий. Каждое увеличивает награду." % GameManager.max_pacts
	subtitle.position = Vector2(0, 70)
	subtitle.size = Vector2(1000, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5, 1))
	panel.add_child(subtitle)

	var start_y = 130
	var gap = 130
	var idx = 0
	for pact_id in GameManager.PACTS.keys():
		var pact = GameManager.PACTS[pact_id]
		var is_active = GameManager.has_pact(pact_id)

		var btn = Button.new()
		btn.name = "PactBtn_%s" % pact_id
		btn.position = Vector2(100, start_y + idx * gap)
		btn.size = Vector2(800, 110)
		btn.add_theme_font_size_override("font_size", 14)
		btn.text = "%s%s\n%s\nБонус: +%d%% отпечатков" % [
			"[✓] " if is_active else "[ ] ",
			pact.name,
			pact.desc,
			int(pact.bonus * 100)
		]
		btn.add_theme_color_override("font_color", pact.color if is_active else Color(0.5, 0.5, 0.5, 1))
		btn.pressed.connect(_on_toggle_pact.bind(pact_id))
		panel.add_child(btn)
		idx += 1

	# Start button
	var btn_start = Button.new()
	btn_start.text = "НАЧАТЬ ЗАБЕГ"
	btn_start.position = Vector2(300, 650)
	btn_start.size = Vector2(400, 50)
	btn_start.add_theme_font_size_override("font_size", 18)
	btn_start.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
	btn_start.pressed.connect(_on_confirm_pacts)
	panel.add_child(btn_start)

func _on_toggle_pact(pact_id: String):
	GameManager.toggle_pact(pact_id)
	close_pact_selector()
	create_pact_selector()

func close_pact_selector():
	pact_selector_open = false
	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		var panel = canvas.get_node_or_null("PactPanel")
		if panel:
			panel.queue_free()

func _on_confirm_pacts():
	close_pact_selector()
	GameManager.start_run()

var upgrade_panel_open: bool = false
var shop_panel_open: bool = false
var npc_menu_open: bool = false

func _on_achievements():
	close_all_panels()
	create_achievements_ui()

func _on_daily_challenge():
	close_all_panels()
	create_daily_challenge_ui()

func _on_toggle_coop():
	GameManager.coop_mode = not GameManager.coop_mode
	close_all_panels()
	create_npc_menu()

func _on_gallery_hub():
	close_all_panels()
	var editor = CanvasLayer.new()
	editor.set_script(load("res://scripts/photo_editor.gd"))
	editor.name = "PhotoEditor"
	editor.snapshot_data = {"boss_name": "", "floor": 0, "date": ""}
	add_child(editor)
	# Call gallery directly
	await get_tree().create_timer(0.1).timeout
	var pe = get_node_or_null("PhotoEditor")
	if pe and pe.has_method("create_gallery_ui"):
		pe.create_gallery_ui()

func create_daily_challenge_ui():
	var canvas = get_node_or_null("CanvasLayer")
	if canvas == null:
		return
	
	var panel = ColorRect.new()
	panel.name = "DailyChallengePanel"
	panel.color = Color(0.05, 0.05, 0.08, 0.95)
	panel.position = Vector2(460, 150)
	panel.size = Vector2(1000, 600)
	canvas.add_child(panel)
	
	var ch = DailyChallengeManager.get_challenge()
	
	var title = Label.new()
	title.text = "ЕЖЕДНЕВНОЕ ИСПЫТАНИЕ"
	title.position = Vector2(0, 20)
	title.size = Vector2(1000, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9, 1))
	title.add_theme_constant_override("outline_size", 4)
	panel.add_child(title)
	
	var date_label = Label.new()
	date_label.text = ch.get("date", "")
	date_label.position = Vector2(0, 70)
	date_label.size = Vector2(1000, 30)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_label.add_theme_font_size_override("font_size", 14)
	date_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	panel.add_child(date_label)
	
	var name_label = Label.new()
	name_label.text = ch.get("name", "")
	name_label.position = Vector2(0, 120)
	name_label.size = Vector2(1000, 40)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1))
	panel.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = ch.get("desc", "")
	desc_label.position = Vector2(100, 180)
	desc_label.size = Vector2(800, 60)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6, 1))
	panel.add_child(desc_label)
	
	var bonus_label = Label.new()
	bonus_label.text = "Бонус: %d отпечатков" % ch.get("bonus_prints", 0)
	bonus_label.position = Vector2(0, 260)
	bonus_label.size = Vector2(1000, 30)
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_label.add_theme_font_size_override("font_size", 18)
	bonus_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
	panel.add_child(bonus_label)
	
	var status_label = Label.new()
	var completed = ch.get("completed", false)
	var best = ch.get("best_score", 0)
	status_label.text = "Статус: %s | Лучший результат: %d" % ["Выполнено" if completed else "Не выполнено", best]
	status_label.position = Vector2(0, 310)
	status_label.size = Vector2(1000, 30)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	panel.add_child(status_label)
	
	# Leaderboard
	var lb_title = Label.new()
	lb_title.text = "ТАБЛИЦА ЛИДЕРОВ"
	lb_title.position = Vector2(0, 370)
	lb_title.size = Vector2(1000, 30)
	lb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_title.add_theme_font_size_override("font_size", 18)
	lb_title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1))
	panel.add_child(lb_title)
	
	var lb = DailyChallengeManager.get_leaderboard()
	var lb_y = 410
	for i in range(min(lb.size(), 5)):
		var entry = lb[i]
		var entry_label = Label.new()
		entry_label.text = "%d. %s — %d отпечатков (Этаж %d)" % [i+1, entry["date"], entry["score"], entry["floor"]]
		entry_label.position = Vector2(200, lb_y + i * 25)
		entry_label.size = Vector2(600, 22)
		entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry_label.add_theme_font_size_override("font_size", 12)
		entry_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6, 1))
		panel.add_child(entry_label)
	
	var btn_start = Button.new()
	btn_start.text = "НАЧАТЬ ИСПЫТАНИЕ" if not completed else "ПОВТОРИТЬ"
	btn_start.position = Vector2(300, 540)
	btn_start.size = Vector2(400, 50)
	btn_start.add_theme_font_size_override("font_size", 18)
	btn_start.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
	btn_start.pressed.connect(_on_start_daily)
	panel.add_child(btn_start)
	
	var btn_close = Button.new()
	btn_close.text = "ЗАКРЫТЬ"
	btn_close.position = Vector2(350, 20)
	btn_close.size = Vector2(100, 30)
	btn_close.add_theme_font_size_override("font_size", 12)
	btn_close.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1))
	btn_close.pressed.connect(func(): panel.queue_free())
	panel.add_child(btn_close)

func _on_start_daily():
	close_all_panels()
	DailyChallengeManager.reset_daily()
	GameManager.start_run()

func create_achievements_ui():
	var canvas = get_node_or_null("CanvasLayer")
	if canvas == null:
		return
	
	var panel = ColorRect.new()
	panel.name = "AchievementsPanel"
	panel.color = Color(0.05, 0.05, 0.08, 0.95)
	panel.position = Vector2(360, 100)
	panel.size = Vector2(1200, 800)
	canvas.add_child(panel)
	
	var title = Label.new()
	title.text = "ДОСТИЖЕНИЯ"
	title.position = Vector2(0, 20)
	title.size = Vector2(1200, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3, 1))
	title.add_theme_constant_override("outline_size", 4)
	panel.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(50, 90)
	scroll.size = Vector2(1100, 620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)
	
	var unlocked = AchievementManager.unlocked_achievements.size()
	var total = AchievementManager.achievements.size()
	
	var progress = Label.new()
	progress.text = "Разблокировано: %d / %d" % [unlocked, total]
	progress.add_theme_font_size_override("font_size", 16)
	progress.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6, 1))
	vbox.add_child(progress)
	
	for id in AchievementManager.achievements.keys():
		var ach = AchievementManager.achievements[id]
		var is_unlocked = id in AchievementManager.unlocked_achievements
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		
		var status = Label.new()
		status.text = "[✓]" if is_unlocked else "[ ]"
		status.add_theme_font_size_override("font_size", 18)
		status.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1) if is_unlocked else Color(0.4, 0.4, 0.4, 1))
		hbox.add_child(status)
		
		var info = VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		
		var name_label = Label.new()
		name_label.text = ach["name"]
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1) if is_unlocked else Color(0.5, 0.5, 0.5, 1))
		info.add_child(name_label)
		
		var desc_label = Label.new()
		desc_label.text = ach["desc"]
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		info.add_child(desc_label)
		
		hbox.add_child(info)
		vbox.add_child(hbox)
	
	var btn_close = Button.new()
	btn_close.text = "ЗАКРЫТЬ"
	btn_close.position = Vector2(450, 730)
	btn_close.size = Vector2(300, 40)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1))
	btn_close.pressed.connect(func(): panel.queue_free())
	panel.add_child(btn_close)

func _on_settings():
	close_all_panels()
	var sm = CanvasLayer.new()
	sm.set_script(load("res://scripts/settings_menu.gd"))
	sm.name = "SettingsMenu"
	add_child(sm)

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

	var btn_ach = Button.new()
	btn_ach.text = "ДОСТИЖЕНИЯ"
	btn_ach.position = Vector2(btn_x, btn_y + 130)
	btn_ach.size = Vector2(btn_w, btn_h)
	btn_ach.add_theme_font_size_override("font_size", 16)
	btn_ach.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1))
	btn_ach.pressed.connect(_on_achievements)
	panel.add_child(btn_ach)

	var btn_daily = Button.new()
	btn_daily.text = "ЕЖЕДНЕВНОЕ ИСПЫТАНИЕ"
	btn_daily.position = Vector2(btn_x, btn_y + 200)
	btn_daily.size = Vector2(btn_w, btn_h)
	btn_daily.add_theme_font_size_override("font_size", 16)
	btn_daily.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9, 1))
	btn_daily.pressed.connect(_on_daily_challenge)
	panel.add_child(btn_daily)

	var btn_gallery = Button.new()
	btn_gallery.text = "ГАЛЕРЕЯ (%d)" % GameManager.photo_gallery.size()
	btn_gallery.position = Vector2(btn_x, btn_y + 270)
	btn_gallery.size = Vector2(btn_w, btn_h)
	btn_gallery.add_theme_font_size_override("font_size", 16)
	btn_gallery.add_theme_color_override("font_color", Color(0.9, 0.5, 0.8, 1))
	btn_gallery.pressed.connect(_on_gallery_hub)
	panel.add_child(btn_gallery)

	var btn_coop = Button.new()
	btn_coop.text = "КООПЕРАТИВ: %s" % ("ВКЛ" if GameManager.coop_mode else "ВЫКЛ")
	btn_coop.position = Vector2(btn_x, btn_y + 340)
	btn_coop.size = Vector2(btn_w, btn_h)
	btn_coop.add_theme_font_size_override("font_size", 16)
	btn_coop.add_theme_color_override("font_color", Color(0.3, 0.9, 0.6, 1) if GameManager.coop_mode else Color(0.5, 0.5, 0.5, 1))
	btn_coop.pressed.connect(_on_toggle_coop)
	panel.add_child(btn_coop)

	var btn_settings = Button.new()
	btn_settings.text = "НАСТРОЙКИ"
	btn_settings.position = Vector2(btn_x, btn_y + 130)
	btn_settings.size = Vector2(btn_w, btn_h)
	btn_settings.add_theme_font_size_override("font_size", 16)
	btn_settings.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1))
	btn_settings.pressed.connect(_on_settings)
	panel.add_child(btn_settings)

	var btn_close = Button.new()
	btn_close.text = "УЙТИ"
	btn_close.position = Vector2(btn_x, btn_y + 480)
	btn_close.size = Vector2(btn_w, btn_h)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1))
	btn_close.pressed.connect(close_npc_menu)
	panel.add_child(btn_close)

func close_all_panels():
	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		for child in canvas.get_children():
			var n = child.name
			if n == "NPCMenuPanel" or n == "ShopPanel" or n == "UpgradePanel":
				child.queue_free()
	npc_menu_open = false
	shop_panel_open = false
	upgrade_panel_open = false

func close_npc_menu():
	close_all_panels()

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
	close_all_panels()
	create_npc_menu()

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
	close_all_panels()
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
		if child.name.begins_with("Relic") or child.name == "RelicScroll":
			child.free()

	var scroll = ScrollContainer.new()
	scroll.name = "RelicScroll"
	scroll.position = Vector2(20, 860)
	scroll.size = Vector2(440, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	canvas.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.name = "RelicVBox"
	vbox.size = Vector2(420, 0)
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var title = Label.new()
	title.name = "RelicTitle"
	title.text = "РЕЛИКВИИ (экипировано %d/%d)" % [RelicManager.equipped_relics.size(), RelicManager.MAX_EQUIPPED]
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1))
	title.add_theme_constant_override("outline_size", 3)
	vbox.add_child(title)

	for i in range(RelicManager.equipped_relics.size()):
		var rid = RelicManager.equipped_relics[i]
		var r = RelicManager.get_relic(rid)
		if r == null:
			continue
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var btn_uneq = Button.new()
		btn_uneq.name = "RelicUnequip_%d" % i
		btn_uneq.text = "×"
		btn_uneq.custom_minimum_size = Vector2(30, 22)
		btn_uneq.add_theme_font_size_override("font_size", 10)
		btn_uneq.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		btn_uneq.pressed.connect(_on_unequip_relic.bind(rid))
		hbox.add_child(btn_uneq)

		var label = Label.new()
		label.name = "RelicEquipped_%d" % i
		label.text = "• %s" % r.display_name
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", r.rarity_color)
		label.add_theme_constant_override("outline_size", 2)
		hbox.add_child(label)
		vbox.add_child(hbox)

	var unequipped = []
	for rid in RelicManager.owned_relics:
		if rid not in RelicManager.equipped_relics:
			unequipped.append(rid)

	if unequipped.size() > 0:
		var sub = Label.new()
		sub.name = "RelicSubTitle"
		sub.text = "В инвентаре:"
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		vbox.add_child(sub)

		for i in range(unequipped.size()):
			var rid = unequipped[i]
			var r = RelicManager.get_relic(rid)
			if r == null:
				continue
			var btn = Button.new()
			btn.name = "RelicBtn_%d" % i
			btn.text = "+ %s" % r.display_name
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", r.rarity_color)
			btn.pressed.connect(_on_equip_relic.bind(rid))
			vbox.add_child(btn)
func _on_equip_relic(relic_id: String):
	RelicManager.equip(relic_id)
	call_deferred("create_relic_ui")

func _on_unequip_relic(relic_id: String):
	RelicManager.unequip(relic_id)
	call_deferred("create_relic_ui")
