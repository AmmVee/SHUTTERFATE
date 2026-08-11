extends Node

var all_relics: Dictionary = {}
var owned_relics: Array[String] = []
var equipped_relics: Array[String] = []
const MAX_EQUIPPED = 3

# Runtime counters
var reload_counter: int = 0
var shot_counter: int = 0
var death_cheat_used: bool = false
var mirror_shard_used: bool = false
var erase_cooldown: float = 0.0
var first_hit_taken: bool = false

func _ready():
	_register_relics()

func _register_relics():
	# === Белые ===
	_register("developer_gloves", "Перчатки Проявщика",
		"Скорость перезарядки -25%",
		"\"Его руки всё ещё пахнут ацетоном.\"",
		"reload_speed_25", "white", Color(0.95, 0.95, 0.95))

	_register("lens_cap", "Крышка объектива",
		"+15 HP",
		"\"Защищает стекло. Иногда — жизнь.\"",
		"hp_plus_15", "white", Color(0.95, 0.95, 0.95))

	# === Зелёные ===
	_register("old_tripod", "Старый штатив",
		"Прицел не замедляет движение",
		"\"Тяжёлый, неуклюжий, незаменимый.\"",
		"no_aim_slow", "green", Color(0.18, 0.8, 0.25))

	_register("photo_journal", "Фотожурнал",
		"+2 кадра в каждой кассете",
		"\"Последний выпуск. Обложка — пустая.\"",
		"plus_2_frames", "green", Color(0.18, 0.8, 0.25))

	_register("red_lamp", "Красная лампа",
		"Враги замечают на 30% позже",
		"\"Безопасный свет. Нечёткие его не видят.\"",
		"enemy_detect_delay", "green", Color(0.18, 0.8, 0.25))

	# === Синие ===
	_register("fingerprint", "Отпечаток пальца",
		"+20% к шансу крита при полном фокусе",
		"\"Чужой. На обратной стороне — адрес.\"",
		"crit_focus", "blue", Color(0.0, 0.45, 0.85))

	_register("broken_uv", "Разбитый фильтр UV",
		"Первый удар в забеге = 0 урона",
		"\"Треснул, но защитил линзу.\"",
		"first_hit_null", "blue", Color(0.0, 0.45, 0.85))

	_register("remote_trigger", "Дистанционный спуск",
		"+50% дальности фокусного расстояния",
		"\"Щёлкни, не подходя близко.\"",
		"aim_range_50", "blue", Color(0.0, 0.45, 0.85))

	# === Фиолетовые ===
	_register("mother_negative", "Негатив матери",
		"Убитые враги оставляют призрачную копию на 3 сек",
		"\"Она улыбается. Но на негативе — нет.\"",
		"ghost_copy", "purple", Color(0.69, 0.05, 0.79))

	_register("empty_cassette", "Кассета без плёнки",
		"Каждая 5-я перезарядка бесплатная и мгновенная",
		"\"Щёлчок. Тишина. Щёлчок. Тишина.\"",
		"free_reload_5", "purple", Color(0.69, 0.05, 0.79))

	_register("pocket_reflector", "Карманный отражатель",
		"ISO даёт +урон, но без штрафа шума",
		"\"Золотой круг в тёмной комнате.\"",
		"iso_no_noise", "purple", Color(0.69, 0.05, 0.79))

	# === Красные ===
	_register("lumiere_card", "Визитка «Люмьер»",
		"+1 уровень камеры на старте",
		"\"Мы фиксируем моменты. Мы фиксируем всё.\"",
		"camera_level_1", "red", Color(1.0, 0.25, 0.2))

	_register("mirror_shard", "Осколок зеркала",
		"При смерти: автоматический кадр (урон ×5). Реликвия ломается.",
		"\"7 лет неудачи. Или одна идеальная съёмка.\"",
		"death_shot", "red", Color(1.0, 0.25, 0.2))

	_register("wet_print", "Мокрый отпечаток",
		"Каждый 15-й кадр наносит урон всем врагам в комнате",
		"\"Ещё не высох. Ещё не жив.\"",
		"aoe_15th", "red", Color(1.0, 0.25, 0.2))

	# === Золотые ===
	_register("eyeglass", "Глазное стекло",
		"В прицеле время замедляется на 10%",
		"\"Он смотрел слишком долго в видоискатель.\"",
		"slow_time_10", "gold", Color(1.0, 0.84, 0.0))

	_register("film_from_future", "Плёнка с будущего",
		"Один раз за забег: смертельный урон оставляет 1 HP",
		"\"На ней — ты. Ты падаешь. Но не сегодня.\"",
		"death_cheat", "gold", Color(1.0, 0.84, 0.0))

	_register("retouch_ink", "Тушь для ретуши",
		"Можешь \"стереть\" одного обычного врага раз в 30 сек",
		"\"Сотри то, что не должно существовать.\"",
		"erase_enemy", "gold", Color(1.0, 0.84, 0.0))

	_register("double_exposure", "Двойная экспозиция",
		"Каждый кадр наносит урон дважды (второй ×0.5)",
		"\"Два кадра. Одна реальность.\"",
		"double_shot", "gold", Color(1.0, 0.84, 0.0))

	# === Легендарные ===
	_register("camera_obscura", "Камера-обскура",
		"Видоискатель показывает всех врагов на уровне",
		"\"Первый принцип. Последнее средство.\"",
		"see_all", "legendary", Color(1.0, 0.5, 0.0))

	_register("frame_zero_relic", "Кадр Ноль",
		"Финальный босс: его HP не может восстанавливаться",
		"\"Исходный снимок. Тот, с которого всё началось.\"",
		"boss_no_heal", "legendary", Color(1.0, 0.5, 0.0))

