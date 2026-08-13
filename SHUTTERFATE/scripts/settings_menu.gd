extends CanvasLayer

var sfx_volume: float = 1.0
var music_volume: float = 1.0
var mouse_sens: float = 1.0

func _ready():
    z_index = 600
    show_settings()

func show_settings():
    var bg = ColorRect.new()
    bg.color = Color(0.02, 0.02, 0.03, 0.95)
    bg.size = Vector2(1920, 1080)
    bg.position = Vector2(-960, -540)
    add_child(bg)

    var vbox = VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.size = Vector2(500, 500)
    vbox.position = Vector2(710, 200)
    add_child(vbox)

    var title = Label.new()
    title.text = "НАСТРОЙКИ"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 36)
    title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1))
    vbox.add_child(title)

    var spacer = Control.new()
    spacer.custom_minimum_size = Vector2(0, 40)
    vbox.add_child(spacer)

    # SFX Volume
    var sfx_label = Label.new()
    sfx_label.text = "Громкость эффектов: 100%"
    sfx_label.add_theme_font_size_override("font_size", 14)
    vbox.add_child(sfx_label)

    var sfx_slider = HSlider.new()
    sfx_slider.min_value = 0
    sfx_slider.max_value = 100
    sfx_slider.value = 100
    sfx_slider.custom_minimum_size = Vector2(400, 30)
    sfx_slider.value_changed.connect(func(v): _on_sfx_changed(v, sfx_label))
    vbox.add_child(sfx_slider)

    var spacer2 = Control.new()
    spacer2.custom_minimum_size = Vector2(0, 20)
    vbox.add_child(spacer2)

    # Music Volume
    var music_label = Label.new()
    music_label.text = "Громкость музыки: 100%"
    music_label.add_theme_font_size_override("font_size", 14)
    vbox.add_child(music_label)

    var music_slider = HSlider.new()
    music_slider.min_value = 0
    music_slider.max_value = 100
    music_slider.value = 100
    music_slider.custom_minimum_size = Vector2(400, 30)
    music_slider.value_changed.connect(func(v): _on_music_changed(v, music_label))
    vbox.add_child(music_slider)

    var spacer3 = Control.new()
    spacer3.custom_minimum_size = Vector2(0, 20)
    vbox.add_child(spacer3)

    # Mouse Sensitivity
    var mouse_label = Label.new()
    mouse_label.text = "Чувствительность мыши: 1.0x"
    mouse_label.add_theme_font_size_override("font_size", 14)
    vbox.add_child(mouse_label)

    var mouse_slider = HSlider.new()
    mouse_slider.min_value = 50
    mouse_slider.max_value = 200
    mouse_slider.value = 100
    mouse_slider.custom_minimum_size = Vector2(400, 30)
    mouse_slider.value_changed.connect(func(v): _on_mouse_changed(v, mouse_label))
    vbox.add_child(mouse_slider)

    var spacer4 = Control.new()
    spacer4.custom_minimum_size = Vector2(0, 40)
    vbox.add_child(spacer4)

    var btn_close = Button.new()
    btn_close.text = "ЗАКРЫТЬ"
    btn_close.custom_minimum_size = Vector2(300, 50)
    btn_close.add_theme_font_size_override("font_size", 16)
    btn_close.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1))
    btn_close.pressed.connect(_on_close)
    vbox.add_child(btn_close)

func _on_sfx_changed(value, label):
    sfx_volume = value / 100.0
    label.text = "Громкость эффектов: %d%%" % int(value)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))

func _on_music_changed(value, label):
    music_volume = value / 100.0
    label.text = "Громкость музыки: %d%%" % int(value)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))

func _on_mouse_changed(value, label):
    mouse_sens = value / 100.0
    label.text = "Чувствительность мыши: %.1fx" % mouse_sens
    # Store in GameManager for player to read
    GameManager.mouse_sensitivity = mouse_sens

func _on_close():
    queue_free()
