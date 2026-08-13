extends CharacterBody2D

# === АБЕРРАЦИЯ — Финальный босс, искажение реальности ===
# Создаёт копии себя (только 1 настоящий)
# Меняет гравитацию (игрок скользит)
# Использует случайные механики предыдущих боссов

@export var max_hp: float = 800.0
@export var move_speed: float = 100.0
@export var attack_damage: int = 25
@export var attack_cooldown: float = 1.8

var hp: float = max_hp
var player: Node2D = null
var can_attack: bool = true

var defense: float = 0.0
var is_smear: bool = false
var is_hidden: bool = false
var is_boss: bool = true

enum Phase { ONE, TWO, THREE }
var current_phase: int = Phase.ONE

# Clone system
var clone_timer: Timer
var active_clones: Array = []
var clone_count: int = 2

# Gravity shift
var gravity_timer: Timer
var gravity_active: bool = false
var gravity_dir: Vector2 = Vector2.ZERO
var gravity_force: float = 200.0

# Random boss mechanic rotation
var mechanic_timer: Timer
var current_mechanic: String = ""

# Phase 1: Portraitist flashes
# Phase 2: Developer jars + Photojournalist teleports
# Phase 3: All mechanics + frenzy

var jar_timer: Timer
var teleport_timer: Timer
var flash_attack_timer: Timer
var frenzy_timer: Timer

@onready var sprite: Sprite2D = $Sprite2D
var attack_timer: Timer
var flash_timer: Timer

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	add_to_group("bosses")

	var floor_num = max(GameManager.current_floor, 1)
	max_hp = 800 + (floor_num - 1) * 150
	hp = max_hp

	attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.one_shot = true
	add_child(attack_timer)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	flash_timer = Timer.new()
	flash_timer.name = "FlashTimer"
	flash_timer.one_shot = true
	add_child(flash_timer)
	flash_timer.timeout.connect(_on_flash_timeout)

	clone_timer = Timer.new()
	clone_timer.name = "CloneTimer"
	clone_timer.one_shot = true
	add_child(clone_timer)
	clone_timer.timeout.connect(_spawn_clones)

	gravity_timer = Timer.new()
	gravity_timer.name = "GravityTimer"
	gravity_timer.one_shot = true
	add_child(gravity_timer)
	gravity_timer.timeout.connect(_shift_gravity)

	mechanic_timer = Timer.new()
	mechanic_timer.name = "MechanicTimer"
	mechanic_timer.one_shot = true
	add_child(mechanic_timer)
	mechanic_timer.timeout.connect(_rotate_mechanic)

	jar_timer = Timer.new()
	jar_timer.name = "JarTimer"
	jar_timer.one_shot = true
	add_child(jar_timer)
	jar_timer.timeout.connect(_throw_jar)

	teleport_timer = Timer.new()
	teleport_timer.name = "TeleportTimer"
	teleport_timer.one_shot = true
	add_child(teleport_timer)
	teleport_timer.timeout.connect(_teleport)

	flash_attack_timer = Timer.new()
	flash_attack_timer.name = "FlashAttackTimer"
	flash_attack_timer.one_shot = true
	add_child(flash_attack_timer)
	flash_attack_timer.timeout.connect(_flash_attack)

	frenzy_timer = Timer.new()
	frenzy_timer.name = "FrenzyTimer"
	frenzy_timer.one_shot = true
	add_child(frenzy_timer)
	frenzy_timer.timeout.connect(_frenzy_action)

	if sprite:
		sprite.scale = Vector2(2.5, 2.5)
		sprite.modulate = Color(0.3, 0.1, 0.4, 1.0)

	_start_phase_one()

func _physics_process(delta):
	if player == null:
		return

	# Apply gravity push to player
	if gravity_active and player:
		player.velocity += gravity_dir * gravity_force * delta

	_update_clones(delta)

	match current_phase:
		Phase.ONE:
			_process_phase_one(delta)
		Phase.TWO:
			_process_phase_two(delta)
		Phase.THREE:
			_process_phase_three(delta)

