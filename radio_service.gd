extends Node

signal search_completed(tracks: Array)
signal status_changed(message: String)
signal track_changed(track: Dictionary)
signal playback_changed(is_playing: bool)

var tracks: Array[Dictionary] = []
var queue: Array[Dictionary] = []
var current_index: int = -1
var current_track: Dictionary = {}
var last_error := ""

var _search_request: HTTPRequest
var _audio_request: HTTPRequest
var _player: AudioStreamPlayer

func _ready() -> void:
	_search_request = HTTPRequest.new()
	_search_request.timeout = 25.0
	_search_request.max_redirects = 8
	add_child(_search_request)
	_search_request.request_completed.connect(_on_search_completed)
	_audio_request = HTTPRequest.new()
	_audio_request.timeout = 45.0
	_audio_request.max_redirects = 8
	_audio_request.body_size_limit = 16 * 1024 * 1024
	add_child(_audio_request)
	_audio_request.request_completed.connect(_on_audio_completed)
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)
	_player.finished.connect(_on_track_finished)
	_player.volume_db = linear_to_db(float(SaveGame.get_value("radio_volume", 0.75)))
	var saved_queue: Variant = SaveGame.get_value("radio_queue", [])
	if saved_queue is Array:
		for item in saved_queue:
			if item is Dictionary:
				queue.append(item)
	current_index = int(SaveGame.get_value("radio_index", -1))
	if current_index >= 0 and current_index < queue.size():
		current_track = queue[current_index]

func search(query: String, client_id: String = "") -> void:
	var key := client_id.strip_edges()
	if key.is_empty():
		key = str(SaveGame.get_value("radio_client_id", "")).strip_edges()
	if key.is_empty():
		status_changed.emit("Вставь Jamendo client_id в поле API KEY. Без ключа каталог не отвечает.")
		return
	if query.strip_edges().is_empty():
		status_changed.emit("Введи название песни или исполнителя.")
		return
	SaveGame.set_value("radio_client_id", key)
	var url := "https://api.jamendo.com/v3.0/tracks/?client_id=%s&format=json&limit=20&search=%s&audioformat=mp31&include=licenses+musicinfo" % [key.uri_encode(), query.strip_edges().uri_encode()]
	status_changed.emit("Ищу треки в каталоге Jamendo…")
	var error := _search_request.request(url)
	if error != OK:
		status_changed.emit("Не удалось отправить запрос. Код: %s" % error)

func _on_search_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_changed.emit("Ошибка каталога: HTTP %s, сеть %s" % [response_code, result])
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		status_changed.emit("Каталог вернул некорректный ответ.")
		return
	var results: Variant = parsed.get("results", [])
	tracks.clear()
	if results is Array:
		for item in results:
			if item is Dictionary and str(item.get("audio", "")).begins_with("http"):
				var cover_url := str(item.get("album_image", ""))
				if cover_url.is_empty():
					cover_url = str(item.get("image", ""))
				tracks.append({
					"id": str(item.get("id", "")),
					"name": str(item.get("name", "Без названия")),
					"artist": str(item.get("artist_name", "Неизвестный исполнитель")),
					"album": str(item.get("album_name", "")),
					"audio": str(item.get("audio", "")),
					"image": cover_url,
					"license": str(item.get("license_ccurl", "")),
					"duration": int(item.get("duration", 0))
				})
	search_completed.emit(tracks)
	status_changed.emit("Найдено треков: %d" % tracks.size())

func set_queue(new_queue: Array, start_index: int = 0) -> void:
	queue.clear()
	for item in new_queue:
		if item is Dictionary:
			queue.append(item)
	current_index = clampi(start_index, 0, maxi(0, queue.size() - 1))
	_save_queue()
	if not queue.is_empty():
		play_track(queue[current_index])

func play_from_search(index: int) -> void:
	if index < 0 or index >= tracks.size():
		return
	set_queue(tracks, index)

func play_track(track: Dictionary) -> void:
	var audio_url := str(track.get("audio", ""))
	if not audio_url.begins_with("https://") and not audio_url.begins_with("http://"):
		status_changed.emit("У этого трека нет доступного аудиопотока.")
		return
	current_track = track
	if queue.is_empty():
		queue = [track]
	current_index = queue.find(track)
	if current_index < 0:
		queue.append(track)
		current_index = queue.size() - 1
	_save_queue()
	track_changed.emit(current_track)
	status_changed.emit("Загружаю MP3-поток…")
	_player.stop()
	var error := _audio_request.request(audio_url)
	if error != OK:
		status_changed.emit("Не удалось загрузить аудио. Код: %s" % error)

func _on_audio_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or body.is_empty():
		status_changed.emit("Не удалось получить аудио: HTTP %s, сеть %s" % [response_code, result])
		return
	if body.size() > 16 * 1024 * 1024:
		status_changed.emit("Файл больше лимита загрузки 16 МБ.")
		return
	var stream := AudioStreamMP3.new()
	stream.data = body
	_player.stream = stream
	_player.play()
	_add_to_history(current_track)
	track_changed.emit(current_track)
	playback_changed.emit(true)
	status_changed.emit("Воспроизводится MP3-поток Jamendo")

func pause_or_resume() -> void:
	if _player.playing and not _player.stream_paused:
		_player.stream_paused = true
		playback_changed.emit(false)
		status_changed.emit("Пауза")
	elif _player.playing and _player.stream_paused:
		_player.stream_paused = false
		playback_changed.emit(true)
		status_changed.emit("Воспроизведение")
	elif _player.stream != null:
		_player.stream_paused = false
		_player.play()
		playback_changed.emit(true)
		status_changed.emit("Воспроизведение")
	elif not current_track.is_empty():
		play_track(current_track)

func stop() -> void:
	_player.stop()
	playback_changed.emit(false)

func next_track() -> void:
	if queue.is_empty():
		return
	current_index = (current_index + 1) % queue.size()
	play_track(queue[current_index])

func previous_track() -> void:
	if queue.is_empty():
		return
	current_index = posmod(current_index - 1, queue.size())
	play_track(queue[current_index])

func set_volume(value: float) -> void:
	var volume := clampf(value, 0.0, 1.0)
	_player.volume_db = linear_to_db(maxf(volume, 0.001))
	SaveGame.set_value("radio_volume", volume)

func is_playing() -> bool:
	return _player.playing and not _player.stream_paused

func get_favorites() -> Array:
	var value: Variant = SaveGame.get_value("radio_favorites", [])
	return value if value is Array else []

func toggle_favorite(track: Dictionary) -> bool:
	var favorites := get_favorites()
	var track_id := str(track.get("id", ""))
	for i in range(favorites.size()):
		if str(favorites[i].get("id", "")) == track_id:
			favorites.remove_at(i)
			SaveGame.set_value("radio_favorites", favorites)
			return false
	favorites.append(track)
	SaveGame.set_value("radio_favorites", favorites)
	return true

func get_history() -> Array:
	var value: Variant = SaveGame.get_value("radio_history", [])
	return value if value is Array else []

func _add_to_history(track: Dictionary) -> void:
	if track.is_empty():
		return
	var history := get_history()
	history.push_front(track)
	if history.size() > 50:
		history.resize(50)
	SaveGame.set_value("radio_history", history)

func _save_queue() -> void:
	SaveGame.set_value("radio_queue", queue, false)
	SaveGame.set_value("radio_index", current_index, false)
	SaveGame.save_game()

func _on_track_finished() -> void:
	playback_changed.emit(false)
	if queue.size() > 1:
		next_track()
