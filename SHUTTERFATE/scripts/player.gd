extends CharacterBody2D

signal died

@export var move_speed: float = 170.0
var base_speed: float = 170.0
@export var aim_slowdown: float = 0.35
@export var max_hp: int = 80
@export var base_damage: float = 10.0
@export var player_id: int = 1

var hp: int = max_hp
var is_downed: bool = false
var downed_timer: float = 0.0
var max_downed_time: float = 15.0
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
var base_damage_mult: float = 1.0

# Blind mechanic
var is_blinded: bool = false
var blind_timer: float = 0.0
var blind_overlay: ColorRect = null

var aim_area: Area2D
var aim_shape: CollisionShape2D
var reload_timer: Timer
var aim_visual: Node2D
var film_aim_params: Dictionary = {}
var flash_overlay: ColorRect

var focus_bar: ProgressBar
var hp_bar: ProgressBar
var film_label: Label
var params_label: Label

func _ready():
	add_to_group("player")
	AchievementManager.reset_run_damage()
	base_speed = move_speed
	
	# Coop: distinguish player 2
	if player_id == 2:
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			sprite.modulate = Color(0.4, 0.7, 1.0, 1.0)
		# Offset position slightly to avoid overlap
		global_position += Vector2(30, 15)

	var hp_bonus = RelicManager.get_max_hp_bonus()
	max_hp += GameManager.get_camera_bonus_hp()
	max_hp += hp_bonus
	max_hp += RelicManager.get_season_hp_bonus()
	hp = max_hp

	move_speed *= GameManager.get_upgrade_bonus_speed()

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
			
			# Load film aim params
			film_aim_params = FilmManager.get_aim_params()
			_update_aim_shape()

	reload_timer = get_node_or_null("ReloadTimer")
	if reload_timer == null:
		reload_timer = Timer.new()
		reload_timer.name = "ReloadTimer"
		reload_timer.one_shot = true
		add_child(reload_timer)
	reload_timer.timeout.connect(_on_reload_timer_timeout)

	# SFX player
	var sfx = get_node_or_null("SFXPlayer")
	if sfx == null:
		sfx = AudioStreamPlayer.new()
		sfx.name = "SFXPlayer"
		add_child(sfx)

	# InteractionArea for pickups/interactables
	var interaction_area = get_node_or_null("InteractionArea")
	if interaction_area == null:
		interaction_area = Area2D.new()
		interaction_area.name = "InteractionArea"
		var shape = CollisionShape2D.new()
		shape.shape = CircleShape2D.new()
		shape.shape.radius = 24.0
		interaction_area.add_child(shape)
		add_child(interaction_area)

	# Remove old AimVisual if exists (from previous runs)
	var old_aim = get_node_or_null("AimVisual")
	if old_aim:
		old_aim.queue_free()
	
	# Create Node2D AimVisual as child of player (world-space, rotates toward cursor)
	aim_visual = Node2D.new()
	aim_visual.name = "AimVisual"
	aim_visual.z_index = 100
	aim_visual.draw.connect(_on_aim_visual_draw)
	add_child(aim_visual)
	
	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		
		flash_overlay = canvas.get_node_or_null("FlashOverlay")
		var ui = canvas.get_node_or_null("UI")
		if ui:
			hp_bar = ui.get_node_or_null("HPBar")
			focus_bar = ui.get_node_or_null("FocusBar")
			film_label = ui.get_node_or_null("FilmLabel")
			params_label = ui.get_node_or_null("ParamsLabel")

		# Blind overlay
		blind_overlay = ColorRect.new()
		blind_overlay.name = "BlindOverlay"
		blind_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
		blind_overlay.size = Vector2(1920, 1080)
		blind_overlay.position = Vector2(-960, -540)
		blind_overlay.z_index = 200
		blind_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(blind_overlay)

	if flash_overlay:
		flash_overlay.visible = false

	max_film = FilmManager.get_max_frames()
	current_film = max_film

	update_ui()

func recalculate_max_film():
	var new_max = FilmManager.get_max_frames() + RelicManager.get_extra_frames() + GameManager.get_upgrade_bonus_frames()
	max_film = new_max
	current_film = min(current_film + RelicManager.get_extra_frames(), max_film)
	update_ui()

func _physics_process(delta):
	_update_blind(delta)
	handle_movement()
	handle_aiming(delta)
	handle_shooting()
	handle_hotbar_input()
	handle_camera_settings()
	update_ui()
	z_index = int(global_position.y)

