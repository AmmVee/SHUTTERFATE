extends CharacterBody2D

@export var max_hp: float = 20.0
@export var move_speed: float = 160.0
@export var attack_damage: int = 5
@export var attack_range: float = 25.0
@export var attack_cooldown: float = 0.8

var hp: float = max_hp
var player: Node2D = null
var can_attack: bool = true

@onready var sprite: Sprite2D = $Sprite2D
var attack_timer: Timer
var flash_timer: Timer
var zigzag_timer: Timer

var move_dir: Vector2 = Vector2.ZERO
var zigzag_offset: float = 0.0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")

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

func _physics_process(_delta):
	if player == null:
		return

	# Fix z_index range
	z_index = clamp(int(global_position.y), -4000, 4000)

	var dist = global_position.distance_to(player.global_position)

	if dist < 250:
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

	if player:
		var knockback = global_position.direction_to(player.global_position) * -30
		global_position += knockback

	if hp <= 0:
		die()

func die():
	queue_free()

func _on_attack_timer_timeout():
	can_attack = true

func _on_flash_timer_timeout():
	if sprite:
		sprite.modulate = Color(1, 1, 1)

func _on_zigzag_timer_timeout():
	zigzag_offset += randf_range(1.5, 3.0)
	zigzag_timer.start(randf_range(0.2, 0.5))
