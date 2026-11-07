extends Node

const SAVE_PATH := "user://kls_save.json"
var data: Dictionary = {
	"money": 20000,
	"player_car": "Chevrolet Cobalt",
	"plate": "777XAH02",
	"paint": "#b9c2c9",
	"engine_level": 0,
	"brake_level": 0,
	"suspension_level": 0,
	"fuel": 62.0,
	"health": 100.0,
	"graphics": "Средние",
	"steering_sensitivity": 1.0,
	"camera_mode": 0,
	"radio_client_id": "",
	"radio_volume": 0.75,
	"radio_favorites": [],
	"radio_history": [],
	"radio_queue": [],
	"radio_index": -1
}

func _ready() -> void:
	load_game()

func get_value(key: String, fallback: Variant = null) -> Variant:
	return data.get(key, fallback)

func set_value(key: String, value: Variant, save_now: bool = true) -> void:
	data[key] = value
	if save_now:
		save_game()

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open save file: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		for key in parsed:
			data[key] = parsed[key]

func _exit_tree() -> void:
	save_game()
