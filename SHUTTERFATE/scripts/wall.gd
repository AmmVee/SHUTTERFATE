extends StaticBody2D

var player: Node2D = null
var sprite: Sprite2D = null
var base_modulate: Color = Color.WHITE

func _ready():
	player = get_tree().get_first_node_in_group("player")
	sprite = get_node_or_null("Sprite2D")
	if sprite:
		base_modulate = sprite.modulate

func _process(_delta):
	if player == null or sprite == null:
		return
	var dy = player.global_position.y - global_position.y
	var dx = abs(player.global_position.x - global_position.x)
	# Player is "behind" wall (lower Y in iso = further back visually)
	if dy < -8 and dx < 50:
		sprite.modulate = base_modulate * Color(1, 1, 1, 0.2)
	else:
		sprite.modulate = base_modulate
