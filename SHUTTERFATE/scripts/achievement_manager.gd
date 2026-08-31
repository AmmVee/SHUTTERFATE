extends Node

var achievements: Dictionary = {}
var unlocked_achievements: Array[String] = []
var achievement_progress: Dictionary = {}

func _ready():
	_init_achievements()
	print("AchievementManager initialized with ", achievements.size(), " achievements")

func _init_achievements():
	achievements = {
		"first_shot": {
			"name": "Первый кадр",
			"desc": "Сделайте первый выстрел",
			"condition": "shots_fired >= 1",
			"reward": "frame_white"
		},
		"shutterbug": {
			"name": "Фотограф-любитель",
			"desc": "Сделайте 100 выстрелов",
			"condition": "shots_fired >= 100",
			"reward": "frame_green"
		},
		"paparazzi": {
			"name": "Папарацци",
			"desc": "Сделайте 1000 выстрелов",
			"condition": "shots_fired >= 1000",
			"reward": "frame_gold"
		},
		"first_blood": {
			"name": "Первая кровь",
			"desc": "Убейте первого врага",
			"condition": "kills >= 1",
			"reward": "frame_white"
		},
		"hunter": {
			"name": "Охотник",
			"desc": "Убейте 100 врагов",
			"condition": "kills >= 100",
			"reward": "frame_green"
		},
		"slaughter": {
			"name": "Резня",
			"desc": "Убейте 1000 врагов",
			"condition": "kills >= 1000",
			"reward": "frame_gold"
		},
		"first_boss": {
			"name": "Проявщик",
			"desc": "Победите первого босса",
			"condition": "bosses_killed >= 1",
			"reward": "frame_blue"
		},
		"boss_slayer": {
			"name": "Убийца боссов",
			"desc": "Победите 10 боссов",
			"condition": "bosses_killed >= 10",
			"reward": "frame_purple"
		},
		"depth_diver": {
			"name": "Глубинный ныряльщик",
			"desc": "Достигните этажа 5",
			"condition": "max_floor >= 5",
			"reward": "frame_blue"
		},
		"abyss_walker": {
			"name": "Странник бездны",
			"desc": "Достигните этажа 10",
			"condition": "max_floor >= 10",
			"reward": "frame_purple"
		},
		"obscura_master": {
			"name": "Мастер Обскуры",
			"desc": "Достигните этажа 15",
			"condition": "max_floor >= 15",
			"reward": "frame_gold"
		},
		"collector": {
			"name": "Коллекционер",
			"desc": "Соберите 10 реликвий",
			"condition": "relics_owned >= 10",
			"reward": "frame_blue"
		},
		"antiquarian": {
			"name": "Антиквар",
			"desc": "Соберите все 20 реликвий",
			"condition": "relics_owned >= 20",
			"reward": "frame_legendary"
		},
		"film_buff": {
			"name": "Киноман",
			"desc": "Разблокируйте все 7 плёнок",
			"condition": "films_unlocked >= 7",
			"reward": "frame_purple"
		},
		"perfectionist": {
			"name": "Перфекционист",
			"desc": "Пройдите этаж без получения урона",
			"condition": "no_damage_run == true",
			"reward": "frame_gold"
		},
		"rich": {
			"name": "Богач",
			"desc": "Накопите 1000 отпечатков",
			"condition": "prints >= 1000",
			"reward": "frame_green"
		},
		"tycoon": {
			"name": "Магнат",
			"desc": "Накопите 10000 отпечатков",
			"condition": "prints >= 10000",
			"reward": "frame_gold"
		},
		"upgrade_master": {
			"name": "Мастер апгрейдов",
			"desc": "Максимально прокачайте все апгрейды камеры",
			"condition": "all_upgrades_max == true",
			"reward": "frame_purple"
		},
		"pact_warrior": {
			"name": "Воин пактов",
			"desc": "Пройдите забег с 3 модификаторами",
			"condition": "max_pacts_run >= 3",
			"reward": "frame_red"
		},
		"elite_hunter": {
			"name": "Охотник на элиту",
			"desc": "Убейте 20 элитных врагов",
			"condition": "elite_kills >= 20",
			"reward": "frame_blue"
		},
		"ghost_buster": {
			"name": "Охотник за привидениями",
			"desc": "Убейте 10 призраков",
			"condition": "ghost_kills >= 10",
			"reward": "frame_green"
		},
		"camera_max": {
			"name": "Профессионал",
			"desc": "Достигните 10 уровня камеры",
			"condition": "camera_level >= 10",
			"reward": "frame_gold"
		},
		"suicide_mission": {
			"name": "Самоубийственная миссия",
			"desc": "Пройдите этаж 5 с модификатором \"Старый объектив\"",
			"condition": "old_lens_floor5 == true",
			"reward": "frame_legendary"
		},
		"shutter_fate": {
			"name": "Судьба затвора",
			"desc": "Пройдите все 15 этажей и победите Фотографа",
			"condition": "max_floor >= 15",
			"reward": "frame_gold"
		}
	}
	achievement_progress = {
		"shots_fired": 0,
		"kills": 0,
		"bosses_killed": 0,
		"max_floor": 0,
		"relics_owned": 0,
		"films_unlocked": 0,
		"no_damage_run": false,
		"prints": 0,
		"all_upgrades_max": false,
		"max_pacts_run": 0,
		"elite_kills": 0,
		"ghost_kills": 0,
		"camera_level": 0,
		"old_lens_floor5": false,
		"damage_taken_this_run": 0,
		"seasonal_challenges_completed": 0,
		"spring_kills_run": 0,
		"summer_iso3200": false,
		"autumn_prints_run": 0,
		"winter_floor5": false,
		"all_seasons_done": false,
		"season_relics_owned": 0,
		"seasons_completed": {"spring": false, "summer": false, "autumn": false, "winter": false}
	}

