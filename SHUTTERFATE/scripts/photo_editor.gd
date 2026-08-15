extends Control

var snapshot_data: Dictionary = {}
var selected_filter: String = "none"
var selected_frame: String = "none"
var caption: String = ""

const FILTERS = {
	"none": {"name": "Без фильтра", "color": Color(1,1,1,1)},
	"sepia": {"name": "Сепия", "color": Color(0.8, 0.6, 0.4, 1)},
	"noir": {"name": "Нуар", "color": Color(0.3, 0.3, 0.3, 1)},
	"vintage": {"name": "Винтаж", "color": Color(0.9, 0.8, 0.5, 1)},
	"cyan": {"name": "Циан", "color": Color(0.2, 0.7, 0.9, 1)},
	"redscale": {"name": "Редскейл", "color": Color(0.9, 0.2, 0.2, 1)}
}

const FRAMES = {
	"none": "Без рамки",
	"classic": "Классическая",
	"polaroid": "Полароид",
	"gold": "Золотая",
	"filmstrip": "Киноплёнка",
	"rough": "Грубая"
}

func _ready():
	z_index = 700
	show_editor()

func show_editor():
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 0.95)
	bg.size = Vector2(1920, 1080)
	bg.position = Vector2(-960, -540)
	add_child(bg)

	var title = Label.new()
	title.text = "ФОТОЛАБОРАТОРИЯ"
	title.position = Vector2(660, 30)
	title.size = Vector2(600, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1))
	title.add_theme_constant_override("outline_size", 4)
	add_child(title)

	# Preview area
	var preview_bg = ColorRect.new()
	preview_bg.color = Color(0.1, 0.1, 0.12, 1)
	preview_bg.position = Vector2(360, 100)
	preview_bg.size = Vector2(600, 450)
	add_child(preview_bg)

	var preview = ColorRect.new()
	preview.name = "PhotoPreview"
	preview.color = Color(0.3, 0.25, 0.2, 1)
	preview.position = Vector2(380, 120)
	preview.size = Vector2(560, 410)
	add_child(preview)

	# Boss name label
	var boss_label = Label.new()
	boss_label.name = "BossLabel"
	boss_label.text = snapshot_data.get("boss_name", "БОСС")
	boss_label.position = Vector2(380, 130)
	boss_label.size = Vector2(560, 40)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 24)
	boss_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
	add_child(boss_label)

	# Floor info
	var floor_label = Label.new()
	floor_label.name = "FloorLabel"
	floor_label.text = "Этаж %d | %s" % [snapshot_data.get("floor", 1), snapshot_data.get("date", "")]
	floor_label.position = Vector2(380, 480)
	floor_label.size = Vector2(560, 25)
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_label.add_theme_font_size_override("font_size", 14)
	floor_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	add_child(floor_label)

	# Caption
	var caption_label = Label.new()
	caption_label.name = "CaptionLabel"
	caption_label.text = caption
	caption_label.position = Vector2(380, 510)
	caption_label.size = Vector2(560, 25)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 16)
	caption_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	add_child(caption_label)

	# Filter panel
	var filter_title = Label.new()
	filter_title.text = "ФИЛЬТРЫ"
	filter_title.position = Vector2(1000, 100)
	filter_title.size = Vector2(400, 30)
	filter_title.add_theme_font_size_override("font_size", 18)
	filter_title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1))
	add_child(filter_title)

	var filter_y = 140
	for fid in FILTERS.keys():
		var btn = Button.new()
		btn.text = FILTERS[fid]["name"]
		btn.position = Vector2(1000, filter_y)
		btn.size = Vector2(200, 35)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", FILTERS[fid]["color"])
		btn.pressed.connect(_on_filter_selected.bind(fid))
		add_child(btn)
		filter_y += 42

	# Frame panel
	var frame_title = Label.new()
	frame_title.text = "РАМКИ"
	frame_title.position = Vector2(1250, 100)
	frame_title.size = Vector2(200, 30)
	frame_title.add_theme_font_size_override("font_size", 18)
	frame_title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1))
	add_child(frame_title)

	var frame_y = 140
	for fid in FRAMES.keys():
		var btn = Button.new()
		btn.text = FRAMES[fid]
		btn.position = Vector2(1250, frame_y)
		btn.size = Vector2(200, 35)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_frame_selected.bind(fid))
		add_child(btn)
		frame_y += 42

	# Caption input
	var cap_title = Label.new()
	cap_title.text = "ПОДПИСЬ"
	cap_title.position = Vector2(1000, 420)
	cap_title.size = Vector2(400, 25)
	cap_title.add_theme_font_size_override("font_size", 16)
	cap_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6, 1))
	add_child(cap_title)

	var cap_line = LineEdit.new()
	cap_line.name = "CaptionInput"
	cap_line.position = Vector2(1000, 450)
	cap_line.size = Vector2(450, 35)
	cap_line.placeholder_text = "Введите подпись..."
	cap_line.text_changed.connect(_on_caption_changed)
	add_child(cap_line)

	# Buttons
	var btn_save = Button.new()
	btn_save.text = "СОХРАНИТЬ СНИМОК"
	btn_save.position = Vector2(1000, 520)
	btn_save.size = Vector2(220, 50)
	btn_save.add_theme_font_size_override("font_size", 14)
	btn_save.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
	btn_save.pressed.connect(_on_save)
	add_child(btn_save)

	var btn_skip = Button.new()
	btn_skip.text = "ПРОПУСТИТЬ"
	btn_skip.position = Vector2(1250, 520)
	btn_skip.size = Vector2(200, 50)
	btn_skip.add_theme_font_size_override("font_size", 14)
	btn_skip.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1))
	btn_skip.pressed.connect(_on_skip)
	add_child(btn_skip)

	# Gallery button
	var btn_gallery = Button.new()
	btn_gallery.text = "ГАЛЕРЕЯ"
	btn_gallery.position = Vector2(1000, 590)
	btn_gallery.size = Vector2(450, 40)
	btn_gallery.add_theme_font_size_override("font_size", 14)
	btn_gallery.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1))
	btn_gallery.pressed.connect(_on_gallery)
	add_child(btn_gallery)

	modulate.a = 0.0
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)