# ========== PHASE 1: The Distortion ==========
func _start_phase_one():
	print("=== PHASE 1: The Distortion ===")
	current_phase = Phase.ONE
	move_speed = 100
	defense = 0.15
	clone_count = 2
	if sprite:
		sprite.modulate = Color(0.3, 0.1, 0.4, 1.0)
	_spawn_clones()
	gravity_timer.start(8.0)
	mechanic_timer.start(5.0)
	flash_attack_timer.start(4.0)

func _process_phase_one(_delta):
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist > 60:
		var dir = global_position.direction_to(player.global_position)
		velocity = dir * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if dist < 50 and can_attack:
		_attack_player()

# ========== PHASE 2: The Fracture ==========
func _transition_to_phase_two():
	print("=== PHASE 2: The Fracture ===")
	current_phase = Phase.TWO
	move_speed = 130
	defense = 0.1
	clone_count = 3
	if sprite:
		sprite.modulate = Color(0.6, 0.1, 0.5, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(2.8, 2.8), 0.5)
	_clear_clones()
	_spawn_clones()
	gravity_timer.start(5.0)
	mechanic_timer.start(4.0)
	jar_timer.start(3.0)
	teleport_timer.start(6.0)

func _process_phase_two(_delta):
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist > 50:
		var dir = global_position.direction_to(player.global_position)
		velocity = dir * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if dist < 45 and can_attack:
		_attack_player()

# ========== PHASE 3: The Null ==========
func _transition_to_phase_three():
	print("=== PHASE 3: THE NULL ===")
	current_phase = Phase.THREE
	move_speed = 160
	defense = 0.05
	clone_count = 4
	if sprite:
		sprite.modulate = Color(0.9, 0.0, 0.2, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(3.0, 3.0), 0.5)
	_clear_clones()
	_spawn_clones()
	gravity_timer.start(3.5)
	mechanic_timer.start(3.0)
	jar_timer.start(2.5)
	teleport_timer.start(4.0)
	flash_attack_timer.start(3.0)
	frenzy_timer.start(8.0)

func _process_phase_three(_delta):
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist > 40:
		var dir = global_position.direction_to(player.global_position)
		velocity = dir * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if dist < 45 and can_attack:
		_attack_player()

# ========== CLONES ==========
func _spawn_clones():
	if not is_instance_valid(self):
		return
	_clear_clones()

	for i in range(clone_count):
		var clone = CharacterBody2D.new()
		clone.name = "AberrationClone_%d" % i
		clone.global_position = global_position + Vector2(randf_range(-80, 80), randf_range(-60, 60))
		clone.add_to_group("enemies")
		clone.add_to_group("aberration_clones")

		var cs = Sprite2D.new()
		cs.texture = load("res://assets/enemy_iso.png")
		cs.modulate = Color(0.3, 0.1, 0.4, 0.7)
		cs.scale = Vector2(2.3, 2.3)
		clone.add_child(cs)

		var ccol = CollisionShape2D.new()
		ccol.shape = RectangleShape2D.new()
		ccol.shape.size = Vector2(40, 40)
		clone.add_child(ccol)

		clone.set_meta("is_clone", true)
		clone.set_meta("lifetime", 5.0)

		# Simple AI: follow player slowly
		var clone_script = GDScript.new()
		clone_script.source_code = """
extends CharacterBody2D
var player: Node2D = null
var lifetime: float = 5.0
func _ready():
	player = get_tree().get_first_node_in_group("player")
func _physics_process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	if player:
		var dir = global_position.direction_to(player.global_position)
		velocity = dir * 50.0
		move_and_slide()
func take_damage(amount):
	# Clones take no damage
	pass
func die():
	queue_free()
"""
		clone.set_script(clone_script)

		get_tree().current_scene.add_child(clone)
		active_clones.append(clone)

	var next_spawn = randf_range(6.0, 10.0)
	if current_phase == Phase.TWO:
		next_spawn = randf_range(5.0, 7.0)
	elif current_phase == Phase.THREE:
		next_spawn = randf_range(4.0, 6.0)
	clone_timer.start(next_spawn)