func handle_hotbar_input():
	if Input.is_action_just_pressed("ui_1"):
		GameManager.use_hotbar_slot(0)
	elif Input.is_action_just_pressed("ui_2"):
		GameManager.use_hotbar_slot(1)
	elif Input.is_action_just_pressed("ui_3"):
		GameManager.use_hotbar_slot(2)
	elif Input.is_action_just_pressed("ui_4"):
		GameManager.use_hotbar_slot(3)
	elif Input.is_action_just_pressed("ui_5"):
		GameManager.use_hotbar_slot(4)
	elif Input.is_key_pressed(KEY_6):
		if Input.is_action_just_pressed("ui_6") or not Input.is_action_pressed("ui_accept"):
			GameManager.use_hotbar_slot(5)

func _update_blind(delta):
	if blind_timer > 0:
		blind_timer = max(blind_timer - delta, 0.0)
		if blind_timer <= 0:
			is_blinded = false
			if blind_overlay:
				blind_overlay.color.a = 0.0
			print("Blindness faded")

func apply_blind(duration: float):
	if RelicManager.has_blind_immunity():
		print("Polarizing Filter: blind immunity!")
		return
	is_blinded = true
	blind_timer = duration
	if blind_overlay:
		# Flash white first
		blind_overlay.color = Color(1.0, 1.0, 1.0, 1.0)
		var tween = get_tree().create_tween()
		tween.tween_property(blind_overlay, "color", Color(0.1, 0.1, 0.1, 0.85), 0.3)
	print("PLAYER BLINDED for ", duration, " sec!")

func handle_movement():
	var input: Vector2
	if player_id == 1:
		input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	else:
		input = Input.get_vector("ui_left2", "ui_right2", "ui_up2", "ui_down2")
	if input.length() > 0.1 and randf() < 0.03:
		play_sfx("res://assets/sounds/footstep.wav")
	var iso_x = input.x
	var iso_y = input.y
	var slow = aim_slowdown
	if RelicManager.has_no_aim_slow():
		slow = 1.0
	var spd = move_speed * (slow if is_aiming else 1.0)
	velocity.x = (iso_x - iso_y) * spd
	velocity.y = (iso_x + iso_y) * spd * 0.5
	move_and_slide()

func handle_aiming(delta):
	# Update aim visual rotation toward cursor (always visible)
	if aim_visual:
		aim_visual.visible = true
		var mouse_world = get_global_mouse_position()
		var dir = mouse_world - global_position
		if dir.length() > 0:
			aim_visual.rotation = dir.angle()
		aim_visual.queue_redraw()

	if is_blinded:
		# Can't aim while blinded
		is_aiming = false
		if aim_area:
			aim_area.monitoring = false
		focus_time = max(focus_time - delta * 4.0, 0.0)
		if RelicManager.has_effect("slow_time_10"):
			Engine.time_scale = 1.0
		return

	# Update aim params from current film
	film_aim_params = FilmManager.get_aim_params()
	_update_aim_shape()

	if Input.is_action_pressed("aim"):
		is_aiming = true

		# Move aim area to cursor (world space)
		if aim_area:
			aim_area.monitoring = true
			var mouse_pos = get_global_mouse_position()
			var dir = (mouse_pos - global_position).normalized()
			var ap = FilmManager.get_aim_params()
			var shape = ap.get("shape", "circle")
			var max_dist = ap.get("radius", 120)
			match shape:
				"rect":
					max_dist = max(ap.get("width", 200), ap.get("height", 140)) * 0.5
				"beam":
					max_dist = ap.get("width", 200) * 0.5
			var dist = min(global_position.distance_to(mouse_pos), max_dist)
			aim_area.global_position = global_position + dir * dist
			# Cone/beam: aim_area stays at player, rotates toward cursor
			if shape == "cone" or shape == "beam":
				aim_area.global_position = global_position
				aim_area.rotation = dir.angle()

		if RelicManager.has_effect("slow_time_10"):
			Engine.time_scale = 0.5

		var enemies = get_enemies_in_aim()
		var build_rate = FilmManager.get_focus_build_rate()
		if enemies.size() > 0:
			focus_time = min(focus_time + delta * build_rate, max_focus_time)
			# Frosted Glass: slow enemies in aim by 20%
			var slow_mult = RelicManager.get_aim_slow_enemy()
			if slow_mult < 1.0:
				for e in enemies:
					if is_instance_valid(e) and e.has_method("apply_temp_slow"):
						e.apply_temp_slow(slow_mult, 0.1)
		else:
			focus_time = max(focus_time - delta * 3.0 * build_rate, 0.0)
	else:
		is_aiming = false
		if aim_area:
			aim_area.monitoring = false
			aim_area.position = Vector2.ZERO
		focus_time = max(focus_time - delta * 4.0, 0.0)
		if RelicManager.has_effect("slow_time_10"):
			Engine.time_scale = 1.0

