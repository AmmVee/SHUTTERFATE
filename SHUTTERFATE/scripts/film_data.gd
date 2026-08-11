extends Resource
class_name FilmData

@export var film_id: String = ""
@export var display_name: String = "Unknown Film"
@export var description: String = ""
@export var max_frames: int = 36
@export var base_damage_mult: float = 1.0
@export var focus_mult: float = 1.0
@export var exposure_mult: float = 1.0
@export var iso_mult: float = 1.0
@export var aperture_mult: float = 1.0
@export var focus_build_rate: float = 1.0
@export var reload_time: float = 2.5
@export var special_id: String = ""
@export var rarity: String = "white"  # white, green, blue, purple, yellow, red, gold
@export var rarity_color: Color = Color.WHITE
