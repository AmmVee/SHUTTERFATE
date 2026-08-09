extends Node

# Meta-progression
var prints: int = 0
var total_deaths: int = 0
var total_kills: int = 0
var camera_level: int = 1
var unlocked_films: Array = ["obskura"]

# Current run
var run_kills: int = 0
var run_bosses: int = 0
var run_prints_earned: int = 0
var current_floor: int = 1
var current_room: int = 1

func _ready():
	print("GameManager initialized")

func start_run():
	run_kills = 0
	run_bosses = 0
	run_prints_earned = 0
	current_floor = 1
	current_room = 1

	print("Starting new run... Floor 1")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func end_run(success: bool):
	var earned = run_kills * 2 + run_bosses * 50
	if success:
		earned += 100

	prints += earned
	run_prints_earned = earned

	if not success:
		total_deaths += 1

	current_floor = 1
	current_room = 1

	print("Run ended. Success: ", success, " | Prints earned: ", earned)

	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/hub.tscn")

func add_kill():
	run_kills += 1
	total_kills += 1

func add_boss_kill():
	run_bosses += 1

func can_afford(cost: int) -> bool:
	return prints >= cost

func spend_prints(amount: int) -> bool:
	if prints >= amount:
		prints -= amount
		return true
	return false
