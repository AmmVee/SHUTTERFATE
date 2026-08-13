extends CharacterBody2D

# === ФОТОЖУРНАЛИСТ — Босс-Репортёр ===
# Телепортируется со вспышкой, ослепляет игрока, уклоняется от прицела
# Фаза 1 (100-50%): телепортация + одиночные вспышки
# Фаза 2 (50-0%): серия из 3 телепортаций, вспышки чаще, уклонение усилено

@export var max_hp: float = 280.0
@export var move_speed: float = 160.0
@export var attack_damage: int = 12
@export var attack_cooldown: float = 1.5

var hp: float = max_hp
var player: Node2D = null
var can_attack: bool = true

var defense: float = 0.0
var is_smear: bool = false
var is_hidden: bool = false
var is_boss: bool = true

enum Phase { ONE, TWO }
var current_phase: int = Phase.ONE

var teleport_timer: Timer
var flash_attack_timer: Timer
var dodge_timer: Timer

var teleport_cooldown: float = 3.0
var flash_cooldown: float = 4.0

@onready var sprite: Sprite2D = $Sprite2D
var attack_timer: Timer
var flash_visual_timer: Timer

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	add_to_group("bosses")

	var floor_num = max(GameManager.current_floor, 1)
	max_hp = 280 + (floor_num - 1) * 60
	hp = max_hp

	attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.one_shot = true
	add_child(attack_timer)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	flash_visual_timer = Timer.new()
	flash_visual_timer.name = "FlashVisualTimer"
	flash_visual_timer.one_shot = true
	add_child(flash_visual_timer)
	flash_visual_timer.timeout.connect(_on_flash_visual_timeout)

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

	dodge_timer = Timer.new()
	dodge_timer.name = "DodgeTimer"
	dodge_timer.one_shot = true
	add_child(dodge_timer)
	dodge_timer.timeout.connect(_check_dodge)

	if sprite:
		sprite.scale = Vector2(1.6, 1.6)
		sprite.modulate = Color(0.7, 0.7, 0.9, 1.0)

	_start_phase_one()

func _physics_process(delta):
	if player == null:
		return
	match current_phase:
		Phase.ONE:
			_process_phase_one(delta)
		Phase.TWO:
			_process_phase_two(delta)
	_check_dodge_condition()

# ========== PHASE 1 ==========
func _start_phase_one():
	print("=== PHASE 1: The Photojournalist ===")
	current_phase = Phase.ONE
	move_speed = 160
	defense = 0.1
	teleport_cooldown = 3.5
	flash_cooldown = 4.5
	if sprite:
		sprite.modulate = Color(0.7, 0.7, 0.9, 1.0)
	teleport_timer.start(randf_range(2.0, 4.0))
	flash_attack_timer.start(randf_range(3.0, 5.0))

func _process_phase_one(_delta):
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist > 80:
		var dir = global_position.direction_to(player.global_position)
		velocity = dir * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if dist < 50 and can_attack:
		_attack_player()

# ========== PHASE 2 ==========
func _transition_to_phase_two():
	print("=== PHASE 2: The Scoop ===")
	current_phase = Phase.TWO
	move_speed = 200
	defense = 0.05
	teleport_cooldown = 2.0
	flash_cooldown = 2.5
	if sprite:
		sprite.modulate = Color(0.9, 0.3, 0.9, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.8, 1.8), 0.3)
	# Triple teleport sequence
	_teleport_sequence()

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
	if dist < 45 and can_attack:
		_attack_player()

# ========== TELEPORT ==========
func _teleport():
	if not is_instance_valid(self):
		return
	if player == null:
		return

	# Flash effect at current position
	_create_teleport_flash(global_position)

	# Find random position around player (but not too close)
	var room = _get_current_room()
	var new_pos: Vector2
	var attempts = 0
	while attempts < 10:
		var angle = randf() * TAU
		var dist = randf_range(120, 350)
		new_pos = player.global_position + Vector2(cos(angle), sin(angle) * 0.5) * dist
		if room and room.has_method("is_position_inside_floor"):
			if room.is_position_inside_floor(new_pos):
				break
		elif new_pos.distance_to(player.global_position) > 100:
			break
		attempts += 1

	global_position = new_pos

	# Flash at new position
	_create_teleport_flash(new_pos)

	# Next teleport
	var next_time = teleport_cooldown * randf_range(0.8, 1.3)
	teleport_timer.start(next_time)

func _teleport_sequence():
	for i in range(3):
		await get_tree().create_timer(0.4).timeout
		if is_instance_valid(self) and current_phase == Phase.TWO:
			_teleport()

