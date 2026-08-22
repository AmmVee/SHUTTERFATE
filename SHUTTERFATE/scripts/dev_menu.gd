extends CanvasLayer

var menu_open: bool = false
var god_mode: bool = false
var one_shot: bool = false
var infinite_film: bool = false
var show_hitboxes: bool = false

@onready var panel: ColorRect
@onready var grid: GridContainer

func _ready():
	visible = false
	_create_ui()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		toggle_menu()

func toggle_menu():
	menu_open = !menu_open
	visible = menu_open
	if menu_open:
		_update_labels()
		Engine.time_scale = 0.1  # Slow motion while menu is open
	else:
		Engine.time_scale = 1.0

func _create_ui():
	# Semi-transparent background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = Vector2(1920, 1080)
	add_child(bg)

	# Main panel
	panel = ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.12, 0.95)
	panel.position = Vector2(560, 140)
	panel.size = Vector2(800, 780)
	add_child(panel)

	# Title
	var title = Label.new()
	title.text = "DEV MENU [F1]"
	title.position = Vector2(0, 15)
	title.size = Vector2(800, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	title.add_theme_constant_override("outline_size", 3)
	panel.add_child(title)

	# Grid of buttons
	grid = GridContainer.new()
	grid.position = Vector2(40, 70)
	grid.size = Vector2(720, 680)
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(grid)

	# Row 1: God Mode
	_add_toggle_btn("God Mode", "god_mode", func(): god_mode = !god_mode; _update_god_mode())
	_add_toggle_btn("One-Shot Kill", "one_shot", func(): one_shot = !one_shot)

	# Row 2: Infinite Film + Kill All
	_add_toggle_btn("Infinite Film", "infinite_film", func(): infinite_film = !infinite_film)
	_add_action_btn("Kill All Enemies", _kill_all)

	# Row 3: Heal + Full Film
	_add_action_btn("Heal to Full", _heal_full)
	_add_action_btn("Refill Film", _refill_film)

	# Row 4: Teleports
	_add_action_btn("TP to Boss", _tp_to_boss)
	_add_action_btn("TP to Treasure", _tp_to_treasure)
	_add_action_btn("TP to Combat", _tp_to_combat)
	_add_action_btn("TP to Trap", _tp_to_trap)
	_add_action_btn("TP to Puzzle", _tp_to_puzzle)
	_add_action_btn("TP to Rest", _tp_to_rest)
	_add_action_btn("TP to Shop", _tp_to_shop)
	_add_action_btn("TP to Start", _tp_to_start)

	# Row 5: Unlock + Skip
	_add_action_btn("Unlock All Doors", _unlock_doors)
	_add_action_btn("Next Floor", _next_floor)

	# Row 6: Economy
	_add_action_btn("+1000 Prints", _add_prints)
	_add_action_btn("Unlock All Films", _unlock_films)

	# Row 7: Relics
	_add_action_btn("Unlock All Relics", _unlock_relics)
	_add_toggle_btn("Show Hitboxes", "show_hitboxes", func(): show_hitboxes = !show_hitboxes; _toggle_hitboxes())

	# Row 8: Time scale
	_add_action_btn("Time ×0.5", func(): Engine.time_scale = 0.5)
	_add_action_btn("Time ×1.0", func(): Engine.time_scale = 1.0)

	# Close button at bottom
	var close = Button.new()
	close.text = "CLOSE [F1]"
	close.size = Vector2(300, 40)
	close.position = Vector2(250, 720)
	close.add_theme_font_size_override("font_size", 16)
	close.add_theme_color_override("font_color", Color(1, 0.5, 0.5, 1))
	close.pressed.connect(toggle_menu)
	panel.add_child(close)

func _add_toggle_btn(text: String, flag_name: String, callback: Callable):
	var btn = Button.new()
	btn.text = text + ": OFF"
	btn.name = "Btn_" + flag_name
	btn.size = Vector2(350, 45)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(callback)
	btn.pressed.connect(_update_labels)
	grid.add_child(btn)

func _add_action_btn(text: String, callback: Callable):
	var btn = Button.new()
	btn.text = text
	btn.size = Vector2(350, 45)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1))
	btn.pressed.connect(callback)
	grid.add_child(btn)