func handle_shooting():
	if is_reloading or current_film <= 0:
		return
	var shoot_pressed = Input.is_action_just_pressed("shoot")
	if shoot_pressed:
		print("SHOOT pressed | is_aiming: ", is_aiming, " | film: ", current_film)
	if shoot_pressed and is_aiming:
		take_photo()

func take_photo():
	play_sfx("res://assets/sounds/click.wav")
	AchievementManager.add_shot()
	var dev_menu = get_tree().get_first_node_in_group("main")
	if dev_menu:
		dev_menu = dev_menu.get_node_or_null("DevMenu")

	if dev_menu and dev_menu.infinite_film:
		pass
	else:
		current_film -= 1

	RelicManager.on_shot()
	var enemies = get_enemies_in_aim()
	var kills_this_shot = 0

	if RelicManager.is_aoe_shot():
		_aoe_damage()

	for enemy in enemies:
		var was_alive = true
		if "hp" in enemy:
			was_alive = enemy.hp > 0

		var dmg = calculate_damage(enemy)
		var is_crit = focus_time / max_focus_time >= 0.99 and randf() < RelicManager.get_crit_bonus()
		show_damage_number(dmg, enemy.global_position, is_crit)
		enemy.take_damage(dmg)

		if RelicManager.has_double_shot():
			show_damage_number(dmg * 0.35, enemy.global_position + Vector2(10, -10), false)
			enemy.take_damage(dmg * 0.35)

		if was_alive and "hp" in enemy and enemy.hp <= 0:
			GameManager.add_kill()
			kills_this_shot += 1
			print("Killed ", enemy.name)
			# Obscura Seed: 20% chance to restore 1 frame on kill
			if randf() < RelicManager.get_seed_regen_chance():
				current_film = min(current_film + 1, max_film)
				print("Obscura Seed: +1 frame restored!")

		if kills_this_shot > 0 and FilmManager.should_heal_on_kill():
			var heal = FilmManager.get_heal_amount() * kills_this_shot
			hp = min(hp + heal, max_hp)
			print("Polaroid heal: +", heal, " HP")

	if enemies.size() == 0:
		print("Miss! No enemy in frame.")

	flash_screen()

	if current_film <= 0:
		start_reload()

func _update_aim_shape():
	if aim_shape == null:
		return
	var ap = FilmManager.get_aim_params()
	film_aim_params = ap
	if ap.get("shape", "circle") == "rect":
		var rect = RectangleShape2D.new()
		rect.size = Vector2(ap.get("width", 200), ap.get("height", 140))
		aim_shape.shape = rect
	else:
		var circ = CircleShape2D.new()
		circ.radius = ap.get("radius", 120)
		aim_shape.shape = circ

