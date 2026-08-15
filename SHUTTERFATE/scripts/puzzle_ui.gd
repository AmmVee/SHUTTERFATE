extends CanvasLayer

signal puzzle_solved
signal puzzle_cancelled

var selected_index: int = -1
var current_order: Array = []
var slots: Array = []
var bg: ColorRect
var panel: Panel

func _ready():
	layer = 101
	
	# Background
	bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.anchor_left = 0
	bg.anchor_top = 0
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	add_child(bg)
	
	# Panel
	panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_top = -200
	panel.offset_right = 300
	panel.offset_bottom = 200
	add_child(panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 1.0, 1)
	panel.add_theme_stylebox_override("panel", style)
	
	# Title
	var title = Label.new()
	title.text = "ХРОНОЛОГИЯ СНИМКОВ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(600, 40)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 1))
	panel.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Выберите два снимка, чтобы поменять их местами"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 60)
	subtitle.size = Vector2(600, 30)
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	panel.add_child(subtitle)
	
	# HBox for photos
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.anchor_left = 0.5
	hbox.anchor_top = 0.5
	hbox.anchor_right = 0.5
	hbox.anchor_bottom = 0.5
	hbox.offset_left = -220
	hbox.offset_top = -40
	hbox.offset_right = 220
	hbox.offset_bottom = 60
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)
	
	# Colors for photos
	var colors = [
		Color(0.9, 0.3, 0.3, 1),
		Color(0.3, 0.9, 0.3, 1),
		Color(0.3, 0.3, 0.9, 1),
		Color(0.9, 0.9, 0.3, 1),
	]
	
	# Generate random order
	current_order = [0, 1, 2, 3]
	current_order.shuffle()
	
	for i in range(4):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 100)
		btn.size = Vector2(80, 100)
		
		var slot_color = colors[current_order[i]]
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = slot_color
		style_normal.border_width_left = 3
		style_normal.border_width_top = 3
		style_normal.border_width_right = 3
		style_normal.border_width_bottom = 3
		style_normal.border_color = Color(0.2, 0.2, 0.2, 1)
		btn.add_theme_stylebox_override("normal", style_normal)
		
		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = slot_color.lightened(0.2)
		style_hover.border_width_left = 3
		style_hover.border_width_top = 3
		style_hover.border_width_right = 3
		style_hover.border_width_bottom = 3
		style_hover.border_color = Color(0.5, 0.5, 0.5, 1)
		btn.add_theme_stylebox_override("hover", style_hover)
		
		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = slot_color.darkened(0.2)
		style_pressed.border_width_left = 3
		style_pressed.border_width_top = 3
		style_pressed.border_width_right = 3
		style_pressed.border_width_bottom = 3
		style_pressed.border_color = Color(0.8, 0.8, 0.8, 1)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		
		var num_label = Label.new()
		num_label.text = str(current_order[i] + 1)
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_label.anchor_left = 0
		num_label.anchor_top = 0
		num_label.anchor_right = 1
		num_label.anchor_bottom = 1
		num_label.add_theme_font_size_override("font_size", 28)
		num_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.add_child(num_label)
		
		btn.pressed.connect(_on_photo_clicked.bind(i))
		hbox.add_child(btn)
		slots.append(btn)
	
	# Cancel button
	var cancel_btn = Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.position = Vector2(220, 160)
	cancel_btn.size = Vector2(120, 40)
	cancel_btn.pressed.connect(_on_cancel)
	panel.add_child(cancel_btn)
	
	# Animate in
	bg.modulate.a = 0
	var tween = get_tree().create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, 0.3)

func _on_photo_clicked(index: int):
	if selected_index == -1:
		selected_index = index
		_highlight_slot(index, true)
	elif selected_index == index:
		_highlight_slot(index, false)
		selected_index = -1
	else:
		_highlight_slot(selected_index, false)
		_swap_photos(selected_index, index)
		selected_index = -1
		_check_solution()

func _highlight_slot(index: int, active: bool):
	var btn = slots[index]
	var style = btn.get_theme_stylebox("normal").duplicate()
	if active:
		style.border_color = Color(1, 1, 1, 1)
		style.border_width_left = 5
		style.border_width_top = 5
		style.border_width_right = 5
		style.border_width_bottom = 5
	else:
		style.border_color = Color(0.2, 0.2, 0.2, 1)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	btn.add_theme_stylebox_override("normal", style)

func _swap_photos(a: int, b: int):
	var temp = current_order[a]
	current_order[a] = current_order[b]
	current_order[b] = temp
	
	var colors = [
		Color(0.9, 0.3, 0.3, 1),
		Color(0.3, 0.9, 0.3, 1),
		Color(0.3, 0.3, 0.9, 1),
		Color(0.9, 0.9, 0.3, 1),
	]
	for i in range(4):
		var btn = slots[i]
		var num_label = btn.get_child(0)
		num_label.text = str(current_order[i] + 1)
		var style = StyleBoxFlat.new()
		style.bg_color = colors[current_order[i]]
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.2, 0.2, 0.2, 1)
		btn.add_theme_stylebox_override("normal", style)

func _check_solution():
	var solved = true
	for i in range(4):
		if current_order[i] != i:
			solved = false
			break
	if solved:
		var tween = get_tree().create_tween()
		tween.tween_property(bg, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func():
			puzzle_solved.emit()
			queue_free()
		)

func _on_cancel():
	var tween = get_tree().create_tween()
	tween.tween_property(bg, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		puzzle_cancelled.emit()
		queue_free()
	)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_cancel()
