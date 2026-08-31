extends CharacterBody2D

@export var max_hp: float = 15.0
@export var move_speed: float = 110.0
@export var attack_damage: int = 8
@export var attack_range: float = 180.0
@export var attack_cooldown: float = 2.0

var hp: float = max_hp
var player: Node2D = null
var can_attack: bool = true

var defense: float = 0.0
var is_smear: bool = false
var is_hidden: bool = false
var is_boss: bool = false

@onready var sprite: Sprite2D = $Sprite2D
var attack_timer: Timer
var flash_timer: Timer
var wander_timer: Timer

var wander_dir: Vector2 = Vector2.ZERO

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")

	var floor = max(GameManager.current_floor, 1)
	var floor_mult = 1.0 + (floor - 1) * 0.15
	max_hp *= floor_mult
	hp = max_hp
	move_speed *= (1.0 + (floor - 1) * 0.05)
	attack_damage = int(attack_damage * floor_mult)

	attack_timer = get_node_or_null("AttackTimer")
	if attack_timer == null:
		attack_timer = Timer.new()
		attack_timer.name = "AttackTimer"
		attack_timer.one_shot = true
		add_child(attack_timer)

	flash_timer = get_node_or_null("FlashTimer")
	if flash_timer == null:
		flash_timer = Timer.new()
		flash_timer.name = "FlashTimer"
		flash_timer.one_shot = true
		add_child(flash_timer)

	wander_timer = get_node_or_null("WanderTimer")
	if wander_timer == null:
		wander_timer = Timer.new()
		wander_timer.name = "WanderTimer"
		wander_timer.one_shot = true
		add_child(wander_timer)

	attack_timer.timeout.connect(_on_attack_timer_timeout)
	flash_timer.timeout.connect(_on_flash_timer_timeout)
	wander_timer.timeout.connect(_on_wander_timer_timeout)

	wander_dir = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()
	wander_timer.start(randf_range(1.5, 3.0))

	if sprite:
		sprite.modulate = Color(0.6, 0.6, 0.9, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(0.9, 0.9), 0.3)

	_update_hidden_visibility()

func _update_hidden_visibility():
	if is_hidden and sprite:
		if FilmManager.current_film and FilmManager.current_film.special_id == "infrared_vision":
			sprite.visible = true
			sprite.modulate = Color(1, 0.5, 0.5, 0.9)
		else:
			sprite.visible = false

func _physics_process(_delta):
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	var detect_range = 280.0 * RelicManager.get_enemy_detect_multiplier()
	if dist < detect_range:
		# Keep distance — ranged enemy
		var dir = global_position.direction_to(player.global_position)
		if dist < attack_range - 40:
			# Too close — back away
			velocity = -dir * move_speed * 0.8
		elif dist > attack_range + 20:
			# Too far — approach
			velocity = dir * move_speed * 0.6
		else:
			# Ideal range — stop and shoot
			velocity = Vector2.ZERO
			if can_attack:
				_shoot_projectile()
	else:
		velocity = wander_dir * (move_speed * 0.5)
	move_and_slide()

func _shoot_projectile():
	can_attack = false
	if player == null:
		return

	var proj = CharacterBody2D.new()
	proj.name = "FaderProjectile"
	proj.global_position = global_position

	var ps = Sprite2D.new()
	ps.texture = load("res://assets/enemy_iso.png")
	ps.modulate = Color(0.5, 0.5, 0.9, 0.8)
	ps.scale = Vector2(0.5, 0.5)
	proj.add_child(ps)

	var pcol = CollisionShape2D.new()
	pcol.shape = CircleShape2D.new()
	pcol.shape.radius = 10.0
	proj.add_child(pcol)

	var dir = global_position.direction_to(player.global_position)
	proj.set_meta("proj_dir", dir)
	proj.set_meta("proj_speed", 220.0)
	proj.set_meta("proj_damage", attack_damage)
	proj.set_meta("proj_hit", false)

	# FIX: add proj to scene tree BEFORE creating/starting timer
	get_tree().current_scene.add_child(proj)

	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 4.0
	timer.timeout.connect(func():
		if is_instance_valid(proj):
			proj.queue_free()
	)
	proj.add_child(timer)
	timer.start()

	# Add projectile movement script
	var script = GDScript.new()
	script.source_code = """extends CharacterBody2D
func _physics_process(_delta):
	move_and_slide()
"""
	script.reload()
	proj.set_script(script)
	proj.velocity = dir * 250.0

	attack_timer.start(attack_cooldown)

