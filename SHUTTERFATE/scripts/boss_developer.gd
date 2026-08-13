extends CharacterBody2D

# === ПРОЯВЩИК — Босс-Алхимик тёмной комнаты ===
# Фаза 1 (100-60%): кидает кислотные банки, оставляет лужи реактивов
# Фаза 2 (60-25%): ускоряется, лужи расширяются
# Фаза 3 (25-0%): бешенство, взрывная смерть — нужно убежать к двери

@export var max_hp: float = 450.0
@export var move_speed: float = 60.0
@export var attack_damage: int = 18
@export var attack_cooldown: float = 2.5

var hp: float = max_hp
var player: Node2D = null
var can_attack: bool = true

var defense: float = 0.0
var is_smear: bool = false
var is_hidden: bool = false
var is_boss: bool = true

enum Phase { ONE, TWO, THREE }
var current_phase: int = Phase.ONE

var jar_timer: Timer
var puddle_timer: Timer
var active_puddles: Array = []
var active_jars: Array = []

var frenzy_timer: Timer
var death_explosion_timer: Timer
var explosion_warning_shown: bool = false

@onready var sprite: Sprite2D = $Sprite2D
var attack_timer: Timer
var flash_timer: Timer

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	add_to_group("bosses")

	var floor_num = max(GameManager.current_floor, 1)
	max_hp = 450 + (floor_num - 1) * 100
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
	flash_timer.timeout.connect(_on_flash_timer_timeout)

	jar_timer = Timer.new()
	jar_timer.name = "JarTimer"
	jar_timer.one_shot = true
	add_child(jar_timer)
	jar_timer.timeout.connect(_throw_acid_jar)

	puddle_timer = Timer.new()
	puddle_timer.name = "PuddleTimer"
	puddle_timer.one_shot = true
	add_child(puddle_timer)
	puddle_timer.timeout.connect(_spawn_puddle)

	frenzy_timer = Timer.new()
	frenzy_timer.name = "FrenzyTimer"
	frenzy_timer.one_shot = true
	add_child(frenzy_timer)
	frenzy_timer.timeout.connect(_on_frenzy_action)

	death_explosion_timer = Timer.new()
	death_explosion_timer.name = "DeathExplosionTimer"
	death_explosion_timer.one_shot = true
	add_child(death_explosion_timer)
	death_explosion_timer.timeout.connect(_death_explosion)

	if sprite:
		sprite.scale = Vector2(2.0, 2.0)
		sprite.modulate = Color(0.4, 0.7, 0.3, 1.0)

	_start_phase_one()

func _physics_process(delta):
	if player == null:
		return
	match current_phase:
		Phase.ONE:
			_process_phase_one(delta)
		Phase.TWO:
			_process_phase_two(delta)
		Phase.THREE:
			_process_phase_three(delta)
	_update_jars(delta)
	_check_puddle_damage(delta)

# ========== PHASE 1 ==========
func _start_phase_one():
	print("=== PHASE 1: The Alchemist ===")
	current_phase = Phase.ONE
	move_speed = 60
	defense = 0.15
	if sprite:
		sprite.modulate = Color(0.4, 0.7, 0.3, 1.0)
	jar_timer.start(randf_range(2.0, 4.0))
	puddle_timer.start(randf_range(4.0, 7.0))

func _process_phase_one(_delta):
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	var ideal_dist = 200.0
	if dist > ideal_dist + 30:
		var dir = global_position.direction_to(player.global_position)
		velocity = dir * move_speed
	elif dist < ideal_dist - 30:
		var dir = global_position.direction_to(player.global_position)
		velocity = -dir * move_speed * 0.7
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _throw_acid_jar():
	if not is_instance_valid(self) or current_phase == Phase.THREE:
		return
	if player == null:
		return
	_create_jar()
	jar_timer.start(randf_range(2.5, 4.5))

func _create_jar():
	var jar = CharacterBody2D.new()
	jar.name = "AcidJar"
	jar.global_position = global_position

	var jar_sprite = Sprite2D.new()
	jar_sprite.texture = load("res://assets/enemy_iso.png")
	jar_sprite.modulate = Color(0.2, 0.9, 0.2, 1.0)
	jar_sprite.scale = Vector2(0.6, 0.6)
	jar.add_child(jar_sprite)

	var coll = CollisionShape2D.new()
	coll.shape = CircleShape2D.new()
	coll.shape.radius = 12.0
	jar.add_child(coll)

	var dir = global_position.direction_to(player.global_position)
	jar.set_meta("jar_velocity", dir * 180.0)
	jar.set_meta("jar_exploded", false)

	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 3.0
	timer.timeout.connect(func(): _explode_jar(jar))
	jar.add_child(timer)
	timer.start()

	var scene = get_tree().current_scene
	if scene:
		scene.add_child(jar)
		active_jars.append(jar)

