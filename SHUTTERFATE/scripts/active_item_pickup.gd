extends Node2D

@export var item_id: String = ""
@export var possible_items: Array = ["flash_bomb", "heal_pack", "time_freeze", "damage_boost", "shield", "teleport"]

var area: Area2D
var bob_time: float = 0.0

func _ready():
	if item_id == "" or item_id == "random":
		item_id = possible_items[randi() % possible_items.size()]

	var item_data = GameManager.get_active_item_data(item_id)

	# Visual
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/enemy.png")
	if not item_data.is_empty():
		sprite.modulate = item_data.icon_color
	else:
		sprite.modulate = Color(1, 1, 1)
	add_child(sprite)

	# Glow effect
	var light = PointLight2D.new()
	light.texture = preload("res://assets/enemy.png")
	light.energy = 0.5
	light.texture_scale = 2.0
	if not item_data.is_empty():
		light.color = item_data.icon_color
	add_child(light)

	# Collision
	area = Area2D.new()
	area.add_to_group("collectible")
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 16
	area.add_child(shape)
	add_child(area)

	area.body_entered.connect(_on_body_entered)

func _process(delta):
	bob_time += delta * 3.0
	position.y += sin(bob_time) * 0.3

func _on_body_entered(body):
	if body.is_in_group("player"):
		if GameManager.add_active_item_to_hotbar(item_id):
			queue_free()
		else:
			var main = get_tree().get_first_node_in_group("main")
			if main and main.has_method("_show_message"):
				main._show_message("Хотбар полон!")
