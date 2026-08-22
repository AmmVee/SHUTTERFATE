extends CanvasLayer

var slots_container: HBoxContainer
var slot_panels: Array = []
var cooldown_labels: Array = []

func _ready():
	layer = 50
	_build_ui()

func _build_ui():
	var panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -210
	panel.offset_top = -90
	panel.offset_right = 210
	panel.offset_bottom = -20
	add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 1.0, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	slots_container = HBoxContainer.new()
	slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_container.anchor_left = 0.0
	slots_container.anchor_top = 0.0
	slots_container.anchor_right = 1.0
	slots_container.anchor_bottom = 1.0
	slots_container.offset_left = 10
	slots_container.offset_top = 10
	slots_container.offset_right = -10
	slots_container.offset_bottom = -10
	slots_container.add_theme_constant_override("separation", 12)
	panel.add_child(slots_container)

	for i in range(6):
		var slot_panel = Panel.new()
		slot_panel.custom_minimum_size = Vector2(60, 60)
		slot_panel.size = Vector2(60, 60)

		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
		slot_style.border_width_left = 2
		slot_style.border_width_top = 2
		slot_style.border_width_right = 2
		slot_style.border_width_bottom = 2
		slot_style.corner_radius_top_left = 4
		slot_style.corner_radius_top_right = 4
		slot_style.corner_radius_bottom_left = 4
		slot_style.corner_radius_bottom_right = 4
		slot_panel.add_theme_stylebox_override("panel", slot_style)

		var key_label = Label.new()
		key_label.text = str(i + 1)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		key_label.position = Vector2(4, 2)
		key_label.add_theme_font_size_override("font_size", 11)
		key_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		slot_panel.add_child(key_label)

		var icon = ColorRect.new()
		icon.anchor_left = 0.5
		icon.anchor_top = 0.5
		icon.anchor_right = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -18
		icon.offset_top = -18
		icon.offset_right = 18
		icon.offset_bottom = 18
		icon.name = "Icon"
		slot_panel.add_child(icon)

		var cd_label = Label.new()
		cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_label.anchor_left = 0
		cd_label.anchor_top = 0
		cd_label.anchor_right = 1
		cd_label.anchor_bottom = 1
		cd_label.add_theme_font_size_override("font_size", 18)
		cd_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		cd_label.name = "Cooldown"
		cd_label.visible = false
		slot_panel.add_child(cd_label)

		slots_container.add_child(slot_panel)
		slot_panels.append(slot_panel)
		cooldown_labels.append(cd_label)

func _process(delta):
	for i in range(6):
		var slot_panel = slot_panels[i]
		var icon = slot_panel.get_node("Icon")
		var cd_label = slot_panel.get_node("Cooldown")
		var slot_style = slot_panel.get_theme_stylebox("panel").duplicate()

		if i >= GameManager.max_hotbar_slots:
			slot_style.bg_color = Color(0.08, 0.08, 0.1, 0.5)
			slot_style.border_color = Color(0.2, 0.2, 0.2, 0.3)
			icon.color = Color(0, 0, 0, 0)
			cd_label.visible = false
			slot_panel.modulate = Color(1, 1, 1, 0.4)
		else:
			slot_panel.modulate = Color(1, 1, 1, 1)
			var item_id = GameManager.hotbar_slots[i]
			if item_id != null and item_id != "":
				var item_data = GameManager.get_active_item_data(item_id)
				if not item_data.is_empty():
					icon.color = item_data.icon_color
					slot_style.border_color = Color(0.6, 0.8, 1.0, 0.9)

					if GameManager.active_item_cooldowns.has(item_id):
						var remaining = GameManager.active_item_cooldowns[item_id] - Time.get_ticks_msec() / 1000.0
						if remaining > 0:
							cd_label.text = str(int(remaining) + 1)
							cd_label.visible = true
							icon.color = item_data.icon_color.darkened(0.5)
						else:
							cd_label.visible = false
							icon.color = item_data.icon_color
					else:
						cd_label.visible = false
				else:
					icon.color = Color(0, 0, 0, 0)
					slot_style.border_color = Color(0.4, 0.4, 0.5, 0.6)
					cd_label.visible = false
			else:
				icon.color = Color(0, 0, 0, 0)
				slot_style.border_color = Color(0.4, 0.4, 0.5, 0.6)
				cd_label.visible = false

		slot_panel.add_theme_stylebox_override("panel", slot_style)