func _on_filter_selected(fid: String):
	selected_filter = fid
	var preview = get_node_or_null("PhotoPreview")
	if preview:
		preview.color = FILTERS[fid]["color"]
	print("Filter selected: ", fid)

func _on_frame_selected(fid: String):
	selected_frame = fid
	var preview = get_node_or_null("PhotoPreview")
	if preview:
		match fid:
			"none": preview.size = Vector2(560, 410)
			"classic": preview.size = Vector2(540, 390)
			"polaroid": preview.size = Vector2(520, 370)
			"gold": preview.size = Vector2(550, 400)
			"filmstrip": preview.size = Vector2(580, 380)
			"rough": preview.size = Vector2(530, 380)
	print("Frame selected: ", fid)

func _on_caption_changed(new_text: String):
	caption = new_text
	var cl = get_node_or_null("CaptionLabel")
	if cl:
		cl.text = caption

func _on_save():
	var snapshot = {
		"boss_name": snapshot_data.get("boss_name", "БОСС"),
		"floor": snapshot_data.get("floor", 1),
		"date": snapshot_data.get("date", ""),
		"filter": selected_filter,
		"frame": selected_frame,
		"caption": caption,
		"prints": GameManager.photo_prints,
		"kills": GameManager.total_kills
	}
	GameManager.photo_gallery.append(snapshot)
	print("Snapshot saved! Gallery size: ", GameManager.photo_gallery.size())
	_show_save_feedback()

func _show_save_feedback():
	var feedback = Label.new()
	feedback.text = "СНИМОК СОХРАНЁН!"
	feedback.position = Vector2(660, 300)
	feedback.size = Vector2(600, 50)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_font_size_override("font_size", 28)
	feedback.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
	feedback.add_theme_constant_override("outline_size", 4)
	add_child(feedback)
	var tween = get_tree().create_tween()
	tween.tween_property(feedback, "modulate:a", 0.0, 2.0)
	tween.chain().tween_callback(func(): feedback.queue_free())

func _on_skip():
	queue_free()
	# Show victory screen
	var vs = CanvasLayer.new()
	vs.set_script(load("res://scripts/victory_screen.gd"))
	vs.name = "VictoryScreen"
	get_tree().current_scene.add_child(vs)

func _on_gallery():
	create_gallery_ui()

func create_gallery_ui():
	var gallery = CanvasLayer.new()
	gallery.z_index = 800

	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 0.95)
	bg.size = Vector2(1920, 1080)
	bg.position = Vector2(-960, -540)
	gallery.add_child(bg)

	var title = Label.new()
	title.text = "ГАЛЕРЕЯ СНИМКОВ"
	title.position = Vector2(660, 30)
	title.size = Vector2(600, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1))
	gallery.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(200, 100)
	scroll.size = Vector2(1520, 800)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gallery.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(grid)

	for snapshot in GameManager.photo_gallery:
		var card = ColorRect.new()
		card.size = Vector2(460, 350)
		card.color = Color(0.08, 0.08, 0.1, 1)
		grid.add_child(card)

		# Filter color preview
		var filter_color = FILTERS.get(snapshot.get("filter", "none"), {}).get("color", Color(1,1,1,1))
		var preview = ColorRect.new()
		preview.color = filter_color
		preview.position = Vector2(10, 10)
		preview.size = Vector2(440, 260)
		card.add_child(preview)

		var boss_name = Label.new()
		boss_name.text = snapshot.get("boss_name", "")
		boss_name.position = Vector2(10, 20)
		boss_name.size = Vector2(440, 30)
		boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_name.add_theme_font_size_override("font_size", 18)
		boss_name.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
		card.add_child(boss_name)

		var info = Label.new()
		info.text = "Этаж %d | %s" % [snapshot.get("floor", 1), snapshot.get("date", "")]
		info.position = Vector2(10, 230)
		info.size = Vector2(440, 20)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", 12)
		info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		card.add_child(info)

		var cap = Label.new()
		cap.text = snapshot.get("caption", "")
		cap.position = Vector2(10, 280)
		cap.size = Vector2(440, 25)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_size_override("font_size", 14)
		cap.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		card.add_child(cap)

		var frame_label = Label.new()
		frame_label.text = "Рамка: %s | Фильтр: %s" % [
			FRAMES.get(snapshot.get("frame", "none"), ""),
			FILTERS.get(snapshot.get("filter", "none"), {}).get("name", "")
		]
		frame_label.position = Vector2(10, 310)
		frame_label.size = Vector2(440, 20)
		frame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		frame_label.add_theme_font_size_override("font_size", 11)
		frame_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		card.add_child(frame_label)

	if GameManager.photo_gallery.size() == 0:
		var empty = Label.new()
		empty.text = "Галерея пуста. Победите босса и сохраните снимок!"
		empty.position = Vector2(500, 400)
		empty.size = Vector2(800, 50)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 20)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		gallery.add_child(empty)

	var btn_close = Button.new()
	btn_close.text = "ЗАКРЫТЬ"
	btn_close.position = Vector2(860, 920)
	btn_close.size = Vector2(200, 40)
	btn_close.add_theme_font_size_override("font_size", 14)
	btn_close.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1))
	btn_close.pressed.connect(func(): gallery.queue_free())
	gallery.add_child(btn_close)

	get_tree().current_scene.add_child(gallery)
