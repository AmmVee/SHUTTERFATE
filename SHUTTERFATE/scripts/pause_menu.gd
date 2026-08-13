extends CanvasLayer

var paused: bool = false

@onready var panel: ColorRect

func _ready():
	visible = false
	_create_ui()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle_pause()

func _on_settings():
	var sm = CanvasLayer.new()
	sm.set_script(load("res://scripts/settings_menu.gd"))
	sm.name = "SettingsMenu"
	add_child(sm)

func toggle_pause():
	paused = !paused
	visible = paused
	get_tree().paused = paused
	if paused:
		print("PAUSED")
	else:
		print("RESUMED")

func _create_ui():
	# Darken background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.size = Vector2(1920, 1080)
	add_child(bg)

	# Panel
	panel = ColorRect.new()
	panel.color = Color(0.06, 0.06, 0.1, 0.95)
	panel.position = Vector2(710, 280)
	panel.size = Vector2(500, 480)
	add_child(panel)

	# Title
	var title = Label.new()
	title.text = "ПАУЗА"
	title.position = Vector2(0, 25)
	title.size = Vector2(500, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6, 1))
	title.add_theme_constant_override("outline_size", 4)
	panel.add_child(title)

	var btn_w = 320
	var btn_h = 50
	var btn_x = (500 - btn_w) / 2
	var start_y = 100
	var gap = 70

	# Resume
	var btn_resume = Button.new()
	btn_resume.text = "ПРОДОЛЖИТЬ"
	btn_resume.position = Vector2(btn_x, start_y)
	btn_resume.size = Vector2(btn_w, btn_h)
	btn_resume.add_theme_font_size_override("font_size", 18)
	btn_resume.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
	btn_resume.pressed.connect(toggle_pause)
	panel.add_child(btn_resume)

	# End Run
	var btn_end = Button.new()
	btn_end.text = "ЗАКОНЧИТЬ ЗАБЕГ"
	btn_end.position = Vector2(btn_x, start_y + gap)
	btn_end.size = Vector2(btn_w, btn_h)
	btn_end.add_theme_font_size_override("font_size", 18)
	btn_end.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 1))
	btn_end.pressed.connect(_end_run)
	panel.add_child(btn_end)

	# Settings placeholder
	var btn_settings = Button.new()
	btn_settings.text = "НАСТРОЙКИ"
	btn_settings.position = Vector2(btn_x, start_y + gap * 2)
	btn_settings.size = Vector2(btn_w, btn_h)
	btn_settings.add_theme_font_size_override("font_size", 18)
	btn_settings.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1))
	btn_settings.disabled = true
	panel.add_child(btn_settings)

	# Quit to Desktop
	var btn_quit = Button.new()
	btn_quit.text = "ВЫЙТИ НА РАБОЧИЙ СТОЛ"
	btn_quit.position = Vector2(btn_x, start_y + gap * 3)
	btn_quit.size = Vector2(btn_w, btn_h)
	btn_quit.add_theme_font_size_override("font_size", 18)
	btn_quit.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1))
	btn_quit.pressed.connect(_quit_game)
	panel.add_child(btn_quit)

	# Floor info
	var info = Label.new()
	info.text = "Этаж: %d | Убийств: %d" % [GameManager.current_floor, GameManager.run_kills]
	info.position = Vector2(0, 400)
	info.size = Vector2(500, 30)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	panel.add_child(info)

func _end_run():
	get_tree().paused = false
	print("Ending run early...")
	GameManager.end_run(false)

func _quit_game():
	get_tree().quit()
