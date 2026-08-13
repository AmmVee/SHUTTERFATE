extends CharacterBody2D

# === КУРАТОР — Хранитель галереи ===
# Меняет экспозицию комнаты (темнота / яркий свет)
# Призывает движущиеся рамки (стены)
# Сам не атакует, контролирует пространство

@export var max_hp: float = 600.0
@export var move_speed: float = 40.0

var hp: float = max_hp
var player: Node2D = null

var defense: float = 0.0
var is_smear: bool = false
var is_hidden: bool = false
var is_boss: bool = true

enum Phase { ONE, TWO }
var current_phase: int = Phase.ONE

enum Exposure { DARK, BRIGHT }
var current_exposure: int = Exposure.DARK

var exposure_timer: Timer
var frame_spawn_timer: Timer
var flash_timer: Timer

var exposure_overlay: ColorRect = null
var active_frames: Array = []

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	add_to_group("bosses")

	var floor_num = max(GameManager.current_floor, 1)
	max_hp = 600 + (floor_num - 1) * 120
	hp = max_hp

	exposure_timer = Timer.new()
	exposure_timer.name = "ExposureTimer"
	exposure_timer.one_shot = true
	add_child(exposure_timer)
	exposure_timer.timeout.connect(_switch_exposure)

	frame_spawn_timer = Timer.new()
	frame_spawn_timer.name = "FrameSpawnTimer"
	frame_spawn_timer.one_shot = true
	add_child(frame_spawn_timer)
	frame_spawn_timer.timeout.connect(_spawn_frame)

	flash_timer = Timer.new()
	flash_timer.name = "FlashTimer"
	flash_timer.one_shot = true
	add_child(flash_timer)
	flash_timer.timeout.connect(_on_flash_timeout)

	if sprite:
		sprite.scale = Vector2(2.2, 2.2)
		sprite.modulate = Color(0.5, 0.4, 0.7, 1.0)

	_create_exposure_overlay()
	_start_phase_one()

func _physics_process(_delta):
	if player == null:
		return
	# Curator slowly orbits the room center
	var room = _get_current_room()
	var center = global_position
	if room and room.has_method("get_center"):
		center = room.global_position + room.get_center()
	var orbit_radius = 180.0
	var time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60
	var angle = float(time) * 0.3
	var target = center + Vector2(cos(angle), sin(angle) * 0.5) * orbit_radius
	var dir = global_position.direction_to(target)
	velocity = dir * move_speed
	move_and_slide()

# ========== EXPOSURE SYSTEM ==========
func _create_exposure_overlay():
	var canvas = CanvasLayer.new()
	canvas.name = "CuratorExposureOverlay"
	canvas.layer = 50
	get_tree().current_scene.add_child(canvas)

	exposure_overlay = ColorRect.new()
	exposure_overlay.name = "ExposureRect"
	exposure_overlay.color = Color(0, 0, 0, 0)
	exposure_overlay.size = Vector2(1920, 1080)
	exposure_overlay.position = Vector2(-960, -540)
	exposure_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(exposure_overlay)

func _remove_exposure_overlay():
	if exposure_overlay:
		var canvas = exposure_overlay.get_parent()
		if canvas:
			canvas.queue_free()
		exposure_overlay = null

func _switch_exposure():
	if not is_instance_valid(self):
		return

	if current_exposure == Exposure.DARK:
		current_exposure = Exposure.BRIGHT
		_apply_bright_exposure()
	else:
		current_exposure = Exposure.DARK
		_apply_dark_exposure()

	var next_time = 8.0
	if current_phase == Phase.TWO:
		next_time = 5.0
	exposure_timer.start(next_time)

func _apply_dark_exposure():
	print("=== EXPOSURE: DARK ===")
	if exposure_overlay:
		var tween = get_tree().create_tween()
		tween.tween_property(exposure_overlay, "color", Color(0, 0, 0, 0.75), 1.0)
	# Make enemies visible but dimmed
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e != self:
			var s = e.get_node_or_null("Sprite2D")
			if s:
				s.visible = true
				s.modulate.a = 0.3
	# Make player visible
	if player:
		var ps = player.get_node_or_null("Sprite2D")
		if ps:
			ps.modulate.a = 1.0

func _apply_bright_exposure():
	print("=== EXPOSURE: BRIGHT ===")
	if exposure_overlay:
		var tween = get_tree().create_tween()
		tween.tween_property(exposure_overlay, "color", Color(1, 1, 1, 0.65), 1.0)
	# Enemies become invisible (except boss)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e != self:
			var s = e.get_node_or_null("Sprite2D")
			if s:
				s.visible = false
	# Player stays visible
	if player:
		var ps = player.get_node_or_null("Sprite2D")
		if ps:
			ps.modulate.a = 1.0

func _reset_exposure():
	if exposure_overlay:
		var tween = get_tree().create_tween()
		tween.tween_property(exposure_overlay, "color", Color(0, 0, 0, 0), 0.5)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e != self:
			var s = e.get_node_or_null("Sprite2D")
			if s:
				s.visible = true
				s.modulate.a = 1.0