func check_all():
	for id in achievements.keys():
		if not id in unlocked_achievements:
			if _check_condition(achievements[id]["condition"]):
				unlock(id)

func _check_condition(condition: String) -> bool:
	match condition:
		"shots_fired >= 1": return achievement_progress["shots_fired"] >= 1
		"shots_fired >= 100": return achievement_progress["shots_fired"] >= 100
		"shots_fired >= 1000": return achievement_progress["shots_fired"] >= 1000
		"kills >= 1": return achievement_progress["kills"] >= 1
		"kills >= 100": return achievement_progress["kills"] >= 100
		"kills >= 1000": return achievement_progress["kills"] >= 1000
		"bosses_killed >= 1": return achievement_progress["bosses_killed"] >= 1
		"bosses_killed >= 10": return achievement_progress["bosses_killed"] >= 10
		"max_floor >= 5": return achievement_progress["max_floor"] >= 5
		"max_floor >= 10": return achievement_progress["max_floor"] >= 10
		"max_floor >= 15": return achievement_progress["max_floor"] >= 15
		"relics_owned >= 10": return achievement_progress["relics_owned"] >= 10
		"relics_owned >= 20": return achievement_progress["relics_owned"] >= 20
		"films_unlocked >= 7": return achievement_progress["films_unlocked"] >= 7
		"no_damage_run == true": return achievement_progress["no_damage_run"]
		"prints >= 1000": return achievement_progress["prints"] >= 1000
		"prints >= 10000": return achievement_progress["prints"] >= 10000
		"all_upgrades_max == true": return achievement_progress["all_upgrades_max"]
		"max_pacts_run >= 3": return achievement_progress["max_pacts_run"] >= 3
		"elite_kills >= 20": return achievement_progress["elite_kills"] >= 20
		"ghost_kills >= 10": return achievement_progress["ghost_kills"] >= 10
		"camera_level >= 10": return achievement_progress["camera_level"] >= 10
		"old_lens_floor5 == true": return achievement_progress["old_lens_floor5"]
		"seasonal_challenges_completed >= 1": return achievement_progress["seasonal_challenges_completed"] >= 1
		"spring_kills_run >= 50": return achievement_progress["spring_kills_run"] >= 50
		"summer_iso3200 == true": return achievement_progress["summer_iso3200"]
		"autumn_prints_run >= 500": return achievement_progress["autumn_prints_run"] >= 500
		"winter_floor5 == true": return achievement_progress["winter_floor5"]
		"all_seasons_done == true": return achievement_progress["all_seasons_done"]
		"season_relics_owned >= 8": return achievement_progress["season_relics_owned"] >= 8
	return false

func unlock(id: String):
	if id in unlocked_achievements:
		return
	unlocked_achievements.append(id)
	var ach = achievements[id]
	print("ACHIEVEMENT UNLOCKED: ", ach["name"])
	_show_popup(ach["name"], ach["desc"], ach["reward"])

