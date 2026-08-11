extends Node

var photo_prints: int = 0
var total_deaths: int = 0
var total_kills: int = 0
var camera_level: int = 1
var unlocked_films: Array = ["obskura"]

# ========== CAMERA UPGRADE SYSTEM (Meta-Progression) ==========
var camera_upgrades = {
	"damage": {"level": 0, "max": 5, "costs": [50, 100, 200, 400, 800], "name": "Усиленный объектив", "desc": "+5% базового урона"},
	"hp": {"level": 0, "max": 5, "costs": [30, 60, 120, 240, 480], "name": "Прочный корпус", "desc": "+5 макс HP"},
	"reload": {"level": 0, "max": 5, "costs": [80, 160, 320, 640, 1280], "name": "Быстрая перемотка", "desc": "+10% скорость перезарядки"},
	"frames": {"level": 0, "max": 3, "costs": [100, 200, 400], "name": "Удлинённая кассета", "desc": "+1 кадр в кассете"},
	"speed": {"level": 0, "max": 5, "costs": [40, 80, 160, 320, 640], "name": "Лёгкий штатив", "desc": "+5% скорость движения"},
	"range": {"level": 0, "max": 5, "costs": [60, 120, 240, 480, 960], "name": "Телеобъектив", "desc": "+10% дальность прицела"}
}

func get_upgrade_level(id: String) -> int:
	return camera_upgrades[id].level

func can_upgrade(id: String) -> bool:
	var up = camera_upgrades[id]
	return up.level < up.max and photo_prints >= up.costs[up.level]

func buy_upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	var up = camera_upgrades[id]
	photo_prints -= up.costs[up.level]
	up.level += 1
	print("Upgrade purchased: ", up.name, " level ", up.level)
	return true

# Combined bonuses: camera level + upgrades
func get_camera_bonus_damage() -> float:
	var level_bonus = 1.0 + (camera_level - 1) * 0.1
	var upgrade_bonus = 1.0 + camera_upgrades["damage"].level * 0.05
	return level_bonus * upgrade_bonus

func get_camera_bonus_hp() -> int:
	return (camera_level - 1) * 5 + camera_upgrades["hp"].level * 5

func get_upgrade_bonus_reload() -> float:
	return 1.0 - camera_upgrades["reload"].level * 0.1

func get_upgrade_bonus_frames() -> int:
	return camera_upgrades["frames"].level

func get_upgrade_bonus_speed() -> float:
	return 1.0 + camera_upgrades["speed"].level * 0.05

func get_upgrade_bonus_range() -> float:
	return 1.0 + camera_upgrades["range"].level * 0.1

# ========== SHOP SYSTEM ==========
var shop_inventory: Array[String] = []
var shop_regenerated: bool = false

func get_relic_price(rarity: String) -> int:
	match rarity:
		"white": return 50
		"green": return 100
		"blue": return 200
		"purple": return 400
		"red": return 800
		"gold": return 1500
		"legendary": return 3000
	return 99999

func regenerate_shop():
	shop_inventory.clear()
	var pool = []
	for id in RelicManager.all_relics.keys():
		if not RelicManager.has_relic(id):
			pool.append(id)

	# Pick 3 random relics
	pool.shuffle()
	for i in range(min(3, pool.size())):
		shop_inventory.append(pool[i])

	shop_regenerated = true
	print("Shop regenerated: ", shop_inventory.size(), " items")

func buy_relic_from_shop(index: int) -> bool:
	if index < 0 or index >= shop_inventory.size():
		return false
	var id = shop_inventory[index]
	var relic = RelicManager.get_relic(id)
	if relic == null:
		return false
	var price = get_relic_price(relic.rarity)
	if photo_prints < price:
		return false

	photo_prints -= price
	RelicManager.unlock(id)
	shop_inventory.remove_at(index)
	print("Bought relic: ", relic.display_name)
	return true

var run_kills: int = 0
var run_bosses: int = 0
var run_prints_earned: int = 0
var current_floor: int = 1
var current_room: int = 1

# Relics
var owned_relics: Array[String] = ["developer_gloves", "lens_cap", "old_tripod", "red_lamp", "fingerprint"]
var equipped_relics: Array[String] = ["developer_gloves", "lens_cap"]

func _ready():
	print("GameManager initialized")

func start_run():
	run_kills = 0
	run_bosses = 0
	run_prints_earned = 0
	current_floor = 1
	current_room = 1
	# Sync relics to RelicManager
	RelicManager.owned_relics = owned_relics.duplicate()
	RelicManager.equipped_relics = equipped_relics.duplicate()
	RelicManager.reset_run()
	# Relic: Lumiere Card (+1 camera level at start)
	var cam_bonus = RelicManager.get_camera_level_bonus()
	print("Camera level bonus: +", cam_bonus)
	print("Starting new run... Floor 1")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func end_run(success: bool):
	var earned = run_kills * 2 + run_bosses * 50
	if success:
		earned += 100
	photo_prints += earned
	run_prints_earned = earned
	if not success:
		total_deaths += 1
	current_floor = 1
	current_room = 1
	# Sync relics back
	owned_relics = RelicManager.owned_relics.duplicate()
	equipped_relics = RelicManager.equipped_relics.duplicate()
	print("Run ended. Success: ", success, " | Prints earned: ", earned)
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/hub.tscn")

func add_kill():
	run_kills += 1
	total_kills += 1

func add_boss_kill():
	run_bosses += 1

func can_afford(cost: int) -> bool:
	return photo_prints >= cost

func spend_prints(amount: int) -> bool:
	if photo_prints >= amount:
		photo_prints -= amount
		return true
	return false
