extends Node

# ========== SEASONAL EVENTS SYSTEM (Stage 8) ==========
# Seasons change every 3 months based on real date
# Each season brings: theme, modifiers, exclusive relics & films, special challenges

var current_season: Dictionary = {}
var season_index: int = 0

const SEASONS = [
	{
		"id": "spring",
		"name": "Пробуждение Обскуры",
		"months": [3, 4, 5],
		"desc": "Весна пробуждает древние плёнки. Фокус растёт быстрее.",
		"modifier": {
			"focus_build_rate": 1.15,
			"enemy_hp_mult": 1.0,
			"prints_bonus": 0.0
		},
		"relics": ["obscura_seed", "beeswax"],
		"film": "bloom_200",
		"challenge": {
			"id": "spring_bloom",
			"name": "Цветочный забег",
			"desc": "Убейте 20 врагов за 90 секунд",
			"target_kills": 20,
			"time_limit": 90,
			"bonus_prints": 250
		},
		"color": Color(0.2, 0.85, 0.35, 1),
		"particle_color": Color(0.4, 0.9, 0.5, 0.6)
	},
	{
		"id": "summer",
		"name": "Пересвет",
		"months": [6, 7, 8],
		"desc": "Солнечные лучи ослабляют врагов, но ослепляют неосторожных.",
		"modifier": {
			"focus_build_rate": 1.0,
			"enemy_hp_mult": 0.9,
			"prints_bonus": 0.0
		},
		"relics": ["solar_battery", "polarizing_filter"],
		"film": "overexposure_100",
		"challenge": {
			"id": "summer_iso",
			"name": "Пересвет",
			"desc": "Пройдите этаж с ISO 3200",
			"require_iso": 3200,
			"bonus_prints": 200
		},
		"color": Color(0.95, 0.75, 0.15, 1),
		"particle_color": Color(1.0, 0.9, 0.3, 0.6)
	},
	{
		"id": "autumn",
		"name": "Золотой час",
		"months": [9, 10, 11],
		"desc": "Осень щедра на отпечатки. Каждый кадр — золото.",
		"modifier": {
			"focus_build_rate": 1.0,
			"enemy_hp_mult": 1.0,
			"prints_bonus": 0.15
		},
		"relics": ["golden_frame", "warm_filter"],
		"film": "golden_hour_400",
		"challenge": {
			"id": "autumn_harvest",
			"name": "Золотая жатва",
			"desc": "Соберите 200 отпечатков за один забег",
			"target_prints": 200,
			"bonus_prints": 300
		},
		"color": Color(0.9, 0.5, 0.1, 1),
		"particle_color": Color(0.95, 0.6, 0.2, 0.6)
	},
	{
		"id": "winter",
		"name": "Морозная проявка",
		"months": [12, 1, 2],
		"desc": "Холод замедляет всех. Выдержка решает всё.",
		"modifier": {
			"focus_build_rate": 1.0,
			"enemy_hp_mult": 1.0,
			"prints_bonus": 0.0,
			"enemy_speed_mult": 0.85
		},
		"relics": ["frosted_glass", "thermal_pack"],
		"film": "frost_32",
		"challenge": {
			"id": "winter_shutter",
			"name": "Морозная выдержка",
			"desc": "Пройдите этаж с выдержкой 1/30",
			"require_shutter": 30.0,
			"bonus_prints": 250
		},
		"color": Color(0.3, 0.7, 0.95, 1),
		"particle_color": Color(0.5, 0.8, 1.0, 0.6)
	}
]

# Season-exclusive relics data
const SEASON_RELICS = {
	# === SPRING ===
	"obscura_seed": {
		"name": "Семя Обскуры",
		"desc": "20% шанс восстановить 1 кадр при убийстве",
		"flavor": "\"Из маленького семени вырастает целая галерея.\"",
		"effect": "seed_regen",
		"rarity": "green",
		"color": Color(0.18, 0.8, 0.25),
		"season": "spring"
	},
	"beeswax": {
		"name": "Пчелиный воск",
		"desc": "+15% урона по врагам с полным HP",
		"flavor": "\"Сладкий аромат перед укусом.\"",
		"effect": "full_hp_bonus",
		"rarity": "blue",
		"color": Color(0.0, 0.45, 0.85),
		"season": "spring"
	},
	# === SUMMER ===
	"solar_battery": {
		"name": "Солнечная батарея",
		"desc": "ISO 3200 без штрафа шума",
		"flavor": "\"Заряжается от света. Разряжается во тьме.\"",
		"effect": "iso_no_noise",
		"rarity": "green",
		"color": Color(0.18, 0.8, 0.25),
		"season": "summer"
	},
	"polarizing_filter": {
		"name": "Поляризационный фильтр",
		"desc": "Иммунитет к ослеплению",
		"flavor": "\"Свет проходит, блики остаются позади.\"",
		"effect": "blind_immunity",
		"rarity": "blue",
		"color": Color(0.0, 0.45, 0.85),
		"season": "summer"
	},
	# === AUTUMN ===
	"golden_frame": {
		"name": "Золотая рамка",
		"desc": "+20% отпечатков за забег",
		"flavor": "\"Каждый кадр в ней — произведение искусства.\"",
		"effect": "prints_plus_20",
		"rarity": "purple",
		"color": Color(0.69, 0.05, 0.79),
		"season": "autumn"
	},
	"warm_filter": {
		"name": "Тёплый фильтр",
		"desc": "+12% шанс крита",
		"flavor": "\"Осень окрашивает всё в золото.\"",
		"effect": "crit_plus_12",
		"rarity": "blue",
		"color": Color(0.0, 0.45, 0.85),
		"season": "autumn"
	},
	# === WINTER ===
	"frosted_glass": {
		"name": "Морозное стекло",
		"desc": "Враги в прицеле замедляются на 20%",
		"flavor": "\"Холод проникает сквозь линзу.\"",
		"effect": "aim_slow_enemy",
		"rarity": "purple",
		"color": Color(0.69, 0.05, 0.79),
		"season": "winter"
	},
	"thermal_pack": {
		"name": "Термопакет",
		"desc": "+20 макс HP",
		"flavor": "\"Согревает даже в самый лютый мороз.\"",
		"effect": "hp_plus_20",
		"rarity": "green",
		"color": Color(0.18, 0.8, 0.25),
		"season": "winter"
	}
}

