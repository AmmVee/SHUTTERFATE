extends Area2D

var opened: bool = false
var player_near: bool = false
var label: Label = null
var sprite: Sprite2D = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label = get_node_or_null("Label")
	sprite = get_node_or_null("Sprite2D")
	if label:
		label.visible = false

func _physics_process(_delta):
	if player_near and not opened and (Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_E)):
		open_chest()

func _on_body_entered(body):
	if body.is_in_group("player") and not opened:
		player_near = true
		if label:
			label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_near = false
		if label:
			label.visible = false

func open_chest():
	if opened:
		return
	opened = true
	if label:
		label.visible = false
	if sprite:
		sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)  # Darkened = opened

	var relic_id = _roll_relic()
	if relic_id != "":
		RelicManager.unlock(relic_id)
		var r = RelicManager.get_relic(relic_id)
		print("TREASURE: Unlocked ", r.display_name if r else relic_id)
		_show_loot_popup(r)
		# Apply relic effects immediately
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("recalculate_max_film"):
			player.recalculate_max_film()
	else:
		print("TREASURE: Nothing this time...")

	# Also give some prints
	var prints = 10 + GameManager.current_floor * 5
	GameManager.photo_prints += prints
	print("TREASURE: +", prints, " prints")

func _roll_relic() -> String:
	var floor = GameManager.current_floor
	var roll = randf()
	var rarity = ""

	if floor <= 2:
		if roll < 0.7: rarity = "white"
		else: rarity = "green"
	elif floor <= 5:
		if roll < 0.5: rarity = "white"
		elif roll < 0.85: rarity = "green"
		else: rarity = "blue"
	elif floor <= 8:
		if roll < 0.5: rarity = "green"
		elif roll < 0.85: rarity = "blue"
		else: rarity = "purple"
	elif floor <= 11:
		if roll < 0.5: rarity = "blue"
		elif roll < 0.85: rarity = "purple"
		else: rarity = "red"
	else:
		if roll < 0.5: rarity = "purple"
		elif roll < 0.85: rarity = "red"
		else: rarity = "gold"

	# Find random relic of this rarity that player doesn't own
	var candidates = []
	for id in RelicManager.all_relics.keys():
		if RelicManager.all_relics[id].rarity == rarity and not RelicManager.has_relic(id):
			candidates.append(id)

	if candidates.size() > 0:
		return candidates[randi() % candidates.size()]

	# Fallback: any unowned relic
	for id in RelicManager.all_relics.keys():
		if not RelicManager.has_relic(id):
			return id

	return ""

func _show_loot_popup(relic):
	if relic == null:
		return
	var popup = Label.new()
	popup.text = "ПОЛУЧЕНО: %s\n%s" % [relic.display_name, relic.description]
	popup.position = global_position + Vector2(-100, -60)
	popup.z_index = 100
	popup.add_theme_font_size_override("font_size", 14)
	popup.add_theme_color_override("font_color", relic.rarity_color)
	popup.add_theme_color_override("font_outline_color", Color(0,0,0,1))
	popup.add_theme_constant_override("outline_size", 3)
	get_tree().current_scene.add_child(popup)

	var tween = get_tree().create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 50, 2.0)
	tween.tween_property(popup, "modulate:a", 0.0, 0.5)
	tween.tween_callback(popup.queue_free)
