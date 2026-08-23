extends CharacterBody2D

@export var max_hp: float = 20.0
@export var move_speed: float = 160.0
@export var attack_damage: int = 5
@export var attack_range: float = 25.0
@export var attack_cooldown: float = 0.8

var hp: float = max_hp
var player: Node2D = null
var can_attack: bool = true

# NEW: Film-related properties
var defense: float = 0.0
var is_smear: bool = false
var is_hidden: bool = false
var is_boss: bool = false

@onready var sprite: Sprite2D = $Sprite2D
var attack_timer: Timer
var flash_timer: Timer
var zigzag_timer: Timer

var move_dir: Vector2 = Vector2.ZERO
var zigzag_offset: float = 0.0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")

	# Floor scaling
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

	zigzag_timer = get_node_or_null("ZigzagTimer")
	if zigzag_timer == null:
		zigzag_timer = Timer.new()
		zigzag_timer.name = "ZigzagTimer"
		zigzag_timer.one_shot = true
		add_child(zigzag_timer)

	attack_timer.timeout.connect(_on_attack_timer_timeout)
	flash_timer.timeout.connect(_on_flash_timer_timeout)
	zigzag_timer.timeout.connect(_on_zigzag_timer_timeout)

	move_dir = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()
	zigzag_timer.start(0.3)

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
	# Relic: Red Lamp (enemies detect 30% later)
	var detect_range = 250.0 * RelicManager.get_enemy_detect_multiplier()
	if dist < detect_range:
		var to_player = global_position.direction_to(player.global_position)
		var perpendicular = Vector2(-to_player.y, to_player.x)
		move_dir = (to_player + perpendicular * sin(zigzag_offset) * 1.5).normalized()
		velocity = move_dir * move_speed
	else:
		velocity = move_dir * (move_speed * 0.5)
	move_and_slide()
	if dist < attack_range and can_attack:
		attack()

func attack():
	can_attack = false
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)
	attack_timer.start(attack_cooldown)

func take_damage(amount: float):
	hp -= amount
	if sprite:
		sprite.modulate = Color(1, 0.3, 0.3)
	flash_timer.start(0.1)
	spawn_blood()
	play_sfx("res://assets/sounds/hit.wav")
	if player:
		var knockback_dir = global_position.direction_to(player.global_position) * -1
		move_and_collide(knockback_dir * 30.0)
	if hp <= 0:
		die()

var is_elite: bool = false

func die():
	# Relic: Mother Negative (ghost copy for 3 sec)
	if RelicManager.has_ghost_copy():
		_create_ghost_copy()

	# Drop relic
	_drop_relic()

	queue_free()

func _drop_relic():
	var roll = randf()
	var rarity = ""

	if is_elite:
		# Elite: 5% green/blue
		if roll < 0.05:
			rarity = "green" if randf() < 0.7 else "blue"
	else:
		# Normal: 2% white
		if roll < 0.02:
			rarity = "white"

	if rarity == "":
		return

	# Find random unowned relic of this rarity
	var candidates = []
	for id in RelicManager.all_relics.keys():
		if RelicManager.all_relics[id].rarity == rarity and not RelicManager.has_relic(id):
			candidates.append(id)

	if candidates.size() > 0:
		var chosen = candidates[randi() % candidates.size()]
		RelicManager.unlock(chosen)
		var r = RelicManager.get_relic(chosen)
		print("DROP from ", "elite " if is_elite else "", "smear: ", r.display_name if r else chosen)
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
		sprite.modulate = Color(1, 1, 1)
		_update_hidden_visibility()

func _on_zigzag_timer_timeout():
	zigzag_offset += randf_range(1.5, 3.0)
	zigzag_timer.start(randf_range(0.2, 0.5))


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

func play_sfx(stream_path: String):
	var sfx = AudioStreamPlayer.new()
	sfx.stream = load(stream_path)
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(func(): sfx.queue_free())
