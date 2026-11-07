class_name PlayerCar
extends VehicleBody3D

signal vehicle_updated(speed_kmh: float, gear: String, fuel: float, health: float)
signal collision_damage(amount: float)

var drive_controls: Dictionary = {}
var fuel: float = 62.0
var health: float = 100.0
var gear_mode: String = "D"
var steering_sensitivity: float = 1.0
var engine_upgrade: int = 0
var brake_upgrade: int = 0
var lights_on: bool = false
var plate_text: String = "777XAH02"
var paint_color: Color = Color("#b9c2c9")
var _paint_material: StandardMaterial3D
var _front_lights: Array[SpotLight3D] = []
var _last_speed := 0.0

func _ready() -> void:
	mass = 1280.0
	linear_damp = 0.08
	angular_damp = 1.5
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)
	fuel = float(SaveGame.get_value("fuel", 62.0))
	health = float(SaveGame.get_value("health", 100.0))
	gear_mode = "D"
	steering_sensitivity = float(SaveGame.get_value("steering_sensitivity", 1.0))
	engine_upgrade = int(SaveGame.get_value("engine_level", 0))
	brake_upgrade = int(SaveGame.get_value("brake_level", 0))
	paint_color = Color(str(SaveGame.get_value("paint", "#b9c2c9")))
	plate_text = str(SaveGame.get_value("plate", "777XAH02"))
	_create_collision()
	_create_sedan_model()
	_create_wheels()
	_create_lights()
	set_plate(plate_text)

func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "ChassisCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.82, 0.72, 4.15)
	collision.shape = shape
	collision.position = Vector3(0, 0.06, 0)
	add_child(collision)

func _create_sedan_model() -> void:
	_paint_material = StandardMaterial3D.new()
	_paint_material.albedo_color = paint_color
	_paint_material.metallic = 0.52
	_paint_material.roughness = 0.28
	_add_box("BodyPaint", Vector3(1.82, 0.58, 4.22), Vector3(0, 0.1, 0), _paint_material)
	var dark := _mat(Color("#171b20"), 0.82)
	var glass := _mat(Color("#253b49"), 0.16, 0.28)
	var trim := _mat(Color("#080a0c"), 0.65)
	var chrome := _mat(Color("#92999d"), 0.22, 0.78)
	var cabin := _add_box("Cabin", Vector3(1.52, 0.64, 2.18), Vector3(0, 0.68, 0.18), glass)
	_add_box("Roof", Vector3(1.42, 0.13, 1.36), Vector3(0, 1.02, 0.26), _paint_material)
	_add_box("FrontWindshield", Vector3(1.43, 0.48, 0.055), Vector3(0, 0.71, -0.89), glass).rotation.x = deg_to_rad(-18)
	_add_box("RearWindshield", Vector3(1.42, 0.45, 0.055), Vector3(0, 0.71, 1.18), glass).rotation.x = deg_to_rad(18)
	for side in [-1.0, 1.0]:
		_add_box("SideWindowFront", Vector3(0.055, 0.42, 0.86), Vector3(side * 0.77, 0.74, -0.38), glass)
		_add_box("SideWindowRear", Vector3(0.055, 0.42, 0.76), Vector3(side * 0.77, 0.74, 0.57), glass)
		_add_box("WindowPillar", Vector3(0.075, 0.48, 0.09), Vector3(side * 0.78, 0.72, 0.05), trim)
		_add_box("DoorHandleFront", Vector3(0.035, 0.045, 0.22), Vector3(side * 0.925, 0.17, -0.48), chrome)
		_add_box("DoorHandleRear", Vector3(0.035, 0.045, 0.22), Vector3(side * 0.925, 0.17, 0.55), chrome)
		_add_box("SideMirror", Vector3(0.16, 0.12, 0.23), Vector3(side * 0.92, 0.48, -0.83), dark)
	_add_box("FrontBumper", Vector3(1.76, 0.22, 0.18), Vector3(0, -0.06, -2.13), dark)
	_add_box("RearBumper", Vector3(1.76, 0.22, 0.18), Vector3(0, -0.06, 2.13), dark)
	_add_box("FrontGrille", Vector3(0.62, 0.16, 0.045), Vector3(0, 0.12, -2.135), trim)
	_add_box("FrontGrilleChrome", Vector3(0.66, 0.025, 0.025), Vector3(0, 0.12, -2.17), chrome)
	_add_box("RearTrim", Vector3(0.8, 0.035, 0.025), Vector3(0, 0.1, 2.14), chrome)
	for side in [-1.0, 1.0]:
		_add_box("Headlamp", Vector3(0.42, 0.16, 0.055), Vector3(side * 0.58, 0.25, -2.13), _mat(Color("#d9e7ed"), 0.14, 0.5))
		_add_box("TailLamp", Vector3(0.4, 0.18, 0.06), Vector3(side * 0.58, 0.21, 2.14), _mat(Color("#9f2020"), 0.18, 0.2))
		_add_box("WheelArchFrontTrim", Vector3(0.06, 0.13, 0.68), Vector3(side * 0.9, -0.05, -1.25), dark)
		_add_box("WheelArchRearTrim", Vector3(0.06, 0.13, 0.68), Vector3(side * 0.9, -0.05, 1.28), dark)
	_add_plate_mesh(-2.23, false)
	_add_plate_mesh(2.23, true)

