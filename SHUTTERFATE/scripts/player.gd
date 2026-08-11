extends CharacterBody2D

signal died

@export var move_speed: float = 170.0
@export var aim_slowdown: float = 0.35
@export var max_hp: int = 80
@export var base_damage: float = 10.0

var hp: int = max_hp
var is_aiming: bool = false
var focus_time: float = 0.0
var max_focus_time: float = 1.5
var is_reloading: bool = false

var aperture: float = 2.8
var shutter_speed: float = 125.0
var iso: int = 400
var focal_length: float = 50.0

var max_film: int = 36
var current_film: int = 36

var aim_area: Area2D
var aim_shape: CollisionShape2D
var reload_timer: Timer
var aim_visual: Panel
var flash_overlay: ColorRect

var focus_bar: ProgressBar
var hp_bar: ProgressBar
var film_label: Label
var params_label: Label

func _ready():
	add_to_group("player")

	# Relic: Lens Cap (+15 HP)
	var hp_bonus = RelicManager.get_max_hp_bonus()
	# Camera level + upgrade HP bonus
	max_hp += GameManager.get_camera_bonus_hp()
	max_hp += hp_bonus
	hp = max_hp

	# Upgrade: speed bonus
	move_speed *= GameManager.get_upgrade_bonus_speed()

	# Relic: Camera Obscura (see all enemies)
	if RelicManager.has_see_all():
		_show_all_enemies()

	aim_area = get_node_or_null("AimArea")
	if aim_area:
		aim_area.monitoring = false
		var shape_node = aim_area.get_node_or_null("CollisionShape2D")
		if shape_node:
			aim_shape = shape_node
			if aim_shape.shape == null:
				aim_shape.shape = CircleShape2D.new()
				aim_shape.shape.radius = 160.0

	reload_timer = get_node_or_null("ReloadTimer")
	if reload_timer == null:
		reload_timer = Timer.new()
		reload_timer.name = "ReloadTimer"
		reload_timer.one_shot = true
		add_child(reload_timer)
	reload_timer.timeout.connect(_on_reload_timer_timeout)

	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		aim_visual = canvas.get_node_or_null("AimVisual")
		flash_overlay = canvas.get_node_or_null("FlashOverlay")
		var ui = canvas.get_node_or_null("UI")
		if ui:
			hp_bar = ui.get_node_or_null("HPBar")
			focus_bar = ui.get_node_or_null("FocusBar")
			film_label = ui.get_node_or_null("FilmLabel")
			params_label = ui.get_node_or_null("ParamsLabel")

	if aim_visual:
		aim_visual.visible = false
	if flash_overlay:
		flash_overlay.visible = false

	max_film = FilmManager.get_max_frames()
	current_film = max_film

	update_ui()

func _physics_process(delta):
	handle_movement()
	handle_aiming(delta)
	handle_shooting()
	handle_camera_settings()
	update_ui()
	z_index = int(global_position.y)

func handle_movement():
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var iso_x = input.x
	var iso_y = input.y
	var slow = aim_slowdown
	# Relic: Old Tripod (no aim slowdown)
	if RelicManager.has_no_aim_slow():
		slow = 1.0
	var spd = move_speed * (slow if is_aiming else 1.0)
	velocity.x = (iso_x - iso_y) * spd
	velocity.y = (iso_x + iso_y) * spd * 0.5
	move_and_slide()

func handle_aiming(delta):
	if Input.is_action_pressed("aim"):
		is_aiming = true
		if aim_area:
			aim_area.monitoring = true
		if aim_visual:
			aim_visual.visible = true

		# Relic: Eyeglass (slow time 20%)
		if RelicManager.has_effect("slow_time_20"):
			Engine.time_scale = RelicManager.get_time_scale()

		var enemies = get_enemies_in_aim()
		var build_rate = FilmManager.get_focus_build_rate()
		if enemies.size() > 0:
			focus_time = min(focus_time + delta * build_rate, max_focus_time)
		else:
			focus_time = max(focus_time - delta * 3.0 * build_rate, 0.0)
	else:
		is_aiming = false
		if aim_area:
			aim_area.monitoring = false
		if aim_visual:
			aim_visual.visible = false
		focus_time = max(focus_time - delta * 4.0, 0.0)
		# Reset time scale
		if RelicManager.has_effect("slow_time_20"):
			Engine.time_scale = 1.0