func _on_aim_visual_draw():
	if aim_visual == null:
		return
	var ap = FilmManager.get_aim_params()
	var shape = ap.get("shape", "circle")
	var radius = ap.get("radius", 120)
	var width = ap.get("width", 200)
	var height = ap.get("height", 140)
	var color = Color(1, 1, 1, 0.3)
	var line_color = Color(1, 1, 1, 0.8)
	
	match shape:
		"circle":
			aim_visual.draw_circle(Vector2(radius, 0), radius, color)
			aim_visual.draw_arc(Vector2(radius, 0), radius, 0, TAU, 32, line_color, 2)
		"cone":
			var pts = PackedVector2Array([
				Vector2.ZERO,
				Vector2(radius, -radius * 0.4),
				Vector2(radius, radius * 0.4)
			])
			aim_visual.draw_colored_polygon(pts, color)
			aim_visual.draw_polyline(pts, line_color, 2)
			aim_visual.draw_line(Vector2.ZERO, Vector2(radius, -radius * 0.4), line_color, 2)
			aim_visual.draw_line(Vector2.ZERO, Vector2(radius, radius * 0.4), line_color, 2)
		"beam":
			var pts = PackedVector2Array([
				Vector2(0, -height * 0.15),
				Vector2(width, -height * 0.15),
				Vector2(width, height * 0.15),
				Vector2(0, height * 0.15)
			])
			aim_visual.draw_colored_polygon(pts, color)
			aim_visual.draw_polyline(pts, line_color, 2)
			aim_visual.draw_line(Vector2(0, -height * 0.15), Vector2(0, height * 0.15), line_color, 2)
		"sector":
			var arc_pts = PackedVector2Array([Vector2.ZERO])
			var steps = 16
			var angle = PI * 0.4
			for i in range(steps + 1):
				var a = -angle / 2 + angle * i / steps
				arc_pts.append(Vector2(cos(a), sin(a)) * radius)
			aim_visual.draw_colored_polygon(arc_pts, color)
			for i in range(arc_pts.size() - 1):
				aim_visual.draw_line(arc_pts[i], arc_pts[i + 1], line_color, 2)
		"aoe":
			aim_visual.draw_circle(Vector2.ZERO, radius, color)
			aim_visual.draw_arc(Vector2.ZERO, radius, 0, TAU, 32, line_color, 2)
		"sniper":
			var r = radius
			aim_visual.draw_line(Vector2(r, -r * 0.3), Vector2(r, r * 0.3), line_color, 2)
			aim_visual.draw_line(Vector2(r * 0.7, 0), Vector2(r * 1.3, 0), line_color, 2)
			aim_visual.draw_circle(Vector2(r, 0), 4, line_color)
		_:
			aim_visual.draw_circle(Vector2(radius, 0), radius, color)
			aim_visual.draw_arc(Vector2(radius, 0), radius, 0, TAU, 32, line_color, 2)

func calculate_damage(enemy) -> float:
	var dist = aim_area.global_position.distance_to(enemy.global_position)
	var max_r = 160.0
	var range_mult = RelicManager.get_aim_range_multiplier() * GameManager.get_upgrade_bonus_range() * GameManager.get_pact_aim_mult()
	if aim_shape and aim_shape.shape:
		if aim_shape.shape is CircleShape2D:
			max_r = aim_shape.shape.radius * range_mult
		elif aim_shape.shape is RectangleShape2D:
			max_r = aim_shape.shape.size.x * 0.5 * range_mult
		else:
			max_r = 160.0 * range_mult
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
	if RelicManager.has_iso_no_noise():
		iso_mod = 1.0 + min((iso - 100) / 1000.0, 0.5)
	else:
		if iso > 1600:
			iso_mod *= randf_range(0.6, 1.4)
		elif iso > 800:
			iso_mod *= randf_range(0.8, 1.2)

	var aperture_mod = clamp(3.5 / aperture, 0.5, 2.5)

	var dmg = base_damage * comp
	dmg *= GameManager.get_camera_bonus_damage()
	dmg = FilmManager.calculate_damage_for_enemy(dmg, focus_ratio, exposure, iso_mod, aperture_mod, current_film, enemy)
	# Beeswax: +15% damage to full HP enemies
	if "hp" in enemy and enemy.has_method("get_max_hp"):
		if enemy.hp >= enemy.get_max_hp():
			dmg *= RelicManager.get_full_hp_bonus()
	elif "hp" in enemy and "max_hp" in enemy:
		if enemy.hp >= enemy.max_hp:
			dmg *= RelicManager.get_full_hp_bonus()

	var dev_menu = get_tree().get_first_node_in_group("main")
	if dev_menu:
		dev_menu = dev_menu.get_node_or_null("DevMenu")
		if dev_menu and dev_menu.one_shot:
			dmg = 99999

	if focus_ratio >= 0.99 and randf() < RelicManager.get_crit_bonus():
		dmg *= 2.0
		print("RELIC CRIT!")

	return max(dmg, 1.0)

