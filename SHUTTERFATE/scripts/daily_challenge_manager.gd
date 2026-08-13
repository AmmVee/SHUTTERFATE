extends Node

# ========== DAILY CHALLENGE SYSTEM ==========
# Generates a new challenge each day based on system date

var current_challenge: Dictionary = {}
var challenge_seed: int = 0
var best_score_today: int = 0
var leaderboard: Array[Dictionary] = []

const CHALLENGE_TYPES = [
    {
        "id": "speedrun",
        "name": "На скорость",
        "desc": "Пройдите этаж за 60 секунд",
        "time_limit": 60,
        "bonus_prints": 150
    },
    {
        "id": "no_reload",
        "name": "Без перезарядки",
        "desc": "Пройдите этаж, не перезаряжаясь",
        "bonus_prints": 200
    },
    {
        "id": "one_film",
        "name": "Один кадр",
        "desc": "Убейте 10 врагов одним выстрелом",
        "target_kills": 10,
        "bonus_prints": 250
    },
    {
        "id": "pacifist",
        "name": "Минималист",
        "desc": "Пройдите этаж, убив не более 5 врагов",
        "max_kills": 5,
        "bonus_prints": 300
    },
    {
        "id": "elite_hunt",
        "name": "Охота на элиту",
        "desc": "Убейте 3 элитных врага за забег",
        "target_elite": 3,
        "bonus_prints": 200
    },
    {
        "id": "boss_rush",
        "name": "Босс-раш",
        "desc": "Победите босса за 30 секунд",
        "boss_time_limit": 30,
        "bonus_prints": 300
    },
    {
        "id": "no_damage",
        "name": "Идеальный забег",
        "desc": "Пройдите этаж без получения урона",
        "bonus_prints": 400
    }
]

func _ready():
    generate_daily_challenge()
    print("Daily challenge: ", current_challenge.get("name", "None"))

func generate_daily_challenge():
    var today = Time.get_date_dict_from_system()
    challenge_seed = today.year * 10000 + today.month * 100 + today.day
    seed(challenge_seed)

    var idx = randi() % CHALLENGE_TYPES.size()
    current_challenge = CHALLENGE_TYPES[idx].duplicate()
    current_challenge["date"] = "%04d-%02d-%02d" % [today.year, today.month, today.day]
    current_challenge["completed"] = false
    current_challenge["best_score"] = 0

func get_challenge() -> Dictionary:
    return current_challenge

func is_daily_mode() -> bool:
    return current_challenge.size() > 0 and not current_challenge.get("completed", false)

func complete_challenge(score: int):
    if score > best_score_today:
        best_score_today = score
        current_challenge["best_score"] = score
    current_challenge["completed"] = true
    _add_to_leaderboard(score)

func _add_to_leaderboard(score: int):
    var entry = {
        "score": score,
        "date": current_challenge.get("date", ""),
        "challenge": current_challenge.get("name", ""),
        "floor": GameManager.current_floor
    }
    leaderboard.append(entry)
    leaderboard.sort_custom(func(a, b): return a["score"] > b["score"])
    if leaderboard.size() > 10:
        leaderboard.resize(10)

func get_leaderboard() -> Array:
    return leaderboard

func reset_daily():
    current_challenge["completed"] = false
    current_challenge["best_score"] = 0