func handle_shooting():
	if is_reloading or current_film <= 0:
		return
	if Input.is_action_just_pressed("shoot") and is_aiming:
		take_photo()

func take_photo():
	var dev_menu = get_tree().get_first_node_in_group("main")
	if dev_menu:
		dev_menu = dev_menu.get_node_or_null("DevMenu")

	if dev_menu and dev_menu.infinite_film:
		pass  # Don't consume film
	else:
		current_film -= 1

	RelicManager.on_shot()
	var enemies = get_enemies_in_aim()
	var kills_this_shot = 0

	# Relic: Wet Print (AOE every 10th shot)
	if RelicManager.is_aoe_shot():
		_aoe_damage()

	for enemy in enemies:
		var was_alive = true
		if "hp" in enemy:
			was_alive = enemy.hp > 0

		var dmg = calculate_damage(enemy)
		enemy.take_damage(dmg)

		# Relic: Double Exposure (second hit ×0.5)
		if RelicManager.has_double_shot():
			enemy.take_damage(dmg * 0.35)

		if was_alive and "hp" in enemy and enemy.hp <= 0:
			GameManager.add_kill()
			kills_this_shot += 1
			print("Killed ", enemy.name)

	# Polaroid: heal on kill
	if kills_this_shot > 0 and FilmManager.should_heal_on_kill():
		var heal = FilmManager.get_heal_amount() * kills_this_shot
		hp = min(hp + heal, max_hp)
		print("Polaroid heal: +", heal, " HP")

	if enemies.size() == 0:
		print("Miss! No enemy in frame.")

	flash_screen()

	if current_film <= 0:
		start_reload()

func calculate_damage(enemy) -> float:
	var dist = global_position.distance_to(enemy.global_position)
	var max_r = 160.0
	# Relic: Remote Trigger (+50% aim range)
	# Upgrade: range bonus
	var range_mult = RelicManager.get_aim_range_multiplier() * GameManager.get_upgrade_bonus_range()
	if aim_shape and aim_shape.shape:
		max_r = aim_shape.shape.radius * range_mult
	else:
		max_r = 160.0 * range_mult

	var comp = clamp(2.0 - (dist / max_r) * 1.5, 0.5, 2.0)
	var focus_ratio = focus_time / max_focus_time

	var exposure: float
	if shutter_speed >= 500:
		exposure = 0.5
	elif shutter_speed >= 250:
		exposure = 0.8
	elif shutter_speed >= 125:
		exposure = 1.0
	elif shutter_speed >= 60:
		exposure = 1.6
	elif shutter_speed >= 30:
		exposure = 2.5
	else:
		exposure = 1.0

	var iso_mod = 1.0 + (iso - 100) / 2000.0
	# Relic: Pocket Reflector (ISO gives damage, no noise penalty)
	if RelicManager.has_iso_no_noise():
		iso_mod = 1.0 + min((iso - 100) / 1000.0, 0.5)
	else:
		if iso > 1600:
			iso_mod *= randf_range(0.6, 1.4)
		elif iso > 800:
			iso_mod *= randf_range(0.8, 1.2)

	var aperture_mod = clamp(3.5 / aperture, 0.5, 2.5)

	var dmg = base_damage * comp
	# Camera level bonus
	dmg *= GameManager.get_camera_bonus_damage()
	# Use new per-enemy damage calculation for film-specific effects
	dmg = FilmManager.calculate_damage_for_enemy(dmg, focus_ratio, exposure, iso_mod, aperture_mod, current_film, enemy)

	# Dev: One-Shot
	var dev_menu = get_tree().get_first_node_in_group("main")
	if dev_menu:
		dev_menu = dev_menu.get_node_or_null("DevMenu")
	if dev_menu and dev_menu.one_shot:
		dmg = 99999

	# Relic: Fingerprint (+20% crit at full focus)
	if focus_ratio >= 0.99 and randf() < RelicManager.get_crit_bonus():
		dmg *= 2.0
		print("RELIC CRIT!")

	return max(dmg, 1.0)

