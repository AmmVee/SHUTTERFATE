extends CanvasLayer

func _ready():
    z_index = 500
    show_game_over()

func show_game_over():
    var bg = ColorRect.new()
    bg.color = Color(0.02, 0.01, 0.03, 0.92)
    bg.size = Vector2(1920, 1080)
    bg.position = Vector2(-960, -540)
    add_child(bg)

    var vbox = VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.size = Vector2(600, 500)
    vbox.position = Vector2(660, 200)
    add_child(vbox)

    var title = Label.new()
    title.text = "ПЛЁНКА ЗАСВЕЧЕНА"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 42)
    title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1))
    title.add_theme_constant_override("outline_size", 4)
    vbox.add_child(title)

    var spacer = Control.new()
    spacer.custom_minimum_size = Vector2(0, 40)
    vbox.add_child(spacer)

    var stats = Label.new()
    stats.text = "Этаж: %d\nУбийств: %d\nОтпечатков: %d\nСмертей всего: %d" % [
        GameManager.current_floor,
        GameManager.total_kills,
        GameManager.photo_prints,
        GameManager.total_deaths
    ]
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.add_theme_font_size_override("font_size", 18)
    stats.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6, 1))
    vbox.add_child(stats)

    var spacer2 = Control.new()
    spacer2.custom_minimum_size = Vector2(0, 60)
    vbox.add_child(spacer2)

    var btn = Button.new()
    btn.text = "ВЕРНУТЬСЯ В ТЁМНУЮ КОМНАТУ"
    btn.custom_minimum_size = Vector2(400, 60)
    btn.add_theme_font_size_override("font_size", 18)
    btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1))
    btn.pressed.connect(_on_return)
    vbox.add_child(btn)

    # Animate in
    modulate.a = 0.0
    var tween = get_tree().create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.5)

func _on_return():
    GameManager.end_run(false)