func take_damage(amount: float):
	hp -= amount
	if sprite:
		sprite.modulate = Color(1, 0.3, 0.3)
		flash_timer.start(0.1)
	if player:
		var knockback_dir = global_position.direction_to(player.global_position) * -1
		move_and_collide(knockback_dir * 30.0)
	if hp <= 0:
		die()

var is_elite: bool = false

func die():
	if RelicManager.has_ghost_copy():
		_create_ghost_copy()
	_drop_relic()
	queue_free()

func _drop_relic():
	var roll = randf()
	var rarity = ""
	if is_elite:
		if roll < 0.05:
			rarity = "green" if randf() < 0.7 else "blue"
	else:
		if roll < 0.02:
			rarity = "white"
	if rarity == "":
		return
	var candidates = []
	for id in RelicManager.all_relics.keys():
		if RelicManager.all_relics[id].rarity == rarity and not RelicManager.has_relic(id):
			candidates.append(id)
	if candidates.size() > 0:
		var chosen = candidates[randi() % candidates.size()]
		RelicManager.unlock(chosen)
		var r = RelicManager.get_relic(chosen)
		print("DROP from ", "elite " if is_elite else "", "fader: ", r.display_name if r else chosen)
		_show_drop_popup(r)

func _show_drop_popup(relic):
	if relic == null:
		return
	var popup = Label.new()
	popup.text = "ДРОП: %s" % relic.display_name
	popup.position = global_position + Vector2(-60, -40)
	popup.z_index = 100
	popup.add_theme_font_size_override("font_size", 12)
	popup.add_theme_color_override("font_color", relic.rarity_color)
	popup.add_theme_color_override("font_outline_color", Color(0,0,0,1))
	popup.add_theme_constant_override("outline_size", 2)
	get_tree().current_scene.add_child(popup)
	var tween = get_tree().create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 40, 1.5)
	tween.tween_property(popup, "modulate:a", 0.0, 0.5)
	tween.tween_callback(popup.queue_free)

func _create_ghost_copy():
	var scene = get_tree().current_scene
	if scene == null:
		return
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture if sprite else null
	ghost.global_position = global_position
	ghost.modulate = Color(0.5, 0.8, 1.0, 0.4)
	ghost.z_index = -50
	scene.add_child(ghost)
	var tween = get_tree().create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 3.0)
	tween.tween_callback(ghost.queue_free)

func _on_attack_timer_timeout():
	can_attack = true

func _on_flash_timer_timeout():
	if sprite:
		sprite.modulate = Color(0.6, 0.6, 0.9, 1.0)
		_update_hidden_visibility()

func _on_wander_timer_timeout():
	wander_dir = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()
	wander_timer.start(randf_range(1.0, 2.5))


func apply_temp_slow(slow_mult: float, duration: float):
	var original_speed = move_speed
	move_speed *= slow_mult
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if is_instance_valid(self):
			move_speed = original_speed
	)


func get_max_hp() -> int:
	return max_hp

func spawn_blood():
	for i in range(4):
		var blood = ColorRect.new()
		blood.color = Color(0.8, 0.05, 0.05, 0.9)
		blood.size = Vector2(randf_range(3, 6), randf_range(3, 6))
		var angle = randf() * TAU
		var dist = randf_range(10, 30)
		blood.position = global_position + Vector2(cos(angle), sin(angle)) * dist - blood.size * 0.5
		blood.z_index = 50
		get_tree().current_scene.add_child(blood)

		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(blood, "modulate:a", 0.0, 0.4 + randf() * 0.3)
		tween.tween_property(blood, "position:y", blood.position.y + randf_range(10, 25), 0.4)
		tween.chain().tween_callback(func(): blood.queue_free())
