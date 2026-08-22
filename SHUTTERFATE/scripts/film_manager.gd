extends Node

var films: Dictionary = {}
var current_film: FilmData = null

func _ready():
	_register_films()

func _register_films():
	# === ОБСКУРА-100 | Белая | Стандартная ===
	var obskura = FilmData.new()
	obskura.film_id = "obskura"
	obskura.display_name = "Обскура-100"
	obskura.description = "Классическая плёнка. 36 кадров. Сбалансированные характеристики."
	obskura.max_frames = 36
	obskura.rarity = "white"
	obskura.rarity_color = Color(0.95, 0.95, 0.95, 1)
	obskura.exposure_mult = 1.0
	obskura.iso_mult = 1.0
	obskura.aperture_mult = 1.0
	films["obskura"] = obskura

	# === ХРОМА-400 | Зелёная | +25% урон по Нечётким ===
	var chroma = FilmData.new()
	chroma.film_id = "chroma"
	chroma.display_name = "Хрома-400"
	chroma.description = "24 кадра. +25% урона по Нечётким в движении."
	chroma.max_frames = 24
	chroma.base_damage_mult = 1.0
	chroma.rarity = "green"
	chroma.rarity_color = Color(0.18, 0.8, 0.25, 1)
	chroma.special_id = "smear_bonus"
	chroma.aim_shape = "cone"
	chroma.aim_radius = 160.0
	chroma.exposure_mult = 1.0
	chroma.iso_mult = 1.0
	chroma.aperture_mult = 1.0
	films["chroma"] = chroma

	# === НУАР-32 | Синяя | Ч/Б. Игнор 50% защиты. Крит ×4 ===
	var noir = FilmData.new()
	noir.film_id = "noir"
	noir.display_name = "Нуар-32"
	noir.description = "12 кадров. Ч/Б. Игнорирует 50% защиты. Крит ×4 при полном фокусе."
	noir.max_frames = 12
	noir.base_damage_mult = 1.1
	noir.focus_mult = 1.0
	noir.focus_build_rate = 1.4
	noir.rarity = "blue"
	noir.rarity_color = Color(0.0, 0.45, 0.85, 1)
	noir.special_id = "noir_crit"
	noir.aim_shape = "sniper"
	noir.aim_radius = 200.0
	noir.exposure_mult = 1.0
	noir.iso_mult = 1.0
	noir.aperture_mult = 1.0
	films["noir"] = noir

	# === ИНФРАКРАСКА | Фиолетовая | Видит скрытых. Урон через стены ===
	var infra = FilmData.new()
	infra.film_id = "infrared"
	infra.display_name = "Инфракраска"
	infra.description = "18 кадров. Видит скрытых врагов. Урон через стены."
	infra.max_frames = 18
	infra.base_damage_mult = 0.9
	infra.focus_mult = 0.9
	infra.rarity = "purple"
	infra.rarity_color = Color(0.69, 0.05, 0.79, 1)
	infra.special_id = "infrared_vision"
	infra.aim_shape = "sector"
	infra.aim_radius = 180.0
	infra.exposure_mult = 1.0
	infra.iso_mult = 1.0
	infra.aperture_mult = 1.0
	films["infrared"] = infra

	# === ПОЛАРОИД | Жёлтая | Хилл 15 HP за убийство ===
	var polaroid = FilmData.new()
	polaroid.film_id = "polaroid"
	polaroid.display_name = "Полароид"
	polaroid.description = "10 кадров. Мгновенная печать: убитый враг даёт 15 HP."
	polaroid.max_frames = 10
	polaroid.base_damage_mult = 0.75
	polaroid.focus_mult = 0.85
	polaroid.focus_build_rate = 1.2
	polaroid.reload_time = 1.8
	polaroid.rarity = "yellow"
	polaroid.rarity_color = Color(1.0, 0.86, 0.0, 1)
	polaroid.special_id = "polaroid_heal"
	polaroid.aim_shape = "aoe"
	polaroid.aim_radius = 100.0
	polaroid.exposure_mult = 1.0
	polaroid.iso_mult = 1.0
	polaroid.aperture_mult = 1.0
	films["polaroid"] = polaroid

	# === КРОСС-ПРОЦЕСС | Красная | Случайный мод 0.5-3.0 ===
	var xpro = FilmData.new()
	xpro.film_id = "xpro"
	xpro.display_name = "Кросс-процесс"
	xpro.description = "20 кадров. Случайный цветовой сдвиг: модификатор 0.5–3.0 за кадр."
	xpro.max_frames = 20
	xpro.rarity = "red"
	xpro.rarity_color = Color(1.0, 0.25, 0.2, 1)
	xpro.special_id = "random_roll"
	xpro.aim_shape = "beam"
	xpro.aim_radius = 120.0
	xpro.aim_width = 220.0
	xpro.aim_height = 60.0
	xpro.exposure_mult = 1.0
	xpro.iso_mult = 1.0
	xpro.aperture_mult = 1.0
	films["xpro"] = xpro

	# === КАДР НОЛЬ | Золотая | Урон = HP босса × 0.75 ===
	var frame_zero = FilmData.new()
	frame_zero.film_id = "frame_zero"
	frame_zero.display_name = "Кадр Ноль"
	frame_zero.description = "3 кадра. Финальная плёнка. Урон = HP босса × 0.75."
	frame_zero.max_frames = 3
	frame_zero.base_damage_mult = 0.5
	frame_zero.focus_mult = 0.0
	frame_zero.focus_build_rate = 999.0
	frame_zero.reload_time = 4.0
	frame_zero.rarity = "gold"
	frame_zero.rarity_color = Color(1.0, 0.84, 0.0, 1)
	frame_zero.special_id = "frame_zero_boss"
	frame_zero.aim_shape = "sniper"
	frame_zero.aim_radius = 250.0
	frame_zero.exposure_mult = 1.0
	frame_zero.iso_mult = 1.0
	frame_zero.aperture_mult = 1.0
	films["frame_zero"] = frame_zero

	current_film = films["obskura"]