func _update_clones(_delta):
	var to_remove = []
	for c in active_clones:
		if not is_instance_valid(c):
			to_remove.append(c)
	for c in to_remove:
		active_clones.erase(c)

func _clear_clones():
	for c in active_clones:
		if is_instance_valid(c):
			c.queue_free()
	active_clones.clear()

# ========== GRAVITY SHIFT ==========
func _shift_gravity():
	if not is_instance_valid(self) or player == null:
		return

	gravity_active = true
	var angles = [0, PI/2, PI, -PI/2, PI/4, -PI/4, 3*PI/4, -3*PI/4]
	var angle = angles[randi() % angles.size()]
	gravity_dir = Vector2(cos(angle), sin(angle) * 0.5).normalized()

	# Visual warning
	var warning = Label.new()
	warning.text = "⚠ ГРАВИТАЦИЯ ИЗМЕНИЛАСЬ! ⚠"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.position = Vector2(-200, -150)
	warning.add_theme_font_size_override("font_size", 18)
	warning.add_theme_color_override("font_color", Color(0.8, 0.2, 0.9, 1))
	warning.add_theme_constant_override("outline_size", 3)
	add_child(warning)

	# Screen tilt effect via shader or overlay
	var tilt = Sprite2D.new()
	tilt.texture = load("res://assets/enemy_iso.png")
	tilt.modulate = Color(0.5, 0.0, 0.8, 0.15)
	tilt.scale = Vector2(20, 20)
	tilt.global_position = player.global_position
	tilt.z_index = -10
	get_tree().current_scene.add_child(tilt)

	await get_tree().create_timer(3.0).timeout
	gravity_active = false
	if is_instance_valid(warning):
		warning.queue_free()
	if is_instance_valid(tilt):
		tilt.queue_free()

	var next_time = 8.0
	if current_phase == Phase.TWO:
		next_time = 5.0
	elif current_phase == Phase.THREE:
		next_time = 3.5
	gravity_timer.start(next_time)

# ========== RANDOM MECHANICS ==========
func _rotate_mechanic():
	if not is_instance_valid(self):
		return

	var mechanics = ["flash", "jar", "teleport"]
	if current_phase == Phase.THREE:
		mechanics.append("all")

	current_mechanic = mechanics[randi() % mechanics.size()]
	match current_mechanic:
		"flash":
			_flash_attack()
		"jar":
			_throw_jar()
		"teleport":
			_teleport()
		"all":
			_flash_attack()
			await get_tree().create_timer(0.5).timeout
			_throw_jar()
			await get_tree().create_timer(0.5).timeout
			_teleport()

	var next_time = randf_range(5.0, 8.0)
	if current_phase == Phase.TWO:
		next_time = randf_range(4.0, 6.0)
	elif current_phase == Phase.THREE:
		next_time = randf_range(3.0, 5.0)
	mechanic_timer.start(next_time)

# ========== PORTRAITIST FLASH ==========
func _flash_attack():
	if not is_instance_valid(self) or player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist < 300:
		# AoE flash circles
		for i in range(3):
			var offset = Vector2(randf_range(-100, 100), randf_range(-80, 80))
			_create_flash_circle(global_position + offset)
		# Blind player
		if player and player.has_method("apply_blind"):
			player.apply_blind(0.8)