func _create_wheels() -> void:
	for z_pos in [-1.32, 1.32]:
		for x_pos in [-0.92, 0.92]:
			var wheel := VehicleWheel3D.new()
			wheel.name = "FrontWheel" if z_pos < 0.0 else "RearWheel"
			wheel.position = Vector3(x_pos, -0.24, z_pos)
			wheel.wheel_radius = 0.34
			wheel.wheel_rest_length = 0.18
			wheel.suspension_travel = 0.18
			wheel.suspension_stiffness = 24.0
			wheel.damping_compression = 0.42
			wheel.damping_relaxation = 0.55
			wheel.suspension_max_force = 7800.0
			wheel.wheel_friction_slip = 3.3
			wheel.wheel_roll_influence = 0.08
			wheel.use_as_traction = z_pos < 0.0 # Cobalt-style front-wheel drive blockout
			wheel.use_as_steering = z_pos < 0.0
			add_child(wheel)
			var tyre := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.31
			cylinder.bottom_radius = 0.31
			cylinder.height = 0.22
			cylinder.radial_segments = 20
			cylinder.material = _mat(Color("#161719"), 0.9)
			tyre.mesh = cylinder
			tyre.rotation.z = PI / 2.0
			wheel.add_child(tyre)
			var hub := MeshInstance3D.new()
			var hub_mesh := CylinderMesh.new()
			hub_mesh.top_radius = 0.16
			hub_mesh.bottom_radius = 0.16
			hub_mesh.height = 0.235
			hub_mesh.radial_segments = 16
			hub_mesh.material = _mat(Color("#aeb4b8"), 0.25, 0.72)
			hub.mesh = hub_mesh
			hub.rotation.z = PI / 2.0
			wheel.add_child(hub)


func _create_lights() -> void:
	for side in [-1.0, 1.0]:
		var light := SpotLight3D.new()
		light.position = Vector3(side * 0.58, 0.25, -2.16)
		light.rotation.x = 0.0
		light.spot_range = 34.0
		light.spot_angle = 28.0
		light.light_energy = 1.35
		light.visible = lights_on
		add_child(light)
		_front_lights.append(light)

func _add_box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	add_child(mesh_instance)
	return mesh_instance

func _add_plate_mesh(z_pos: float, rear: bool) -> void:
	var plate_material := _mat(Color("#f4f3e9"), 0.6)
	var plate := _add_box("Plate", Vector3(0.48, 0.15, 0.018), Vector3(0, 0.11, z_pos), plate_material)
	var label := Label3D.new()
	label.name = "PlateText"
	label.text = plate_text
	label.font_size = 24
	label.pixel_size = 0.0019
	label.modulate = Color("#111820")
	label.outline_size = 2
	label.position = Vector3(0, 0.11, z_pos + (0.012 if not rear else -0.012))
	if not rear:
		label.rotation.y = PI
	add_child(label)

func _mat(color: Color, rough: float = 0.7, metal: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.metallic = metal
	return material

func set_controls(values: Dictionary) -> void:
	drive_controls = values.duplicate()

func set_paint(color: Color) -> void:
	paint_color = color
	_paint_material.albedo_color = color
	SaveGame.set_value("paint", color.to_html(false))

func set_plate(value: String) -> void:
	plate_text = value.to_upper().replace(" ", "")
	for child in get_children():
		if child is Label3D and child.name == "PlateText":
			child.text = plate_text
	SaveGame.set_value("plate", plate_text)

func toggle_lights() -> void:
	lights_on = not lights_on
	for light in _front_lights:
		light.visible = lights_on

func toggle_gear() -> void:
	gear_mode = "R" if gear_mode == "D" else "D"

func refuel(amount: float) -> void:
	fuel = clampf(fuel + amount, 0.0, 100.0)
	SaveGame.set_value("fuel", fuel)

func apply_tuning(power_level: int, brake_level_value: int) -> void:
	engine_upgrade = power_level
	brake_upgrade = brake_level_value
	SaveGame.set_value("engine_level", engine_upgrade)
	SaveGame.set_value("brake_level", brake_upgrade)

func _physics_process(delta: float) -> void:
	var keyboard_steer := Input.get_axis("ui_left", "ui_right")
	var keyboard_throttle := 1.0 if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) else 0.0
	var keyboard_brake := 1.0 if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) else 0.0
	var steer := float(drive_controls.get("left", 0.0)) * -1.0 + float(drive_controls.get("right", 0.0))
	steer += keyboard_steer
	steer = clampf(steer, -1.0, 1.0) * steering_sensitivity
	var throttle := maxf(float(drive_controls.get("throttle", 0.0)), keyboard_throttle)
	var brake_input := maxf(float(drive_controls.get("brake", 0.0)), keyboard_brake)
	var handbrake_input := float(drive_controls.get("handbrake", 0.0))
	var power := 48.0 + float(engine_upgrade) * 8.0
	engine_force = 0.0
	if throttle > 0.0 and fuel > 0.0 and health > 0.0:
		engine_force = power * throttle * (1.0 if gear_mode == "D" else -0.72)
		fuel = maxf(0.0, fuel - throttle * delta * 0.018)
	brake = brake_input * (28.0 + float(brake_upgrade) * 5.0) + handbrake_input * 42.0
	steering = steer * 0.43
	if health <= 0.0:
		engine_force = 0.0
	var speed := linear_velocity.length() * 3.6
	_last_speed = speed
	vehicle_updated.emit(speed, gear_mode, fuel, health)
	if Engine.get_physics_frames() % 300 == 0:
		SaveGame.set_value("fuel", fuel, false)
		SaveGame.set_value("health", health, false)
		SaveGame.save_game()

func _on_body_entered(_body: Node) -> void:
	var impact := linear_velocity.length()
	if impact > 3.0:
		var damage := clampf(impact * 0.7, 1.0, 22.0)
		health = maxf(0.0, health - damage)
		collision_damage.emit(damage)
		SaveGame.set_value("health", health)
