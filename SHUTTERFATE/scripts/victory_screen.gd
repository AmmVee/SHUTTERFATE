extends CanvasLayer

var next_floor: bool = false

func _ready():
    layer = 100
    show_victory()

func show_victory():
    var bg = ColorRect.new()
    bg.color = Color(0.02, 0.03, 0.01, 0.92)
    bg.anchor_left = 0.0
    bg.anchor_top = 0.0
    bg.anchor_right = 1.0
    bg.anchor_bottom = 1.0
    bg.offset_left = 0
    bg.offset_top = 0
    bg.offset_right = 0
    bg.offset_bottom = 0
    add_child(bg)

    var vbox = VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.anchor_left = 0.5
    vbox.anchor_top = 0.5
    vbox.anchor_right = 0.5
    vbox.anchor_bottom = 0.5
    vbox.offset_left = -300
    vbox.offset_top = -250
    vbox.offset_right = 300
    vbox.offset_bottom = 250
    add_child(vbox)

    var title = Label.new()
    title.text = "ЭТАЖ %d ПРОЙДЁН" % GameManager.current_floor
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 42)
    title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1))
    title.add_theme_constant_override("outline_size", 4)
    vbox.add_child(title)

    var spacer = Control.new()
    spacer.custom_minimum_size = Vector2(0, 40)
    vbox.add_child(spacer)

    var stats = Label.new()
    stats.text = "Убийств за забег: %d\nОтпечатков: %d\nУровень камеры: %d" % [
        GameManager.total_kills,
        GameManager.photo_prints,
        GameManager.camera_level
    ]
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.add_theme_font_size_override("font_size", 18)
    stats.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6, 1))
    vbox.add_child(stats)

    var spacer2 = Control.new()
    spacer2.custom_minimum_size = Vector2(0, 60)
    vbox.add_child(spacer2)

    var btn_next = Button.new()
    btn_next.text = "СЛЕДУЮЩИЙ ЭТАЖ"
    btn_next.custom_minimum_size = Vector2(400, 50)
    btn_next.add_theme_font_size_override("font_size", 18)
    btn_next.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
    btn_next.pressed.connect(_on_next_floor)
    vbox.add_child(btn_next)

    var spacer3 = Control.new()
    spacer3.custom_minimum_size = Vector2(0, 20)
    vbox.add_child(spacer3)

    var btn_hub = Button.new()
    btn_hub.text = "ВЕРНУТЬСЯ В ХАБ"
    btn_hub.custom_minimum_size = Vector2(400, 50)
    btn_hub.add_theme_font_size_override("font_size", 16)
    btn_hub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6, 1))
    btn_hub.pressed.connect(_on_return_hub)
    vbox.add_child(btn_hub)

    bg.modulate.a = 0.0
    var tween = get_tree().create_tween()
    tween.tween_property(bg, "modulate:a", 1.0, 0.5)

func _on_next_floor():
    GameManager.current_floor += 1
    get_tree().reload_current_scene()

func _on_return_hub():
    GameManager.end_run(true)
