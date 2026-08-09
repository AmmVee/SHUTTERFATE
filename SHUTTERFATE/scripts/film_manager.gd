extends Node

var films: Dictionary = {}
var current_film: FilmData = null

func _ready():
	_register_films()

func _register_films():
	var obskura = FilmData.new()
	obskura.film_id = "obskura"
	obskura.display_name = "Обскура"
	obskura.description = "Классическая плёнка. Сбалансированные характеристики."
	obskura.max_frames = 36
	films["obskura"] = obskura

	var chroma = FilmData.new()
	chroma.film_id = "chroma"
	chroma.display_name = "Хрома"
	chroma.description = "+25% урон при полном фокусе. Насыщенные цвета."
	chroma.max_frames = 36
	chroma.focus_mult = 1.25
	chroma.base_damage_mult = 0.9
	films["chroma"] = chroma

	var noir = FilmData.new()
	noir.film_id = "noir"
	noir.display_name = "Нуар"
	noir.description = "Фокус накапливается быстрее, но ISO шумит сильнее."
	noir.max_frames = 36
	noir.focus_build_rate = 1.8
	noir.iso_mult = 0.7
	noir.focus_mult = 1.15
	films["noir"] = noir

	var infra = FilmData.new()
	infra.film_id = "infrared"
	infra.display_name = "Инфракраска"
	infra.description = "Видит сквозь тьму. Мало кадров, но высокий базовый урон."
	infra.max_frames = 24
	infra.base_damage_mult = 1.3
	infra.focus_mult = 0.8
	films["infrared"] = infra

	var polaroid = FilmData.new()
	polaroid.film_id = "polaroid"
	polaroid.display_name = "Полароид"
	polaroid.description = "Мгновенная фиксация. Нет фокуса, мало кадров."
	polaroid.max_frames = 10
	polaroid.base_damage_mult = 0.6
	polaroid.focus_mult = 0.0
	polaroid.focus_build_rate = 999.0
	polaroid.reload_time = 1.5
	films["polaroid"] = polaroid

	var xpro = FilmData.new()
	xpro.film_id = "xpro"
	xpro.display_name = "Кросс-процесс"
	xpro.description = "Непредсказуемая химия. Случайные всплески урона."
	xpro.max_frames = 36
	xpro.special_id = "random_roll"
	films["xpro"] = xpro

	var frame_zero = FilmData.new()
	frame_zero.film_id = "frame_zero"
	frame_zero.display_name = "Кадр Ноль"
	frame_zero.description = "Последний кадр наносит колоссальный урон. Долгая перезарядка."
	frame_zero.max_frames = 36
	frame_zero.special_id = "last_frame_burst"
	frame_zero.reload_time = 4.0
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

func apply_damage_modifiers(base_dmg: float, focus_ratio: float, exposure: float, iso_mod: float, aperture_mod: float, current_frame: int, _max_frame: int) -> float:
	if current_film == null:
		return base_dmg * (0.2 + focus_ratio * 2.8) * exposure * iso_mod * aperture_mod
	var dmg = base_dmg * current_film.base_damage_mult
	dmg *= (0.2 + focus_ratio * 2.8) * current_film.focus_mult
	dmg *= exposure * current_film.exposure_mult
	dmg *= iso_mod * current_film.iso_mult
	dmg *= aperture_mod * current_film.aperture_mult
	match current_film.special_id:
		"random_roll":
			dmg *= randf_range(0.5, 2.0)
		"last_frame_burst":
			if current_frame == 1:
				dmg *= 5.0
				print("FRAME ZERO BURST!")
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