func _create_flash_circle(pos: Vector2):
	var circle = Area2D.new()
	circle.global_position = pos
	var cshape = CollisionShape2D.new()
	cshape.shape = CircleShape2D.new()
	cshape.shape.radius = 50.0
	circle.add_child(cshape)
	get_tree().current_scene.add_child(circle)

	var csprite = Sprite2D.new()
	csprite.texture = load("res://assets/enemy_iso.png")
	csprite.modulate = Color(1.0, 1.0, 0.8, 0.5)
	csprite.scale = Vector2(2.0, 2.0)
	circle.add_child(csprite)

	await get_tree().create_timer(0.3).timeout
	var bodies = circle.get_overlapping_bodies()
	for b in bodies:
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(15)
			print("Aberration flash hit!")

	var tween = get_tree().create_tween()
	tween.tween_property(csprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(circle.queue_free)

# ========== DEVELOPER JAR ==========
func _throw_jar():
	if not is_instance_valid(self) or player == null:
		return
	for i in range(2 if current_phase == Phase.THREE else 1):
		var jar = CharacterBody2D.new()
		jar.name = "AberrationJar"
		jar.global_position = global_position
		var js = Sprite2D.new()
		js.texture = load("res://assets/enemy_iso.png")
		js.modulate = Color(0.8, 0.2, 0.8, 1.0)
		js.scale = Vector2(0.6, 0.6)
		jar.add_child(js)
		var jcol = CollisionShape2D.new()
		jcol.shape = CircleShape2D.new()
		jcol.shape.radius = 12.0
		jar.add_child(jcol)
		var spread = randf_range(-0.5, 0.5)
		var dir = global_position.direction_to(player.global_position).rotated(spread)
		jar.set_meta("jar_velocity", dir * 200.0)
		jar.set_meta("jar_exploded", false)
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = 3.0
		timer.timeout.connect(func(): _explode_jar(jar))
		jar.add_child(timer)
		timer.start()
		get_tree().current_scene.add_child(jar)

func _explode_jar(jar):
	if not is_instance_valid(jar) or jar.get_meta("jar_exploded", false):
		return
	jar.set_meta("jar_exploded", true)
	var splash = Area2D.new()
	var sshape = CollisionShape2D.new()
	sshape.shape = CircleShape2D.new()
	sshape.shape.radius = 60.0
	splash.add_child(sshape)
	jar.add_child(splash)
	await get_tree().process_frame
	var bodies = splash.get_overlapping_bodies()
	for b in bodies:
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(12)
	splash.queue_free()
	# Create puddle
	var puddle = Area2D.new()
	puddle.global_position = jar.global_position
	puddle.add_to_group("acid_puddles")
	var ps = Sprite2D.new()
	ps.texture = load("res://assets/floor_iso.png")
	ps.modulate = Color(0.6, 0.1, 0.6, 0.4)
	ps.scale = Vector2(1.5, 1.5)
	puddle.add_child(ps)
	var pshape = CollisionShape2D.new()
	pshape.shape = CircleShape2D.new()
	pshape.shape.radius = 50.0
	puddle.add_child(pshape)
	puddle.set_meta("damage_per_sec", 10)
	get_tree().current_scene.add_child(puddle)
	var tween = get_tree().create_tween()
	tween.tween_property(ps, "modulate:a", 0.0, 8.0)
	tween.tween_callback(puddle.queue_free)
	jar.queue_free()

# ========== PHOTOJOURNALIST TELEPORT ==========
func _teleport():
	if not is_instance_valid(self) or player == null:
		return
	# Flash at current
	_create_teleport_flash(global_position)
	# Teleport
	var angle = randf() * TAU
	var dist = randf_range(150, 300)
	global_position = player.global_position + Vector2(cos(angle), sin(angle) * 0.5) * dist
	_create_teleport_flash(global_position)
	var next_time = randf_range(5.0, 8.0)
	if current_phase == Phase.THREE:
		next_time = randf_range(3.0, 5.0)
	teleport_timer.start(next_time)

func _create_teleport_flash(pos: Vector2):
	var flash = Sprite2D.new()
	flash.texture = load("res://assets/enemy_iso.png")
	flash.modulate = Color(0.8, 0.2, 0.8, 0.6)
	flash.scale = Vector2(3.0, 3.0)
	flash.global_position = pos
	flash.z_index = 100
	get_tree().current_scene.add_child(flash)
	var tween = get_tree().create_tween()
	tween.tween_property(flash, "scale", Vector2(5, 5), 0.15)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)