func get_enemies_in_aim() -> Array:
	if aim_area == null:
		return []
	var bodies = aim_area.get_overlapping_bodies()
	var enemies = []
	var ap = FilmManager.get_aim_params()
	var shape = ap.get("shape", "circle")
	var aim_pos = aim_area.global_position
	for b in bodies:
		if not b.is_in_group("enemies"):
			continue
		var dist = aim_pos.distance_to(b.global_position)
		match shape:
			"circle", "aoe":
				var r = ap.get("radius", 120)
				if dist <= r:
					enemies.append(b)
			"rect":
				var w = ap.get("width", 200) * 0.5
				var h = ap.get("height", 140) * 0.5
				var local = b.global_position - aim_pos
				if abs(local.x) <= w and abs(local.y) <= h:
					enemies.append(b)
			"cone":
				var r = ap.get("radius", 120)
				var angle = ap.get("angle", 45.0)
				if dist <= r:
					var dir = (b.global_position - global_position).normalized()
					var aim_dir = (aim_pos - global_position).normalized()
					if dir.angle_to(aim_dir) <= deg_to_rad(angle * 0.5):
						enemies.append(b)
			"sniper":
				var r = ap.get("radius", 120)
				if dist <= r:
					enemies.append(b)
			_:
				enemies.append(b)
	return enemies

func start_reload():
	play_sfx("res://assets/sounds/wind.wav")
	RelicManager.on_reload()
	if RelicManager.is_free_reload():
		print("Empty Cassette: FREE RELOAD!")
		max_film = FilmManager.get_max_frames() + RelicManager.get_extra_frames()
		current_film = max_film
		is_reloading = false
		print("Reloaded instantly!")
		return

	is_reloading = true
	var reload_time = FilmManager.get_reload_time() * RelicManager.get_reload_multiplier() * GameManager.get_upgrade_bonus_reload() * GameManager.get_pact_reload_mult()
	reload_timer.start(reload_time)
	print("Reloading... (", reload_time, "s)")

func _on_reload_timer_timeout():
	max_film = FilmManager.get_max_frames() + RelicManager.get_extra_frames() + GameManager.get_upgrade_bonus_frames()
	current_film = max_film
	is_reloading = false
	spawn_reload_particles()
	print("Reloaded!")

func take_damage(amount: int):
	if is_downed:
		return
	
	# Shield check (active item)
	if GameManager.shield_active:
		GameManager.consume_shield()
		_show_blocked_effect()
		return
	
	AchievementManager.add_damage_taken(amount)
	var dev_menu = get_tree().get_first_node_in_group("main")
	if dev_menu:
		dev_menu = dev_menu.get_node_or_null("DevMenu")
		if dev_menu and dev_menu.god_mode:
			return

	if RelicManager.on_first_hit():
		print("UV Filter absorbed the hit!")
		flash_screen()
		return

	if hp - amount <= 0:
		if RelicManager.use_death_cheat():
			hp = 1
			print("Film from Future saved you! 1 HP remaining.")
			flash_screen()
			return

	hp -= amount
	if hp <= 0:
		if GameManager.coop_mode:
			_enter_downed_state()
		else:
			die()

func _show_blocked_effect():
	var label = Label.new()
	label.text = "BLOCKED"
	label.position = global_position + Vector2(0, -30)
	label.modulate = Color(0.3, 0.5, 1.0)
	get_tree().current_scene.add_child(label)
	await get_tree().create_timer(0.8).timeout
	label.queue_free()

func modify_damage(multiplier: float, duration: float):
	base_damage_mult = multiplier
	await get_tree().create_timer(duration).timeout
	base_damage_mult = 1.0

func _auto_aim():
	var nearest = _get_nearest_enemy()
	if nearest:
		var dir = global_position.direction_to(nearest.global_position)
		# Rotate aim visual towards enemy
		if aim_visual:
			aim_visual.rotation = dir.angle()

func _try_revive():
	if not GameManager.coop_mode:
		return
	var other = _get_other_player()
	if other == null or other.is_downed:
		return
	var dist = global_position.distance_to(other.global_position)
	if dist < 80 and Input.is_action_just_pressed("revive"):
		# Cost: 10 film frames from the reviving player
		if other.current_film >= 10:
			other.current_film -= 10
			other.update_ui()
			is_downed = false
			hp = int(max_hp * 0.3)
			update_ui()
			print("Player ", player_id, " REVIVED by Player ", other.player_id)
			# Visual feedback
			var label = Label.new()
			label.text = "ВОСКРЕШЁН!"
			label.position = global_position - Vector2(40, 40)
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
			label.z_index = 200
			get_tree().current_scene.add_child(label)
			var tween = get_tree().create_tween()
			tween.tween_property(label, "modulate:a", 0.0, 1.5)
			tween.chain().tween_callback(func(): label.queue_free())
		else:
			print("Not enough film to revive!")

func _get_other_player() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p != self and p.has_method("take_damage"):
			return p
	return null