func _update_jars(delta):
	var to_remove = []
	for jar in active_jars:
		if not is_instance_valid(jar) or jar.get_meta("jar_exploded", false):
			to_remove.append(jar)
			continue
		var vel = jar.get_meta("jar_velocity", Vector2.ZERO)
		var collision = jar.move_and_collide(vel * delta)
		if collision:
			_explode_jar(jar)
	for jar in to_remove:
		active_jars.erase(jar)

func _explode_jar(jar):
	if not is_instance_valid(jar) or jar.get_meta("jar_exploded", false):
		return
	jar.set_meta("jar_exploded", true)

	# Splash damage
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
	_create_puddle(jar.global_position)

	# Visual flash
	var boom = Sprite2D.new()
	boom.texture = load("res://assets/enemy_iso.png")
	boom.modulate = Color(0.3, 1.0, 0.3, 0.6)
	boom.scale = Vector2(2.0, 2.0)
	boom.global_position = jar.global_position
	boom.z_index = 50
	get_tree().current_scene.add_child(boom)
	var tween = get_tree().create_tween()
	tween.tween_property(boom, "scale", Vector2(3, 3), 0.2)
	tween.tween_property(boom, "modulate:a", 0.0, 0.3)
	tween.tween_callback(boom.queue_free)

	jar.queue_free()

func _spawn_puddle():
	if not is_instance_valid(self) or current_phase == Phase.THREE:
		return
	var offset = Vector2(randf_range(-120, 120), randf_range(-80, 80))
	_create_puddle(global_position + offset)
	var next_time = randf_range(5.0, 8.0)
	if current_phase == Phase.TWO:
		next_time = randf_range(3.0, 5.0)
	puddle_timer.start(next_time)

func _create_puddle(pos: Vector2):
	var puddle = Area2D.new()
	puddle.name = "ReactivePuddle"
	puddle.global_position = pos
	puddle.add_to_group("acid_puddles")

	var ps = Sprite2D.new()
	ps.texture = load("res://assets/floor_iso.png")
	ps.modulate = Color(0.1, 0.8, 0.1, 0.45)
	ps.scale = Vector2(1.8, 1.8)
	puddle.add_child(ps)

	var pshape = CollisionShape2D.new()
	pshape.shape = CircleShape2D.new()
	pshape.shape.radius = 55.0
	puddle.add_child(pshape)

	puddle.set_meta("damage_per_sec", 8)

	var scene = get_tree().current_scene
	if scene:
		scene.add_child(puddle)
		active_puddles.append(puddle)
		var tween = get_tree().create_tween()
		tween.tween_property(ps, "modulate:a", 0.0, 10.0)
		tween.tween_callback(func():
			if is_instance_valid(puddle):
				puddle.queue_free()
			active_puddles.erase(puddle)
		)

# ========== PHASE 2 ==========
func _transition_to_phase_two():
	print("=== PHASE 2: The Accelerant ===")
	current_phase = Phase.TWO
	move_speed = 100
	defense = 0.25
	if sprite:
		sprite.modulate = Color(0.8, 0.9, 0.2, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(2.2, 2.2), 0.5)
	for p in active_puddles:
		if is_instance_valid(p):
			var ps = p.get_node_or_null("Sprite2D")
			if ps:
				var tween = get_tree().create_tween()
				tween.tween_property(ps, "scale", Vector2(2.5, 2.5), 1.0)
			var pshape = p.get_node_or_null("CollisionShape2D")
			if pshape and pshape.shape:
				pshape.shape.radius = 80.0
			p.set_meta("damage_per_sec", 12)
	puddle_timer.start(randf_range(3.0, 5.0))

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

# ========== PHASE 3 ==========
func _transition_to_phase_three():
	print("=== PHASE 3: The Catalyst ===")
	current_phase = Phase.THREE
	move_speed = 140
	defense = 0.1
	if sprite:
		sprite.modulate = Color(0.9, 0.1, 0.1, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(2.4, 2.4), 0.3)
	for i in range(5):
		var angle = (TAU / 5.0) * i
		var offset = Vector2(cos(angle), sin(angle) * 0.5) * randf_range(80, 150)
		_create_puddle(global_position + offset)
	frenzy_timer.start(3.0)

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

func _on_frenzy_action():
	if not is_instance_valid(self) or current_phase != Phase.THREE:
		return
	for i in range(3):
		await get_tree().create_timer(0.4).timeout
		if is_instance_valid(self) and current_phase == Phase.THREE:
			var jar = CharacterBody2D.new()
			jar.name = "AcidJar"
			jar.global_position = global_position
			var jar_sprite = Sprite2D.new()
			jar_sprite.texture = load("res://assets/enemy_iso.png")
			jar_sprite.modulate = Color(0.2, 0.9, 0.2, 1.0)
			jar_sprite.scale = Vector2(0.6, 0.6)
			jar.add_child(jar_sprite)
			var coll = CollisionShape2D.new()
			coll.shape = CircleShape2D.new()
			coll.shape.radius = 12.0
			jar.add_child(coll)
			var spread_dir = global_position.direction_to(player.global_position).rotated(randf_range(-0.5, 0.5))
			jar.set_meta("jar_velocity", spread_dir * 180.0)
			jar.set_meta("jar_exploded", false)
			var timer = Timer.new()
			timer.one_shot = true
			timer.wait_time = 3.0
			timer.timeout.connect(func(): _explode_jar(jar))
			jar.add_child(timer)
			timer.start()
			var scene = get_tree().current_scene
			if scene:
				scene.add_child(jar)
				active_jars.append(jar)
	frenzy_timer.start(randf_range(4.0, 6.0))