func _create_teleport_flash(pos: Vector2):
	var flash = Sprite2D.new()
	flash.texture = load("res://assets/enemy_iso.png")
	flash.modulate = Color(1.0, 1.0, 1.0, 0.8)
	flash.scale = Vector2(3.0, 3.0)
	flash.global_position = pos
	flash.z_index = 100
	get_tree().current_scene.add_child(flash)

	var tween = get_tree().create_tween()
	tween.tween_property(flash, "scale", Vector2(5, 5), 0.15)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)

# ========== FLASH ATTACK (BLIND) ==========
func _flash_attack():
	if not is_instance_valid(self) or player == null:
		return

	# Only flash if player is within range
	var dist = global_position.distance_to(player.global_position)
	if dist < 300:
		# Visual flash on boss
		if sprite:
			sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
			flash_visual_timer.start(0.2)

		# Create expanding flash ring
		_create_flash_ring()

		# Blind player
		if player and player.has_method("apply_blind"):
			player.apply_blind(1.0)
			print("Photojournalist BLINDED player!")

	var next_time = flash_cooldown * randf_range(0.8, 1.2)
	flash_attack_timer.start(next_time)

func _create_flash_ring():
	var ring = Sprite2D.new()
	ring.texture = load("res://assets/enemy_iso.png")
	ring.modulate = Color(1.0, 1.0, 0.8, 0.5)
	ring.scale = Vector2(1.0, 1.0)
	ring.global_position = global_position
	ring.z_index = 90
	get_tree().current_scene.add_child(ring)

	var tween = get_tree().create_tween()
	tween.tween_property(ring, "scale", Vector2(8.0, 8.0), 0.5)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)

# ========== DODGE ==========
func _check_dodge_condition():
	if player == null or not is_instance_valid(self):
		return
	# If player is aiming at us and we're in aim area, chance to dodge
	if player.is_aiming and dodge_timer.is_stopped():
		var dist = global_position.distance_to(player.global_position)
		if dist < 200:
			var dodge_chance = 0.25
			if current_phase == Phase.TWO:
				dodge_chance = 0.45
			if randf() < dodge_chance:
				_dodge()
				dodge_timer.start(randf_range(1.5, 3.0))

func _dodge():
	if not is_instance_valid(self) or player == null:
		return
	# Dodge perpendicular to player aim
	var to_player = global_position.direction_to(player.global_position)
	var dodge_dir = to_player.rotated(PI / 2 * (1 if randf() < 0.5 else -1))
	var dodge_dist = randf_range(80, 150)
	var target = global_position + dodge_dir * dodge_dist

	# Visual dodge
	if sprite:
		var tween = create_tween()
		tween.tween_property(self, "global_position", target, 0.15)
		var ghost = Sprite2D.new()
		ghost.texture = sprite.texture
		ghost.modulate = Color(0.7, 0.7, 0.9, 0.3)
		ghost.scale = sprite.scale
		ghost.global_position = global_position
		ghost.z_index = sprite.z_index - 1
		get_tree().current_scene.add_child(ghost)
		var gtween = get_tree().create_tween()
		gtween.tween_property(ghost, "modulate:a", 0.0, 0.3)
		gtween.tween_callback(ghost.queue_free)
	else:
		global_position = target

	print("Photojournalist DODGED!")

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
		flash_visual_timer.start(0.1)
	var hp_ratio = hp / max_hp
	if current_phase == Phase.ONE and hp_ratio <= 0.5:
		_transition_to_phase_two()
	if hp <= 0:
		die()

func die():
	print("PHOTOJOURNALIST DEFEATED!")
	GameManager.add_boss_kill()
	_drop_reward()
	queue_free()

func _drop_reward():
	var prints_bonus = 100 * GameManager.current_floor
	GameManager.photo_prints += prints_bonus
	print("BOSS REWARD: +", prints_bonus, " prints")
	if not "infrared" in GameManager.unlocked_films:
		GameManager.unlocked_films.append("infrared")
		print("UNLOCKED: Плёнка 'Инфракраска'!")
	var possible_relics = ["mother_negative", "empty_cassette", "pocket_reflector"]
	var chosen = possible_relics[randi() % possible_relics.size()]
	if not RelicManager.has_relic(chosen):
		RelicManager.unlock(chosen)
		print("UNLOCKED: Реликвия '", RelicManager.get_relic(chosen).display_name, "'")

func _on_flash_visual_timeout():
	if sprite and is_instance_valid(self):
		match current_phase:
			Phase.ONE:
				sprite.modulate = Color(0.7, 0.7, 0.9, 1.0)
			Phase.TWO:
				sprite.modulate = Color(0.9, 0.3, 0.9, 1.0)

func _get_current_room() -> Node2D:
	var main = get_tree().current_scene
	if main and main.has_method("get"):
		var fg = main.get_node_or_null("FloorGenerator")
		if fg and fg.has_method("get_current_room"):
			return fg.get_current_room()
	return null