# ========== FRENZY (Phase 3 only) ==========
func _frenzy_action():
	if not is_instance_valid(self) or current_phase != Phase.THREE:
		return
	print("=== ABERRATION FRENZY ===")
	# Spawn 2 extra clones
	for i in range(2):
		var clone = CharacterBody2D.new()
		clone.name = "FrenzyClone_%d" % i
		clone.global_position = global_position + Vector2(randf_range(-60, 60), randf_range(-40, 40))
		clone.add_to_group("enemies")
		var cs = Sprite2D.new()
		cs.texture = load("res://assets/enemy_iso.png")
		cs.modulate = Color(0.9, 0.0, 0.2, 0.6)
		cs.scale = Vector2(2.5, 2.5)
		clone.add_child(cs)
		var ccol = CollisionShape2D.new()
		ccol.shape = RectangleShape2D.new()
		ccol.shape.size = Vector2(40, 40)
		clone.add_child(ccol)
		clone.set_meta("is_clone", true)
		clone.set_meta("lifetime", 3.0)
		var cscript = GDScript.new()
		cscript.source_code = """
extends CharacterBody2D
var player: Node2D = null
var lifetime: float = 3.0
func _ready():
	player = get_tree().get_first_node_in_group("player")
func _physics_process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	if player:
		var dir = global_position.direction_to(player.global_position)
		velocity = dir * 80.0
		move_and_slide()
func take_damage(amount):
	pass
func die():
	queue_free()
"""
		clone.set_script(cscript)
		get_tree().current_scene.add_child(clone)
		active_clones.append(clone)

	# Throw 4 jars
	for i in range(4):
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(self):
			_throw_jar()

	frenzy_timer.start(randf_range(8.0, 12.0))

# ========== COMMON ==========
func _attack_player():
	can_attack = false
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)
	attack_timer.start(attack_cooldown)

func _on_attack_timer_timeout():
	can_attack = true

func take_damage(amount: float):
	var actual = amount * (1.0 - defense)
	hp -= actual
	if sprite:
		sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
		flash_timer.start(0.1)
	var hp_ratio = hp / max_hp
	if current_phase == Phase.ONE and hp_ratio <= 0.7:
		_transition_to_phase_two()
	elif current_phase == Phase.TWO and hp_ratio <= 0.35:
		_transition_to_phase_three()
	if hp <= 0:
		die()

func die():
	print("ABERRATION DEFEATED! YOU WON!")
	_clear_clones()
	gravity_active = false
	GameManager.add_boss_kill()
	_drop_reward()
	_show_secret_ending()
	queue_free()

func _drop_reward():
	var prints_bonus = 300 * GameManager.current_floor
	GameManager.photo_prints += prints_bonus
	print("BOSS REWARD: +", prints_bonus, " prints")
	if not "frame_zero" in GameManager.unlocked_films:
		GameManager.unlocked_films.append("frame_zero")
		print("UNLOCKED: Плёнка 'Кадр Ноль'!")
	if not RelicManager.has_relic("frame_zero_relic"):
		RelicManager.unlock("frame_zero_relic")
		print("UNLOCKED: Реликвия 'Кадр Ноль' (Легендарная)!")

func _show_secret_ending():
	var canvas = CanvasLayer.new()
	canvas.layer = 300
	canvas.name = "SecretEnding"
	get_tree().current_scene.add_child(canvas)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.size = Vector2(1920, 1080)
	bg.position = Vector2(-960, -540)
	canvas.add_child(bg)

	var label = Label.new()
	label.text = "КАДР НОЛЬ\n\nТы запечатлел то, что не должно существовать.\nТеперь оно смотрит на тебя."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-400, -150)
	label.size = Vector2(800, 300)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.3, 1))
	label.add_theme_constant_override("outline_size", 4)
	canvas.add_child(label)

	var tween = get_tree().create_tween()
	tween.tween_property(bg, "color", Color(0, 0, 0, 0.9), 2.0)
	await get_tree().create_timer(5.0).timeout
	GameManager.end_run(true)

func _on_flash_timeout():
	if sprite and is_instance_valid(self):
		match current_phase:
			Phase.ONE:
				sprite.modulate = Color(0.3, 0.1, 0.4, 1.0)
			Phase.TWO:
				sprite.modulate = Color(0.6, 0.1, 0.5, 1.0)
			Phase.THREE:
				sprite.modulate = Color(0.9, 0.0, 0.2, 1.0)

func _exit_tree():
	_clear_clones()
	gravity_active = false