# ========== PUDDLE DAMAGE ==========
func _check_puddle_damage(delta):
	if player == null:
		return
	var puddles = get_tree().get_nodes_in_group("acid_puddles")
	for p in puddles:
		if not is_instance_valid(p):
			continue
		var bodies = p.get_overlapping_bodies()
		for b in bodies:
			if b.is_in_group("player") and b.has_method("take_damage"):
				var dps = p.get_meta("damage_per_sec", 5)
				b.take_damage(int(dps * delta))

# ========== DEATH EXPLOSION ==========
func _start_death_sequence():
	print("=== DEATH SEQUENCE STARTED ===")
	explosion_warning_shown = true
	var warning = Label.new()
	warning.text = "⚠ УБЕГАЙТЕ! ВЗРЫВ ЧЕРЕЗ 5 СЕК! ⚠"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.position = Vector2(-200, -120)
	warning.add_theme_font_size_override("font_size", 20)
	warning.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	warning.add_theme_constant_override("outline_size", 3)
	add_child(warning)

	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2, 0, 0, 1), 0.2)
		tween.tween_property(sprite, "modulate", Color(1, 0, 0, 1), 0.2)
		tween.set_loops(10)

	death_explosion_timer.start(5.0)
	await get_tree().create_timer(5.5).timeout
	if is_instance_valid(warning):
		warning.queue_free()

func _death_explosion():
	if not is_instance_valid(self):
		return
	print("=== BOOM! ===")

	var explosion_area = Area2D.new()
	explosion_area.global_position = global_position
	var eshape = CollisionShape2D.new()
	eshape.shape = CircleShape2D.new()
	eshape.shape.radius = 400.0
	explosion_area.add_child(eshape)
	get_tree().current_scene.add_child(explosion_area)

	var boom = Sprite2D.new()
	boom.texture = load("res://assets/enemy_iso.png")
	boom.modulate = Color(1.0, 0.5, 0.0, 0.8)
	boom.scale = Vector2(8.0, 8.0)
	boom.global_position = global_position
	boom.z_index = 100
	get_tree().current_scene.add_child(boom)

	var tween = get_tree().create_tween()
	tween.tween_property(boom, "scale", Vector2(12, 12), 0.3)
	tween.tween_property(boom, "modulate:a", 0.0, 0.5)
	tween.tween_callback(boom.queue_free)

	await get_tree().create_timer(0.1).timeout
	var bodies = explosion_area.get_overlapping_bodies()
	for b in bodies:
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(80)
			print("Explosion hit player!")
	explosion_area.queue_free()
	_actual_die()

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
	if current_phase == Phase.ONE and hp_ratio <= 0.6:
		_transition_to_phase_two()
	elif current_phase == Phase.TWO and hp_ratio <= 0.25:
		_transition_to_phase_three()
	if hp <= 0 and not explosion_warning_shown:
		_start_death_sequence()

func die():
	if not explosion_warning_shown:
		_start_death_sequence()

func _actual_die():
	print("DEVELOPER DEFEATED!")
	GameManager.add_boss_kill()
	_drop_reward()
	queue_free()

func _drop_reward():
	var prints_bonus = 75 * GameManager.current_floor
	GameManager.photo_prints += prints_bonus
	print("BOSS REWARD: +", prints_bonus, " prints")
	if not "noir" in GameManager.unlocked_films:
		GameManager.unlocked_films.append("noir")
		print("UNLOCKED: Плёнка 'Нуар-32'!")
	var possible_relics = ["fingerprint", "broken_uv", "remote_trigger"]
	var chosen = possible_relics[randi() % possible_relics.size()]
	if not RelicManager.has_relic(chosen):
		RelicManager.unlock(chosen)
		print("UNLOCKED: Реликвия '", RelicManager.get_relic(chosen).display_name, "'")

func _on_flash_timer_timeout():
	if sprite and is_instance_valid(self):
		match current_phase:
			Phase.ONE:
				sprite.modulate = Color(0.4, 0.7, 0.3, 1.0)
			Phase.TWO:
				sprite.modulate = Color(0.8, 0.9, 0.2, 1.0)
			Phase.THREE:
				sprite.modulate = Color(0.9, 0.1, 0.1, 1.0)