func _show_popup(name: String, desc: String, reward: String):
	var popup = CanvasLayer.new()
	popup.layer = 100
	var panel = ColorRect.new()
	panel.color = Color(0.05, 0.05, 0.08, 0.95)
	panel.size = Vector2(500, 120)
	panel.position = Vector2(710, 50)
	popup.add_child(panel)
	var title = Label.new()
	title.text = "ДОСТИЖЕНИЕ РАЗБЛОКИРОВАНО"
	title.position = Vector2(0, 10)
	title.size = Vector2(500, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3, 1))
	panel.add_child(title)
	var ach_name = Label.new()
	ach_name.text = name
	ach_name.position = Vector2(0, 40)
	ach_name.size = Vector2(500, 30)
	ach_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ach_name.add_theme_font_size_override("font_size", 20)
	ach_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1))
	ach_name.add_theme_constant_override("outline_size", 3)
	panel.add_child(ach_name)
	var ach_desc = Label.new()
	ach_desc.text = desc
	ach_desc.position = Vector2(0, 75)
	ach_desc.size = Vector2(500, 20)
	ach_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ach_desc.add_theme_font_size_override("font_size", 12)
	ach_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	panel.add_child(ach_desc)
	# FIX: use get_tree().root instead of current_scene to avoid null during scene change
	var root = get_tree().root
	if root:
		root.add_child(popup)
	else:
		print("WARNING: Cannot show achievement popup — no root available")
		return
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.5).set_delay(3.0)
	tween.chain().tween_callback(func():
		if is_instance_valid(popup):
			popup.queue_free()
	)

func add_shot():
	achievement_progress["shots_fired"] += 1
	check_all()

func add_kill(enemy_type: String = "", is_elite: bool = false):
	achievement_progress["kills"] += 1
	if is_elite:
		achievement_progress["elite_kills"] += 1
	if enemy_type == "ghost":
		achievement_progress["ghost_kills"] += 1
	check_all()

func add_boss_kill():
	achievement_progress["bosses_killed"] += 1
	check_all()

func set_max_floor(floor_num: int):
	if floor_num > achievement_progress["max_floor"]:
		achievement_progress["max_floor"] = floor_num
	check_all()

func set_relics_owned(count: int):
	achievement_progress["relics_owned"] = count
	check_all()

func set_films_unlocked(count: int):
	achievement_progress["films_unlocked"] = count
	check_all()

func set_prints(count: int):
	achievement_progress["prints"] = count
	check_all()

func set_camera_level(level: int):
	achievement_progress["camera_level"] = level
	check_all()

func set_all_upgrades_max(val: bool):
	achievement_progress["all_upgrades_max"] = val
	check_all()

func set_max_pacts_run(count: int):
	if count > achievement_progress["max_pacts_run"]:
		achievement_progress["max_pacts_run"] = count
	check_all()

func set_no_damage_run(val: bool):
	achievement_progress["no_damage_run"] = val
	check_all()

func add_damage_taken(amount: int):
	achievement_progress["damage_taken_this_run"] += amount
	achievement_progress["no_damage_run"] = false

func reset_run_damage():
	achievement_progress["damage_taken_this_run"] = 0
	# FIX: Don't preset no_damage_run = true — it will be evaluated at floor end

func check_no_damage_run():
	if achievement_progress["damage_taken_this_run"] == 0:
		achievement_progress["no_damage_run"] = true
		unlock("perfectionist")

func check_old_lens_floor5(floor_num: int):
	if floor_num >= 5 and GameManager.has_pact("old_lens"):
		achievement_progress["old_lens_floor5"] = true
		check_all()

func add_seasonal_challenge_complete():
	achievement_progress["seasonal_challenges_completed"] += 1
	check_all()

func add_spring_kill():
	if SeasonManager.get_season_id() == "spring":
		achievement_progress["spring_kills_run"] += 1
		check_all()

func set_summer_iso3200(val: bool):
	if val and SeasonManager.get_season_id() == "summer":
		achievement_progress["summer_iso3200"] = true
		check_all()

func add_autumn_prints(amount: int):
	if SeasonManager.get_season_id() == "autumn":
		achievement_progress["autumn_prints_run"] += amount
		check_all()

func set_winter_floor5(floor_num: int):
	if floor_num >= 5 and SeasonManager.get_season_id() == "winter":
		achievement_progress["winter_floor5"] = true
		check_all()

func mark_season_completed(season_id: String):
	var seasons = achievement_progress.get("seasons_completed", {})
	if season_id in seasons:
		seasons[season_id] = true
	var all_done = true
	for s in ["spring", "summer", "autumn", "winter"]:
		if not seasons.get(s, false):
			all_done = false
			break
	achievement_progress["all_seasons_done"] = all_done
	check_all()

func set_season_relics_owned(count: int):
	achievement_progress["season_relics_owned"] = count
	check_all()

func reset_season_run_stats():
	achievement_progress["spring_kills_run"] = 0
	achievement_progress["autumn_prints_run"] = 0
	achievement_progress["summer_iso3200"] = false
