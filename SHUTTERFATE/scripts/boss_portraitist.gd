extends CharacterBody2D

# === ПОРТРЕТИСТ — Босс-Художник ===
# Фаза 1 (100-50%): стоит на месте, рисует силуэты, неуязвим между "рисованием"
# Фаза 2 (50-25%): движется, вспышки света (AoE)
# Фаза 3 (25-0%): призывает 4 силуэта, ускоряется

@export var max_hp: float = 300.0
@export var move_speed: float = 70.0
@export var attack_damage: int = 15
@export var attack_cooldown: float = 2.0

var hp: float = max_hp
var player: Node2D = null
var can_attack: bool = true

# Boss properties
var defense: float = 0.0
var is_smear: bool = false
var is_hidden: bool = false
var is_boss: bool = true

# Phase system
enum Phase { ONE, TWO, THREE }
var current_phase: int = Phase.ONE

# Phase 1: painting
var is_painting: bool = false
var paint_timer: Timer
var silhouette_scene = preload("res://scenes/enemy_smear.tscn")  # fallback

# Phase 2: flash AoE
var flash_aoe_scene: PackedScene = null
var flash_timer: Timer

# Phase 3: frenzy
var frenzy_spawn_timer: Timer

@onready var sprite: Sprite2D = $Sprite2D
var attack_timer: Timer
var flash_visual: Timer

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	add_to_group("bosses")

	# Scale HP by floor
	var floor = max(GameManager.current_floor, 1)
	max_hp = 300 + (floor - 1) * 80
	hp = max_hp

	# Timers
	attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.one_shot = true
	add_child(attack_timer)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	flash_visual = Timer.new()
	flash_visual.name = "FlashVisual"
	flash_visual.one_shot = true
	add_child(flash_visual)
	flash_visual.timeout.connect(_on_flash_timeout)

	paint_timer = Timer.new()
	paint_timer.name = "PaintTimer"
	paint_timer.one_shot = true
	add_child(paint_timer)
	paint_timer.timeout.connect(_on_paint_timeout)

	flash_timer = Timer.new()
	flash_timer.name = "FlashTimer"
	flash_timer.one_shot = true
	add_child(flash_timer)
	flash_timer.timeout.connect(_flash_attack)

	frenzy_spawn_timer = Timer.new()
	frenzy_spawn_timer.name = "FrenzyTimer"
	frenzy_spawn_timer.one_shot = true
	add_child(frenzy_spawn_timer)
	frenzy_spawn_timer.timeout.connect(_on_frenzy_spawn)

	# Visual
	if sprite:
		sprite.scale = Vector2(1.8, 1.8)
		sprite.modulate = Color(0.9, 0.4, 0.4, 1.0)

	# Start Phase 1
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

# ========== PHASE 1: The Painter ==========
func _start_phase_one():
	print("=== PHASE 1: The Painter ===")
	current_phase = Phase.ONE
	move_speed = 0  # Immobile
	defense = 0.9   # 90% damage reduction when NOT painting
	_paint_silhouette()

func _process_phase_one(_delta):
	# Stand still, paint silhouettes
	velocity = Vector2.ZERO
	move_and_slide()

func _paint_silhouette():
	if hp <= max_hp * 0.5:
		_transition_to_phase_two()
		return
	is_painting = true
	defense = 0.0  # Vulnerable while painting
	if sprite:
		sprite.modulate = Color(1.0, 0.8, 0.3, 1.0)  # Yellow = painting
		# Shake effect
		var tween = create_tween()
		tween.tween_property(sprite, "position:x", sprite.position.x + 3, 0.1)
		tween.tween_property(sprite, "position:x", sprite.position.x - 3, 0.1)
		tween.tween_property(sprite, "position:x", sprite.position.x, 0.1)

	# Spawn silhouette after 1.5s
	paint_timer.start(1.5)

func _on_paint_timeout():
	if not is_instance_valid(self):
		return
	_spawn_silhouette()
	is_painting = false
	defense = 0.9  # Back to invulnerable
	if sprite:
		sprite.modulate = Color(0.9, 0.4, 0.4, 1.0)

	# Next paint in 3-5 seconds
	if current_phase == Phase.ONE:
		var next = randf_range(3.0, 5.0)
		paint_timer.start(next)
		await paint_timer.timeout
		if is_instance_valid(self) and current_phase == Phase.ONE:
			_paint_silhouette()