# ========== PHASE 1 ==========
func _start_phase_one():
	print("=== PHASE 1: The Curator ===")
	current_phase = Phase.ONE
	move_speed = 40
	defense = 0.2
	if sprite:
		sprite.modulate = Color(0.5, 0.4, 0.7, 1.0)
	exposure_timer.start(6.0)
	frame_spawn_timer.start(4.0)
	_apply_dark_exposure()

# ========== PHASE 2 ==========
func _transition_to_phase_two():
	print("=== PHASE 2: The Gallery ===")
	current_phase = Phase.TWO
	move_speed = 70
	defense = 0.1
	if sprite:
		sprite.modulate = Color(0.8, 0.3, 0.8, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(2.5, 2.5), 0.5)
	# Spawn extra frames immediately
	for i in range(2):
		_spawn_frame()

# ========== FRAMES (Moving Walls) ==========
func _spawn_frame():
	if not is_instance_valid(self):
		return

	var room = _get_current_room()
	if room == null:
		return

	var room_center = room.global_position + room.get_center() if room.has_method("get_center") else room.global_position
	var angle = randf() * TAU
	var dist = randf_range(100, 280)
	var start_pos = room_center + Vector2(cos(angle), sin(angle) * 0.5) * dist

	var frame = StaticBody2D.new()
	frame.name = "GalleryFrame"
	frame.global_position = start_pos
	frame.add_to_group("curator_frames")

	# Frame sprite
	var fs = Sprite2D.new()
	fs.texture = load("res://assets/wall_iso.png")
	fs.modulate = Color(0.7, 0.5, 0.9, 0.9)
	fs.scale = Vector2(1.2, 1.2)
	frame.add_child(fs)

	# Collision
	var fcoll = CollisionShape2D.new()
	fcoll.shape = RectangleShape2D.new()
	fcoll.shape.size = Vector2(60, 30)
	fcoll.position = Vector2(0, -8)
	frame.add_child(fcoll)

	get_tree().current_scene.add_child(frame)
	active_frames.append(frame)

	# Movement pattern
	var move_dir = Vector2(cos(angle + PI/2), sin(angle + PI/2) * 0.5).normalized()
	var move_dist = randf_range(80, 180)
	var move_time = randf_range(2.5, 4.0)
	if current_phase == Phase.TWO:
		move_time = randf_range(1.5, 2.5)

	var tween = get_tree().create_tween()
	tween.set_loops()
	tween.tween_property(frame, "global_position", start_pos + move_dir * move_dist, move_time)
	tween.tween_property(frame, "global_position", start_pos - move_dir * move_dist, move_time)

	# Store tween to stop later
	frame.set_meta("move_tween", tween)

	var next_time = randf_range(5.0, 8.0)
	if current_phase == Phase.TWO:
		next_time = randf_range(3.0, 5.0)
	frame_spawn_timer.start(next_time)

func _clear_frames():
	for f in active_frames:
		if is_instance_valid(f):
			var tween = f.get_meta("move_tween", null)
			if tween:
				tween.kill()
			f.queue_free()
	active_frames.clear()

# ========== DAMAGE & DEATH ==========
func take_damage(amount: float):
	var actual = amount * (1.0 - defense)
	hp -= actual
	if sprite:
		sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
		flash_timer.start(0.1)
	var hp_ratio = hp / max_hp
	if current_phase == Phase.ONE and hp_ratio <= 0.6:
		_transition_to_phase_two()
	if hp <= 0:
		die()

func die():
	print("CURATOR DEFEATED!")
	_reset_exposure()
	_remove_exposure_overlay()
	_clear_frames()
	GameManager.add_boss_kill()
	_drop_reward()
	queue_free()

func _drop_reward():
	var prints_bonus = 150 * GameManager.current_floor
	GameManager.photo_prints += prints_bonus
	print("BOSS REWARD: +", prints_bonus, " prints")
	if not "xpro" in GameManager.unlocked_films:
		GameManager.unlocked_films.append("xpro")
		print("UNLOCKED: Плёнка 'Кросс-процесс'!")
	var possible_relics = ["lumiere_card", "mirror_shard", "wet_print"]
	var chosen = possible_relics[randi() % possible_relics.size()]
	if not RelicManager.has_relic(chosen):
		RelicManager.unlock(chosen)
		print("UNLOCKED: Реликвия '", RelicManager.get_relic(chosen).display_name, "'")

func _on_flash_timeout():
	if sprite and is_instance_valid(self):
		match current_phase:
			Phase.ONE:
				sprite.modulate = Color(0.5, 0.4, 0.7, 1.0)
			Phase.TWO:
				sprite.modulate = Color(0.8, 0.3, 0.8, 1.0)

func _get_current_room() -> Node2D:
	var main = get_tree().current_scene
	if main and main.has_method("get"):
		var fg = main.get_node_or_null("FloorGenerator")
		if fg and fg.has_method("get_current_room"):
			return fg.get_current_room()
	return null

func _exit_tree():
	# Cleanup if boss dies or scene changes
	_reset_exposure()
	_remove_exposure_overlay()
	_clear_frames()