func get_enemies_in_aim() -> Array:
	if aim_area == null:
		return []
	var bodies = aim_area.get_overlapping_bodies()
	var enemies = []
	for b in bodies:
		if b.is_in_group("enemies"):
			enemies.append(b)
	return enemies

func start_reload():
	RelicManager.on_reload()
	# Relic: Empty Cassette (every 5th reload is free & instant)
	if RelicManager.is_free_reload():
		print("Empty Cassette: FREE RELOAD!")
		max_film = FilmManager.get_max_frames() + RelicManager.get_extra_frames()
		current_film = max_film
		is_reloading = false
		print("Reloaded instantly!")
		return

	is_reloading = true
	var reload_time = FilmManager.get_reload_time() * RelicManager.get_reload_multiplier() * GameManager.get_upgrade_bonus_reload()
	reload_timer.start(reload_time)
	print("Reloading... (", reload_time, "s)")

func _on_reload_timer_timeout():
	max_film = FilmManager.get_max_frames() + RelicManager.get_extra_frames() + GameManager.get_upgrade_bonus_frames()
	current_film = max_film
	is_reloading = false
	print("Reloaded!")

func take_damage(amount: int):
	# Dev: God Mode
	var dev_menu = get_tree().get_first_node_in_group("main")
	if dev_menu:
		dev_menu = dev_menu.get_node_or_null("DevMenu")
	if dev_menu and dev_menu.god_mode:
		return

	# Relic: Broken UV Filter (first hit = 0)
	if RelicManager.on_first_hit():
		print("UV Filter absorbed the hit!")
		flash_screen()
		return

	# Relic: Film from Future (death cheat once per run)
	if hp - amount <= 0:
		if RelicManager.use_death_cheat():
			hp = 1
			print("Film from Future saved you! 1 HP remaining.")
			flash_screen()
			return

	hp -= amount
	if hp <= 0:
		die()

func die():
	# Relic: Mirror Shard (death shot)
	if RelicManager.use_death_shot():
		var nearest = _get_nearest_enemy()
		if nearest:
			nearest.take_damage(base_damage * 5.0)
			print("Mirror Shard final shot!")
		flash_screen()

	print("GAME OVER")
	died.emit()
	GameManager.end_run(false)

func flash_screen():
	if flash_overlay == null:
		return
	flash_overlay.visible = true
	flash_overlay.modulate.a = 0.8
	await get_tree().create_timer(0.05).timeout
	if flash_overlay:
		flash_overlay.visible = false

func handle_camera_settings():
	if Input.is_action_just_pressed("ui_1"):
		shutter_speed = 500.0
	elif Input.is_action_just_pressed("ui_2"):
		shutter_speed = 125.0
	elif Input.is_action_just_pressed("ui_3"):
		shutter_speed = 30.0
	elif Input.is_action_just_pressed("ui_4"):
		iso = 100 if iso != 100 else 3200
	elif Input.is_action_just_pressed("ui_5"):
		aperture = 1.4 if aperture != 1.4 else 16.0

func _aoe_damage():
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if is_instance_valid(enemy) and "take_damage" in enemy:
			enemy.take_damage(base_damage * 1.5)
	print("Wet Print AOE!")

func _get_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var min_dist = 99999.0
	for e in enemies:
		if is_instance_valid(e):
			var d = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				nearest = e
	return nearest

func _show_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e.has_method("_update_hidden_visibility"):
			e._update_hidden_visibility()
	print("Camera Obscura: all enemies revealed")

func update_ui():
	if hp_bar:
		hp_bar.value = (float(hp) / max_hp) * 100
	if focus_bar:
		focus_bar.value = (focus_time / max_focus_time) * 100
	if film_label:
		var txt = "FILM: %d/%d" % [current_film, max_film]
		if is_reloading:
			txt += " [RELOAD]"
		film_label.text = txt
	if params_label:
		var film_name = FilmManager.current_film.display_name if FilmManager.current_film else "None"
		params_label.text = "f/%.1f | 1/%.0f | ISO %d | %.0fmm | %s" % [aperture, shutter_speed, iso, focal_length, film_name]
