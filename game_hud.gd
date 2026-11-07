class_name GameHUD
extends CanvasLayer

var controls := {"left": 0.0, "right": 0.0, "throttle": 0.0, "brake": 0.0, "handbrake": 0.0}
var player: Node3D
var game_world: Node
var radio_panel: PanelContainer
var garage_panel: PanelContainer
var speed_label: Label
var info_label: Label
var money_label: Label
var status_label: Label
var minimap: Control
var plate_input: LineEdit
var _money := 20000
var _paint_index := 0
var _paint_colors: Array[Color] = [Color("#b9c2c9"), Color("#111820"), Color("#8f1f24"), Color("#173b58"), Color("#e2e0d8"), Color("#334d3f")]

func _ready() -> void:
	_build_hud()
	_money = int(SaveGame.get_value("money", 20000))
	_update_money()

func bind_player(car: Node3D) -> void:
	player = car
	if player.has_signal("vehicle_updated"):
		player.connect("vehicle_updated", _on_vehicle_updated)
	if minimap != null:
		minimap.set("player", player)

func bind_world(world: Node) -> void:
	game_world = world

func set_money_balance(value: int) -> void:
	_money = value
	_update_money()

func get_controls() -> Dictionary:
	return controls

func set_status(message: String) -> void:
	status_label.text = message

func _build_hud() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(14, 12)
	top.size = Vector2(760, 78)
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.075, 0.86)))
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top.add_child(top_row)
	var title := Label.new()
	title.text = "KLS  /  КАЗАХСТАН"
	title.add_theme_font_size_override("font_size", 18)
	top_row.add_child(title)
	speed_label = Label.new()
	speed_label.text = "000 км/ч"
	speed_label.add_theme_font_size_override("font_size", 23)
	top_row.add_child(speed_label)
	info_label = Label.new()
	info_label.text = "D  •  ТОПЛИВО 62%  •  КУЗОВ 100%"
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(info_label)
	money_label = Label.new()
	money_label.text = "20 000 ₸"
	money_label.add_theme_font_size_override("font_size", 18)
	top_row.add_child(money_label)
	var actions := HBoxContainer.new()
	actions.position = Vector2(790, 16)
	actions.size = Vector2(476, 54)
	actions.add_theme_constant_override("separation", 7)
	root.add_child(actions)
	_add_action_button(actions, "РАДИО", _toggle_radio)
	_add_action_button(actions, "ГАРАЖ", _toggle_garage)
	_add_action_button(actions, "КАМЕРА", _next_camera)
	_add_action_button(actions, "СВЕТ", _toggle_lights)
	_add_action_button(actions, "D / R", _toggle_gear)
	_add_action_button(actions, "РАБОТА", _start_delivery)
	var minimap_script := load("res://scripts/minimap.gd")
	minimap = Control.new()
	minimap.set_script(minimap_script)
	minimap.position = Vector2(1050, 105)
	minimap.size = Vector2(210, 150)
	root.add_child(minimap)
	status_label = Label.new()
	status_label.position = Vector2(14, 100)
	status_label.size = Vector2(590, 28)
	status_label.text = "W / ↑ газ • S / ↓ тормоз • A/D руль"
	status_label.add_theme_color_override("font_color", Color("#f1f4f6"))
	root.add_child(status_label)
	_add_drive_button(root, "◀", Vector2(30, -150), Vector2(92, 92), "left")
	_add_drive_button(root, "▶", Vector2(136, -150), Vector2(92, 92), "right")
	_add_drive_button(root, "ГАЗ", Vector2(-132, -184), Vector2(108, 108), "throttle", true)
	_add_drive_button(root, "ТОРМОЗ", Vector2(-254, -112), Vector2(108, 84), "brake")
	_add_drive_button(root, "РУЧНИК", Vector2(-376, -112), Vector2(108, 84), "handbrake")
	radio_panel = PanelContainer.new()
	radio_panel.position = Vector2(350, 108)
	radio_panel.size = Vector2(480, 510)
	radio_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.06, 0.97)))
	var radio_script := load("res://scripts/radio_panel.gd")
	radio_panel.set_script(radio_script)
	root.add_child(radio_panel)
	garage_panel = _build_garage(root)