func _register(id: String, display_name: String, desc: String, vignette: String, effect: String, rarity: String, color: Color):
	var r = RelicData.new()
	r.relic_id = id
	r.display_name = display_name
	r.description = desc
	r.vignette = vignette
	r.effect_id = effect
	r.rarity = rarity
	r.rarity_color = color
	all_relics[id] = r

func get_relic(id: String) -> RelicData:
	return all_relics.get(id, null)

func has_relic(id: String) -> bool:
	return id in owned_relics

func is_equipped(id: String) -> bool:
	return id in equipped_relics

func equip(id: String) -> bool:
	if not has_relic(id):
		return false
	if id in equipped_relics:
		return true
	if equipped_relics.size() >= MAX_EQUIPPED:
		print("Max relics equipped (", MAX_EQUIPPED, ")")
		return false
	equipped_relics.append(id)
	print("Equipped: ", all_relics[id].display_name)
	return true

func unequip(id: String) -> bool:
	if id in equipped_relics:
		equipped_relics.erase(id)
		print("Unequipped: ", all_relics[id].display_name)
		return true
	return false

func unlock(id: String) -> bool:
	if not all_relics.has(id):
		return false
	if id in owned_relics:
		return false
	owned_relics.append(id)
	print("Relic unlocked: ", all_relics[id].display_name)
	return true

# ========== EFFECT CHECKERS ==========

func has_effect(effect: String) -> bool:
	for id in equipped_relics:
		var r = all_relics.get(id)
		if r and r.effect_id == effect:
			return true
	return false

func get_reload_multiplier() -> float:
	if has_effect("reload_speed_25"):
		return 0.75
	return 1.0

func get_max_hp_bonus() -> int:
	if has_effect("hp_plus_15"):
		return 15
	return 0

func has_no_aim_slow() -> bool:
	return has_effect("no_aim_slow")

func get_extra_frames() -> int:
	if has_effect("plus_2_frames"):
		return 2
	return 0

func get_enemy_detect_multiplier() -> float:
	if has_effect("enemy_detect_delay"):
		return 1.3
	return 1.0

func get_crit_bonus() -> float:
	if has_effect("crit_focus"):
		return 0.2
	return 0.0

func has_first_hit_null() -> bool:
	return has_effect("first_hit_null")

func get_aim_range_multiplier() -> float:
	if has_effect("aim_range_50"):
		return 1.5
	return 1.0

func has_ghost_copy() -> bool:
	return has_effect("ghost_copy")

func get_free_reload_counter() -> int:
	if has_effect("free_reload_5"):
		return 5
	return 0

func has_iso_no_noise() -> bool:
	return has_effect("iso_no_noise")

func get_camera_level_bonus() -> int:
	if has_effect("camera_level_1"):
		return 1
	return 0

func has_death_shot() -> bool:
	return has_effect("death_shot")

func get_aoe_interval() -> int:
	if has_effect("aoe_15th"):
		return 10
	return 0

func get_time_scale() -> float:
	if has_effect("slow_time_10"):
		return 0.9
	return 1.0

func has_death_cheat() -> bool:
	return has_effect("death_cheat")

func has_erase() -> bool:
	return has_effect("erase_enemy")

func has_double_shot() -> bool:
	return has_effect("double_shot")

func has_see_all() -> bool:
	return has_effect("see_all")

func has_boss_no_heal() -> bool:
	return has_effect("boss_no_heal")

# ========== RUNTIME COUNTERS ==========

func on_reload():
	reload_counter += 1

func on_shot():
	shot_counter += 1

func is_free_reload() -> bool:
	var interval = get_free_reload_counter()
	if interval > 0 and reload_counter > 0 and reload_counter % interval == 0:
		return true
	return false

func is_aoe_shot() -> bool:
	var interval = get_aoe_interval()
	if interval > 0 and shot_counter > 0 and shot_counter % interval == 0:
		return true
	return false

func reset_run():
	reload_counter = 0
	shot_counter = 0
	death_cheat_used = false
	mirror_shard_used = false
	erase_cooldown = 0.0
	first_hit_taken = false

func _physics_process(delta):
	if erase_cooldown > 0:
		erase_cooldown = max(erase_cooldown - delta, 0.0)

func can_erase_now() -> bool:
	return has_erase() and erase_cooldown <= 0.0

func use_erase():
	erase_cooldown = 30.0

func use_death_cheat() -> bool:
	if has_death_cheat() and not death_cheat_used:
		death_cheat_used = true
		return true
	return false

func use_death_shot() -> bool:
	if has_death_shot() and not mirror_shard_used:
		mirror_shard_used = true
		return true
	return false

func on_first_hit() -> bool:
	if has_first_hit_null() and not first_hit_taken:
		first_hit_taken = true
		return true
	return false