func _spawn_silhouette():
	var scene = silhouette_scene
	if scene == null:
		return
	var sil = scene.instantiate()
	# Position near boss
	var offset = Vector2(randf_range(-80, 80), randf_range(-40, 40))
	sil.global_position = global_position + offset
	# Silhouette stats
	sil.max_hp = 15
	sil.hp = 15
	sil.move_speed = 60
	sil.attack_damage = 5
	sil.defense = 0
	sil.is_boss = false
	if sil.has_node("Sprite2D"):
		sil.get_node("Sprite2D").modulate = Color(0.3, 0.3, 0.4, 0.6)
		sil.get_node("Sprite2D").scale = Vector2(0.8, 0.8)
	var scene_node = get_tree().current_scene
	if scene_node:
		scene_node.add_child(sil)
	else:
		add_child(sil)
	print("Silhouette spawned!")

# ========== PHASE 2: The Flash ==========
func _transition_to_phase_two():
	print("=== PHASE 2: The Flash ===")
	current_phase = Phase.TWO
	move_speed = 90
	defense = 0.2
	if sprite:
		sprite.modulate = Color(1.0, 0.6, 0.2, 1.0)  # Orange
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.5)
	_flash_attack()

func _process_phase_two(_delta):
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

func _flash_attack():
	if hp <= max_hp * 0.25 or current_phase != Phase.TWO:
		return
	# Create AoE warning
	_create_flash_aoe()
	flash_timer.start(randf_range(2.5, 4.0))
	await flash_timer.timeout
	if is_instance_valid(self) and current_phase == Phase.TWO:
		_flash_attack()

func _create_flash_aoe():
	if player == null:
		return
	# Warning circle
	var warning = ColorRect.new()
	warning.color = Color(1.0, 0.9, 0.2, 0.3)
	warning.size = Vector2(120, 120)
	warning.position = player.global_position - Vector2(60, 60)
	warning.z_index = -10
	get_tree().current_scene.add_child(warning)

	# Explode after 1.0s
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(warning):
		warning.queue_free()

	# Damage if player still in range
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist < 150:
			player.take_damage(attack_damage)
			print("Flash hit!")

	# Visual flash
	if sprite:
		sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
		flash_visual.start(0.15)

func _on_flash_timeout():
	if sprite and is_instance_valid(self):
		match current_phase:
			Phase.TWO:
				sprite.modulate = Color(1.0, 0.6, 0.2, 1.0)
			Phase.THREE:
				sprite.modulate = Color(1.0, 0.1, 0.1, 1.0)

# ========== PHASE 3: The Frenzy ==========
func _transition_to_phase_three():
	print("=== PHASE 3: The Frenzy ===")
	current_phase = Phase.THREE
	move_speed = 130
	defense = 0.1
	if sprite:
		sprite.modulate = Color(1.0, 0.1, 0.1, 1.0)  # Deep red
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(2.2, 2.2), 0.3)

	# Spawn 4 silhouettes at once
	for i in range(4):
		_spawn_silhouette()

	# Continue spawning every 5 seconds
	frenzy_spawn_timer.start(5.0)

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

func _on_frenzy_spawn():
	if not is_instance_valid(self) or current_phase != Phase.THREE:
		return
	for i in range(2):
		_spawn_silhouette()
	frenzy_spawn_timer.start(5.0)

# ========== COMMON ==========
func _attack_player():
	can_attack = false
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)
	attack_timer.start(attack_cooldown)

func _on_attack_timer_timeout():
	can_attack = true

func take_damage(amount: float):
	# Apply defense
	var actual = amount * (1.0 - defense)
	hp -= actual

	if sprite:
		# White flash on hit
		sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
		flash_visual.start(0.1)

	# Phase transitions
	var hp_ratio = hp / max_hp
	if current_phase == Phase.ONE and hp_ratio <= 0.5:
		_transition_to_phase_two()
	elif current_phase == Phase.TWO and hp_ratio <= 0.25:
		_transition_to_phase_three()

	if hp <= 0:
		die()

func die():
	print("PORTRAITIST DEFEATED!")
	GameManager.add_boss_kill()
	# Drop reward
	_drop_reward()
	queue_free()

func _drop_reward():
	# Boss 1 (Portraitist) rewards — mid-tier, not legendary
	var prints_bonus = 50 * GameManager.current_floor
	GameManager.photo_prints += prints_bonus
	print("BOSS REWARD: +", prints_bonus, " prints")

	# Unlock Chroma film (green rarity — appropriate for first boss)
	if not "chroma" in GameManager.unlocked_films:
		GameManager.unlocked_films.append("chroma")
		print("UNLOCKED: Плёнка 'Хрома-400'!")

	# Unlock a green/blue relic (not legendary)
	var possible_relics = ["old_tripod", "photo_journal", "red_lamp"]
	var chosen = possible_relics[randi() % possible_relics.size()]
	if not RelicManager.has_relic(chosen):
		RelicManager.unlock(chosen)
		print("UNLOCKED: Реликвия '", RelicManager.get_relic(chosen).display_name, "'")