func _update_labels():
	var names = ["god_mode", "one_shot", "infinite_film", "show_hitboxes"]
	var values = [god_mode, one_shot, infinite_film, show_hitboxes]
	for i in range(names.size()):
		var btn = grid.get_node_or_null("Btn_" + names[i])
		if btn:
			var base = btn.text.split(":")[0]
			btn.text = base + ": " + ("ON" if values[i] else "OFF")
			btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3) if values[i] else Color(0.8, 0.8, 0.8))

# ========== COMMANDS ==========

func _update_god_mode():
	var player = get_tree().get_first_node_in_group("player")
	if player and god_mode:
		player.hp = 999999
		player.max_hp = 999999

func _kill_all():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(99999)
	print("DEV: All enemies killed")

func _heal_full():
	var player = get_tree().get_first_node_in_group("player")
	if player and "hp" in player and "max_hp" in player:
		player.hp = player.max_hp
		print("DEV: Healed to full")

func _refill_film():
	var player = get_tree().get_first_node_in_group("player")
	if player and "current_film" in player and "max_film" in player:
		player.current_film = player.max_film
		player.is_reloading = false
		print("DEV: Film refilled")

func _tp_to_boss():
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("_find_room_of_type"):
		var pos = main._find_room_of_type("boss")
		if pos != Vector2i.ZERO:
			main.call_deferred("move_to_room", pos, "")
			print("DEV: TP to boss room")

func _tp_to_treasure():
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("_find_room_of_type"):
		var pos = main._find_room_of_type("treasure")
		if pos != Vector2i.ZERO:
			main.call_deferred("move_to_room", pos, "")
			print("DEV: TP to treasure room")

func _unlock_doors():
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("unlock_doors"):
		main.unlock_doors()
		print("DEV: All doors unlocked")

func _tp_to_combat():
	_tp_to_room_type("combat")

func _tp_to_trap():
	_tp_to_room_type("trap")

func _tp_to_puzzle():
	_tp_to_room_type("puzzle")

func _tp_to_rest():
	_tp_to_room_type("rest")

func _tp_to_shop():
	_tp_to_room_type("shop")

func _tp_to_start():
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("move_to_room"):
		main.call_deferred("move_to_room", Vector2i.ZERO, "")
		print("DEV: TP to start room")

func _tp_to_room_type(room_type: String):
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("_find_room_of_type"):
		var pos = main._find_room_of_type(room_type)
		if pos != Vector2i.ZERO:
			main.call_deferred("move_to_room", pos, "")
			print("DEV: TP to ", room_type, " room")
		else:
			print("DEV: No ", room_type, " room found")

func _next_floor():
	GameManager.current_floor += 1
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("generate_floor"):
		main.call_deferred("generate_floor")
		print("DEV: Next floor ", GameManager.current_floor)

func _add_prints():
	GameManager.photo_prints += 1000
	print("DEV: +1000 prints")

func _unlock_films():
	var all_films = ["obskura", "chroma", "noir", "infrared", "polaroid", "xpro", "frame_zero"]
	for f in all_films:
		if f not in GameManager.unlocked_films:
			GameManager.unlocked_films.append(f)
	print("DEV: All films unlocked")

func _unlock_relics():
	for id in RelicManager.all_relics.keys():
		RelicManager.unlock(id)
	print("DEV: All relics unlocked")

func _toggle_hitboxes():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e):
			for child in e.get_children():
				if child is CollisionShape2D:
					child.debug_color = Color(1, 0, 0, 0.5) if show_hitboxes else Color(0, 0, 0, 0)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		for child in player.get_children():
			if child is CollisionShape2D:
				child.debug_color = Color(0, 1, 0, 0.5) if show_hitboxes else Color(0, 0, 0, 0)
	print("DEV: Hitboxes ", "ON" if show_hitboxes else "OFF")