func _enter_downed_state():
	is_downed = true
	downed_timer = max_downed_time
	set_physics_process(false)
	# Visual: red tint, pulsing
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(0.5, 0.1, 0.1, 0.7)
	print("Player ", player_id, " is DOWNED! Revive within ", max_downed_time, " seconds")
	
	# Show revive prompt
	var label = Label.new()
	label.name = "DownedLabel"
	label.text = "ИГРОК %d УПАЛ! [R] Воскресить (10 кадров)" % player_id
	label.position = global_position - Vector2(120, 60)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1))
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 200
	get_tree().current_scene.add_child(label)

func die():
	# Remove downed label if exists
	var dl = get_tree().current_scene.get_node_or_null("DownedLabel")
	if dl:
		dl.queue_free()
	if RelicManager.use_death_shot():
		var nearest = _get_nearest_enemy()
		if nearest:
			nearest.take_damage(base_damage * 5.0)
			print("Mirror Shard final shot!")
			flash_screen()

	print("GAME OVER")
	died.emit()
	
	# Show Game Over screen
	var go = CanvasLayer.new()
	go.set_script(load("res://scripts/game_over_screen.gd"))
	go.name = "GameOverScreen"
	get_tree().current_scene.add_child(go)
	
	# Disable player input
	set_physics_process(false)

func play_sfx(stream_path: String):
	var sfx = get_node_or_null("SFXPlayer")
	if sfx == null:
		return
	var stream = load(stream_path)
	if stream:
		sfx.stream = stream
		sfx.play()

func flash_screen():
	if flash_overlay == null:
		return
	flash_overlay.visible = true
	flash_overlay.modulate.a = 0.6
	flash_overlay.scale = Vector2(1.0, 1.0)
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash_overlay, "modulate:a", 0.0, 0.15)
	tween.tween_property(flash_overlay, "scale", Vector2(1.2, 1.2), 0.15)
	tween.chain().tween_callback(func(): if flash_overlay: flash_overlay.visible = false)
	
	# Local shutter flash at player position
	spawn_shutter_flash()

func spawn_shutter_flash():
	var flash = ColorRect.new()
	flash.color = Color(1.0, 1.0, 0.95, 0.9)
	flash.size = Vector2(80, 80)
	flash.position = global_position - Vector2(40, 40)
	flash.z_index = 100
	get_tree().current_scene.add_child(flash)
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "modulate:a", 0.0, 0.12)
	tween.tween_property(flash, "size", Vector2(200, 200), 0.12)
	tween.tween_property(flash, "position", flash.position - Vector2(60, 60), 0.12)
	tween.chain().tween_callback(func(): flash.queue_free())

func show_damage_number(damage: float, pos: Vector2, is_crit: bool = false):
	var label = Label.new()
	label.text = "%.0f" % damage
	label.add_theme_font_size_override("font_size", 18 if not is_crit else 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0) if is_crit else Color(1.0, 0.3, 0.1, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.position = pos - Vector2(20, 30)
	label.z_index = 150
	get_tree().current_scene.add_child(label)
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(func(): label.queue_free())

func spawn_reload_particles():
	for i in range(6):
		var p = ColorRect.new()
		p.color = Color(0.2, 0.9, 0.3, 0.8)
		p.size = Vector2(6, 6)
		p.position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		p.z_index = 100
		get_tree().current_scene.add_child(p)
		
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position:y", p.position.y - randf_range(30, 60), 0.5)
		tween.tween_property(p, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(func(): p.queue_free())

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
	var enemies = get_enemies_in_aim()
	for enemy in enemies:
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
		if is_blinded:
			txt += " [BLIND]"
		film_label.text = txt
	if params_label:
		var film_name = FilmManager.current_film.display_name if FilmManager.current_film else "None"
		var ap_ui = FilmManager.get_aim_params()
		var aim_desc = ap_ui.get("shape", "circle")
		var aim_size = ap_ui.get("radius", 120)
		match aim_desc:
			"beam", "sniper": aim_size = ap_ui.get("width", 200)
			"aoe": aim_size = ap_ui.get("radius", 100)
		params_label.text = "f/%.1f | 1/%.0f | ISO %d | %.0fmm | %s\nПринты: %d | Прицел: %s (%d)" % [aperture, shutter_speed, iso, focal_length, film_name, GameManager.photo_prints, aim_desc, aim_size]


func get_max_hp() -> int:
	return max_hp

func apply_temp_slow(duration: float, factor: float):
	move_speed = base_speed * factor
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func():
		move_speed = base_speed
	)
