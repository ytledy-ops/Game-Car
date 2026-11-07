extends PanelContainer

var query_input: LineEdit
var key_input: LineEdit
var status_label: Label
var current_label: Label
var results_list: VBoxContainer
var play_pause_button: Button
var favorites_button: Button
var cover_image: TextureRect
var _cover_request: HTTPRequest
var _showing_favorites := false

func _ready() -> void:
	custom_minimum_size = Vector2(470, 500)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_build_ui()
	_cover_request = HTTPRequest.new()
	_cover_request.timeout = 20.0
	add_child(_cover_request)
	_cover_request.request_completed.connect(_on_cover_downloaded)
	RadioService.search_completed.connect(_on_search_completed)
	RadioService.status_changed.connect(_on_status_changed)
	RadioService.track_changed.connect(_on_track_changed)
	RadioService.playback_changed.connect(_on_playback_changed)
	visible = false
	if not RadioService.current_track.is_empty():
		_on_track_changed(RadioService.current_track)

func _build_ui() -> void:
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 8)
	add_child(frame)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "KLS RADIO  /  JAMENDO"
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func(): visible = false)
	header.add_child(close)
	frame.add_child(header)
	var key_caption := Label.new()
	key_caption.text = "API KEY / client_id (Jamendo Developer Portal)"
	frame.add_child(key_caption)
	key_input = LineEdit.new()
	key_input.placeholder_text = "Вставь свой client_id"
	key_input.secret = true
	key_input.text = str(SaveGame.get_value("radio_client_id", ""))
	frame.add_child(key_input)
	var search_row := HBoxContainer.new()
	query_input = LineEdit.new()
	query_input.placeholder_text = "Название песни или исполнитель"
	query_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	query_input.text_submitted.connect(_search)
	search_row.add_child(query_input)
	var search_button := Button.new()
	search_button.text = "НАЙТИ"
	search_button.pressed.connect(_search)
	search_row.add_child(search_button)
	frame.add_child(search_row)
	var filter_row := HBoxContainer.new()
	var results_button := Button.new()
	results_button.text = "РЕЗУЛЬТАТЫ"
	results_button.pressed.connect(_show_search_results)
	filter_row.add_child(results_button)
	favorites_button = Button.new()
	favorites_button.text = "ИЗБРАННОЕ"
	favorites_button.pressed.connect(_show_favorites)
	filter_row.add_child(favorites_button)
	var history_button := Button.new()
	history_button.text = "ИСТОРИЯ"
	history_button.pressed.connect(_show_history)
	filter_row.add_child(history_button)
	frame.add_child(filter_row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 205)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_list = VBoxContainer.new()
	results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(results_list)
	frame.add_child(scroll)
	var now_row := HBoxContainer.new()
	cover_image = TextureRect.new()
	cover_image.custom_minimum_size = Vector2(64, 64)
	cover_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	now_row.add_child(cover_image)
	current_label = Label.new()
	current_label.text = "Сейчас ничего не играет"
	current_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	now_row.add_child(current_label)
	frame.add_child(now_row)
	var playback_row := HBoxContainer.new()
	var previous := Button.new()
	previous.text = "|◀"
	previous.pressed.connect(RadioService.previous_track)
	playback_row.add_child(previous)
	play_pause_button = Button.new()
	play_pause_button.text = "▶ / ПАУЗА"
	play_pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_pause_button.pressed.connect(RadioService.pause_or_resume)
	playback_row.add_child(play_pause_button)
	var next := Button.new()
	next.text = "▶|"
	next.pressed.connect(RadioService.next_track)
	playback_row.add_child(next)
	frame.add_child(playback_row)
	var volume_row := HBoxContainer.new()
	var volume_caption := Label.new()
	volume_caption.text = "ГРОМКОСТЬ"
	volume_row.add_child(volume_caption)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = float(SaveGame.get_value("radio_volume", 0.75))
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.value_changed.connect(RadioService.set_volume)
	volume_row.add_child(volume)
	frame.add_child(volume_row)
	status_label = Label.new()
	status_label.text = "Для поиска нужен бесплатный Jamendo client_id."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame.add_child(status_label)

func _search(_submitted: String = "") -> void:
	RadioService.search(query_input.text, key_input.text)

func _render_tracks(items: Array) -> void:
	for child in results_list.get_children():
		child.queue_free()
	for item in items:
		if not (item is Dictionary):
			continue
		var row := HBoxContainer.new()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		title.text = str(item.get("name", "Без названия"))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(title)
		var artist := Label.new()
		artist.text = str(item.get("artist", "")) + "  •  " + _license_short(str(item.get("license", "")))
		artist.add_theme_font_size_override("font_size", 12)
		artist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(artist)
		row.add_child(info)
		var play := Button.new()
		play.text = "▶"
		play.pressed.connect(_play_track.bind(item))
		row.add_child(play)
		var favorite := Button.new()
		favorite.text = "★"
		favorite.pressed.connect(_toggle_favorite.bind(item))
		row.add_child(favorite)
		results_list.add_child(row)
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Список пуст. Выполни поиск."
		results_list.add_child(empty)

func _license_short(url: String) -> String:
	if url.is_empty():
		return "лицензия не указана"
	var parts := url.trim_suffix("/").split("/")
	if parts.size() >= 2:
		return "CC %s %s" % [parts[parts.size() - 2].to_upper(), parts[parts.size() - 1]]
	return "CC"

func _on_search_completed(items: Array) -> void:
	_showing_favorites = false
	_render_tracks(items)

func _on_status_changed(message: String) -> void:
	status_label.text = message

func _on_track_changed(track: Dictionary) -> void:
	current_label.text = "СЕЙЧАС: %s — %s" % [track.get("artist", ""), track.get("name", "")]
	var image_url := str(track.get("image", ""))
	if image_url.begins_with("https://") or image_url.begins_with("http://"):
		_cover_request.request(image_url)

func _on_cover_downloaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or body.is_empty():
		return
	var loaded := Image.new()
	var error := loaded.load_jpg_from_buffer(body)
	if error != OK:
		error = loaded.load_png_from_buffer(body)
	if error == OK:
		cover_image.texture = ImageTexture.create_from_image(loaded)

func _play_track(track: Dictionary) -> void:
	RadioService.play_track(track)

func _toggle_favorite(track: Dictionary) -> void:
	var added := RadioService.toggle_favorite(track)
	status_label.text = "Добавлено в избранное" if added else "Удалено из избранного"

func _show_search_results() -> void:
	_showing_favorites = false
	_render_tracks(RadioService.tracks)

func _on_playback_changed(playing: bool) -> void:
	play_pause_button.text = "⏸ ПАУЗА" if playing else "▶ ПРОДОЛЖИТЬ"

func _show_favorites() -> void:
	_showing_favorites = true
	_render_tracks(RadioService.get_favorites())

func _show_history() -> void:
	_showing_favorites = false
	_render_tracks(RadioService.get_history())
