extends CharacterBody2D

signal died

@export var move_speed: float = 180.0
@export var aim_slowdown: float = 0.35
@export var max_hp: int = 100
@export var base_damage: float = 12.0

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
	var spd = move_speed * (aim_slowdown if is_aiming else 1.0)
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

		var enemies = get_enemies_in_aim()
		if enemies.size() > 0:
			focus_time = min(focus_time + delta, max_focus_time)
		else:
			focus_time = max(focus_time - delta * 3.0, 0.0)
	else:
		is_aiming = false
		if aim_area:
			aim_area.monitoring = false
		if aim_visual:
			aim_visual.visible = false
		focus_time = max(focus_time - delta * 4.0, 0.0)

func handle_shooting():
	if is_reloading or current_film <= 0:
		return
	if Input.is_action_just_pressed("shoot") and is_aiming:
		take_photo()

func take_photo():
	current_film -= 1
	var enemies = get_enemies_in_aim()

	for enemy in enemies:
		var dmg = calculate_damage(enemy)
		enemy.take_damage(dmg)
		print("Shot ", enemy.name, " for ", round(dmg), " dmg")
		GameManager.add_kill()

	if enemies.size() == 0:
		print("Miss! No enemy in frame.")

	flash_screen()

	if current_film <= 0:
		start_reload()

func calculate_damage(enemy) -> float:
	var dist = global_position.distance_to(enemy.global_position)
	var max_r = 160.0
	if aim_shape and aim_shape.shape:
		max_r = aim_shape.shape.radius

	var comp = clamp(2.0 - (dist / max_r) * 1.5, 0.5, 2.0)
	var focus = 0.2 + (focus_time / max_focus_time) * 2.8

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
	if iso > 1600:
		iso_mod *= randf_range(0.6, 1.4)
	elif iso > 800:
		iso_mod *= randf_range(0.8, 1.2)

	var aperture_mod = clamp(3.5 / aperture, 0.5, 2.5)

	var dmg = base_damage * comp * focus * exposure * iso_mod * aperture_mod
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
	is_reloading = true
	reload_timer.start(2.5)
	print("Reloading...")

func _on_reload_timer_timeout():
	current_film = max_film
	is_reloading = false
	print("Reloaded!")

func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		die()

func die():
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
		params_label.text = "f/%.1f | 1/%.0f | ISO %d | %.0fmm" % [aperture, shutter_speed, iso, focal_length]