func _add_action_button(parent: Control, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(70, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)

func _add_drive_button(root: Control, caption: String, offset: Vector2, button_size: Vector2, control_name: String, prominent: bool = false) -> void:
	var button := Button.new()
	button.text = caption
	button.size = button_size
	button.custom_minimum_size = button_size
	button.add_theme_font_size_override("font_size", 20 if prominent else 16)
	if offset.x < 0:
		button.anchor_left = 1.0
		button.anchor_right = 1.0
	else:
		button.anchor_left = 0.0
		button.anchor_right = 0.0
	if offset.y < 0:
		button.anchor_top = 1.0
		button.anchor_bottom = 1.0
	else:
		button.anchor_top = 0.0
		button.anchor_bottom = 0.0
	button.offset_left = offset.x
	button.offset_top = offset.y
	button.offset_right = offset.x + button_size.x
	button.offset_bottom = offset.y + button_size.y
	root.add_child(button)
	button.button_down.connect(func(): _set_control(control_name, 1.0))
	button.button_up.connect(func(): _set_control(control_name, 0.0))

func _set_control(control_name: String, value: float) -> void:
	controls[control_name] = value

func _build_garage(root: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = Vector2(360, 135)
	panel.size = Vector2(450, 430)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.06, 0.97)))
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "ГАРАЖ / CHEVROLET COBALT"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func(): panel.visible = false)
	header.add_child(close)
	column.add_child(header)
	var car_note := Label.new()
	car_note.text = "Сейчас доступен тестовый кузов-седан. Лицензионная 3D-модель Cobalt подключается отдельным asset-пакетом."
	car_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(car_note)
	var paint_row := HBoxContainer.new()
	var paint_label := Label.new()
	paint_label.text = "ЦВЕТ КУЗОВА"
	paint_row.add_child(paint_label)
	var paint_button := Button.new()
	paint_button.text = "СМЕНИТЬ ЦВЕТ"
	paint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_button.pressed.connect(_change_paint)
	paint_row.add_child(paint_button)
	column.add_child(paint_row)
	var plate_caption := Label.new()
	plate_caption.text = "КАЗАХСТАНСКИЙ НОМЕР"
	column.add_child(plate_caption)
	plate_input = LineEdit.new()
	plate_input.text = str(SaveGame.get_value("plate", "777XAH02"))
	plate_input.placeholder_text = "777XAH02"
	column.add_child(plate_input)
	var plate_row := HBoxContainer.new()
	var random_plate := Button.new()
	random_plate.text = "СЛУЧАЙНЫЙ"
	random_plate.pressed.connect(_random_plate)
	plate_row.add_child(random_plate)
	var apply_plate := Button.new()
	apply_plate.text = "УСТАНОВИТЬ"
	apply_plate.pressed.connect(_apply_plate)
	plate_row.add_child(apply_plate)
	column.add_child(plate_row)
	var tune_caption := Label.new()
	tune_caption.text = "УЛУЧШЕНИЯ  •  ДВИГАТЕЛЬ 3 500 ₸  /  ТОРМОЗА 2 500 ₸"
	tune_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(tune_caption)
	var tune_row := HBoxContainer.new()
	var engine_button := Button.new()
	engine_button.text = "+ МОЩНОСТЬ"
	engine_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	engine_button.pressed.connect(_upgrade_engine)
	tune_row.add_child(engine_button)
	var brake_button := Button.new()
	brake_button.text = "+ ТОРМОЗА"
	brake_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brake_button.pressed.connect(_upgrade_brakes)
	tune_row.add_child(brake_button)
	column.add_child(tune_row)
	var fuel_button := Button.new()
	fuel_button.text = "ЗАПРАВИТЬ +25%  •  1 000 ₸"
	fuel_button.pressed.connect(_refuel)
	column.add_child(fuel_button)
	var money := Label.new()
	money.name = "GarageMoney"
	money.text = "Баланс: %s ₸" % _money
	column.add_child(money)
	panel.visible = false
	return panel

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.35, 0.48, 0.58, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _toggle_radio() -> void:
	radio_panel.visible = not radio_panel.visible
	if radio_panel.visible and garage_panel.visible:
		garage_panel.visible = false