# Season-exclusive films data
const SEASON_FILMS = {
	"bloom_200": {
		"name": "Цветение-200",
		"desc": "28 кадров. +15% урон по врагам с полным HP.",
		"max_frames": 28,
		"rarity": "green",
		"rarity_color": Color(0.18, 0.8, 0.25, 1),
		"special_id": "bloom_full_hp",
		"base_damage_mult": 1.0,
		"season": "spring"
	},
	"overexposure_100": {
		"name": "Пересвет-100",
		"desc": "20 кадров. Каждый 5-й выстрел — двойной урон.",
		"max_frames": 20,
		"rarity": "yellow",
		"rarity_color": Color(0.95, 0.85, 0.1, 1),
		"special_id": "every_5th_double",
		"base_damage_mult": 1.0,
		"season": "summer"
	},
	"golden_hour_400": {
		"name": "Золотой час-400",
		"desc": "24 кадра. +25% отпечатков за убийство.",
		"max_frames": 24,
		"rarity": "orange",
		"rarity_color": Color(0.95, 0.5, 0.1, 1),
		"special_id": "prints_bonus_25",
		"base_damage_mult": 1.0,
		"season": "autumn"
	},
	"frost_32": {
		"name": "Мороз-32",
		"desc": "16 кадров. Крит замораживает врага на 1 сек.",
		"max_frames": 16,
		"rarity": "cyan",
		"rarity_color": Color(0.2, 0.8, 0.95, 1),
		"special_id": "crit_freeze",
		"base_damage_mult": 1.0,
		"season": "winter"
	}
}

# Unlocked season content (persisted)
var unlocked_season_relics: Array[String] = []
var unlocked_season_films: Array[String] = []

func _ready():
	_update_season()
	print("SeasonManager: current season = ", current_season.get("name", "None"))

func _update_season():
	var today = Time.get_date_dict_from_system()
	var month = today.month
	for i in range(SEASONS.size()):
		if month in SEASONS[i].months:
			season_index = i
			current_season = SEASONS[i].duplicate(true)
			break

func get_season_name() -> String:
	return current_season.get("name", "Нет сезона")

func get_season_id() -> String:
	return current_season.get("id", "")

func get_season_color() -> Color:
	return current_season.get("color", Color.WHITE)

func get_season_modifier(key: String) -> float:
	var mods = current_season.get("modifier", {})
	return mods.get(key, 1.0)

func get_season_prints_bonus() -> float:
	return current_season.get("modifier", {}).get("prints_bonus", 0.0)

func get_season_challenge() -> Dictionary:
	return current_season.get("challenge", {})

func is_season_relic(id: String) -> bool:
	return id in SEASON_RELICS

func is_season_film(id: String) -> bool:
	return id in SEASON_FILMS

func get_season_relic(id: String) -> Dictionary:
	return SEASON_RELICS.get(id, {})

func get_season_film(id: String) -> Dictionary:
	return SEASON_FILMS.get(id, {})

func get_current_season_relics() -> Array[String]:
	return current_season.get("relics", [])

func get_current_season_film() -> String:
	return current_season.get("film", "")

func unlock_season_relic(id: String):
	if id not in unlocked_season_relics and is_season_relic(id):
		unlocked_season_relics.append(id)
		print("Season relic unlocked: ", id)

func unlock_season_film(id: String):
	if id not in unlocked_season_films and is_season_film(id):
		unlocked_season_films.append(id)
		print("Season film unlocked: ", id)

func has_season_relic(id: String) -> bool:
	return id in unlocked_season_relics

func has_season_film(id: String) -> bool:
	return id in unlocked_season_films

# Check if a relic/film is available in current season
func is_available_this_season(id: String) -> bool:
	if is_season_relic(id):
		var relic = SEASON_RELICS[id]
		return relic.get("season", "") == get_season_id()
	if is_season_film(id):
		var film = SEASON_FILMS[id]
		return film.get("season", "") == get_season_id()
	return true

# Get all available season relics for current season (for shop/treasure)
func get_available_season_relics() -> Array[String]:
	var result: Array[String] = []
	for id in SEASON_RELICS.keys():
		if SEASON_RELICS[id].get("season", "") == get_season_id():
			result.append(id)
	return result

# Get current season film data (for FilmManager integration)
func get_current_season_film_data() -> Dictionary:
	var film_id = get_current_season_film()
	if film_id.is_empty():
		return {}
	return SEASON_FILMS.get(film_id, {})