func set_film(film_id: String):
	if films.has(film_id) and film_id in GameManager.unlocked_films:
		current_film = films[film_id]
		print("Film changed to: ", current_film.display_name)
	else:
		print("Film locked or not found: ", film_id)

func get_film(id: String) -> FilmData:
	return films.get(id, null)

func apply_damage_modifiers(base_dmg: float, focus_ratio: float, exposure: float, iso_mod: float, aperture_mod: float, _current_frame: int, _max_frame: int) -> float:
	if current_film == null:
		return base_dmg * (0.3 + focus_ratio * 2.2) * exposure * iso_mod * aperture_mod
	var dmg = base_dmg * current_film.base_damage_mult
	dmg *= (0.3 + focus_ratio * 2.2) * current_film.focus_mult
	dmg *= exposure * current_film.exposure_mult
	dmg *= iso_mod * current_film.iso_mult
	dmg *= aperture_mod * current_film.aperture_mult
	match current_film.special_id:
		"random_roll":
			dmg *= randf_range(0.7, 2.0)
	return max(dmg, 1.0)

# NEW: Calculate damage for a specific enemy (for film-specific effects)
func calculate_damage_for_enemy(base_dmg: float, focus_ratio: float, exposure: float, iso_mod: float, aperture_mod: float, current_frame: int, enemy) -> float:
	var dmg = apply_damage_modifiers(base_dmg, focus_ratio, exposure, iso_mod, aperture_mod, current_frame, 0)
	if current_film == null:
		return dmg

	match current_film.special_id:
		"smear_bonus":
			if enemy and enemy.get("is_smear") == true:
				dmg *= 1.25
		"noir_crit":
			# Игнорируем 50% защиты = урон × 2 относительно защищённого
			if enemy and enemy.get("defense") > 0:
				dmg *= (1.0 + enemy.defense * 0.5)
			# Крит ×4 при полном фокусе
			if focus_ratio >= 0.99:
				dmg *= 3.0
				print("NOIR CRIT! ×3")
		"frame_zero_boss":
			if enemy and enemy.get("is_boss") == true:
				var boss_hp = enemy.hp if "hp" in enemy else 100
				dmg = boss_hp * 0.75
				print("FRAME ZERO! Boss damage: ", dmg)
		"infrared_vision":
			# Урон через стены уже работает через Area2D
			# Бонус против скрытых врагов
			if enemy and enemy.get("is_hidden") == true:
				dmg *= 1.5
	return max(dmg, 1.0)

func get_max_frames() -> int:
	if current_film:
		return current_film.max_frames
	return 36

func get_reload_time() -> float:
	if current_film:
		return current_film.reload_time
	return 2.5

func get_focus_build_rate() -> float:
	if current_film:
		return current_film.focus_build_rate
	return 1.0

func should_heal_on_kill() -> bool:
	return current_film != null and current_film.special_id == "polaroid_heal"

func get_heal_amount() -> int:
	return 10


func _register_seasonal_films():
	for film_id in SeasonManager.SEASON_FILMS.keys():
		var data = SeasonManager.SEASON_FILMS[film_id]
		var film = FilmData.new()
		film.film_id = film_id
		film.display_name = data["name"]
		film.description = data["desc"]
		film.max_frames = data["max_frames"]
		film.rarity = data["rarity"]
		film.rarity_color = data["rarity_color"]
		film.special_id = data.get("special_id", "")
		film.base_damage_mult = data.get("base_damage_mult", 1.0)
		films[film_id] = film

func is_seasonal_film_unlocked(film_id: String) -> bool:
	return SeasonManager.has_season_film(film_id)

func unlock_seasonal_film(film_id: String):
	SeasonManager.unlock_season_film(film_id)

func get_aim_params() -> Dictionary:
	if current_film == null:
		return {"shape": "circle", "radius": 120.0, "width": 240.0, "height": 240.0}
	return {
		"shape": current_film.aim_shape,
		"radius": current_film.aim_radius,
		"width": current_film.aim_width,
		"height": current_film.aim_height
	}