func _toggle_garage() -> void:
	garage_panel.visible = not garage_panel.visible
	if garage_panel.visible and radio_panel.visible:
		radio_panel.visible = false

func _next_camera() -> void:
	if get_parent().has_method("cycle_camera"):
		get_parent().call("cycle_camera")

func _toggle_lights() -> void:
	if player != null and player.has_method("toggle_lights"):
		player.call("toggle_lights")

func _start_delivery() -> void:
	if game_world != null and game_world.has_method("begin_delivery"):
		game_world.call("begin_delivery")

func _toggle_gear() -> void:
	if player != null and player.has_method("toggle_gear"):
		player.call("toggle_gear")

func _change_paint() -> void:
	if player == null:
		return
	_paint_index = (_paint_index + 1) % _paint_colors.size()
	player.call("set_paint", _paint_colors[_paint_index])
	set_status("Цвет кузова изменён и сохранён.")

func _random_plate() -> void:
	var letters := "ABCEHKMOPTXY"
	var plate := "%03d%s%02d" % [randi_range(100, 999), _random_letters(letters, 3), randi_range(1, 20)]
	plate_input.text = plate

func _random_letters(pool: String, count: int) -> String:
	var result := ""
	for i in range(count):
		result += pool.substr(randi_range(0, pool.length() - 1), 1)
	return result

func _apply_plate() -> void:
	var value := plate_input.text.to_upper().replace(" ", "")
	if value.length() < 8:
		set_status("Номер слишком короткий. Формат: 777XAH02")
		return
	if player != null:
		player.call("set_plate", value)
		set_status("Госномер сохранён: %s" % value)

func _upgrade_engine() -> void:
	if _money < 3500:
		set_status("Не хватает денег на улучшение двигателя.")
		return
	_money -= 3500
	var level := int(SaveGame.get_value("engine_level", 0)) + 1
	if player != null:
		player.call("apply_tuning", level, int(SaveGame.get_value("brake_level", 0)))
	SaveGame.set_value("money", _money)
	_update_money()
	set_status("Мощность двигателя улучшена. Уровень %d." % level)

func _upgrade_brakes() -> void:
	if _money < 2500:
		set_status("Не хватает денег на тормоза.")
		return
	_money -= 2500
	var level := int(SaveGame.get_value("brake_level", 0)) + 1
	if player != null:
		player.call("apply_tuning", int(SaveGame.get_value("engine_level", 0)), level)
	SaveGame.set_value("money", _money)
	_update_money()
	set_status("Тормозная система улучшена. Уровень %d." % level)

func _refuel() -> void:
	if _money < 1000:
		set_status("Не хватает денег на топливо.")
		return
	_money -= 1000
	if player != null:
		player.call("refuel", 25.0)
	SaveGame.set_value("money", _money)
	_update_money()
	set_status("Заправка выполнена: +25% топлива.")

func _update_money() -> void:
	if money_label != null:
		money_label.text = "%s ₸" % _money
	if garage_panel != null:
		var label := garage_panel.find_child("GarageMoney", true, false)
		if label is Label:
			label.text = "Баланс: %s ₸" % _money

func _on_vehicle_updated(speed: float, gear: String, fuel: float, health: float) -> void:
	speed_label.text = "%03d км/ч" % int(round(speed))
	info_label.text = "%s  •  ТОПЛИВО %d%%  •  КУЗОВ %d%%" % [gear, int(fuel), int(health)]
