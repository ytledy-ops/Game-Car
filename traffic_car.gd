class_name TrafficCar
extends Node3D

var route: Array[Vector3] = []
var target_index := 0
var cruise_speed := 9.0
var vehicle_kind := "sedan"
var paint_color := Color("#7b8992")
var _visual_root: Node3D

func _ready() -> void:
	_build_visual()

func _process(delta: float) -> void:
	if route.size() < 2:
		return
	var target := route[target_index]
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 3.0:
		target_index = (target_index + 1) % route.size()
		return
	var direction := to_target.normalized()
	var wanted_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, wanted_yaw, minf(delta * 2.4, 1.0))
	var forward := -global_transform.basis.z
	global_position += forward * cruise_speed * delta

func _build_visual() -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = paint_color
	body_mat.metallic = 0.3
	body_mat.roughness = 0.38
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#273b46")
	glass.roughness = 0.16
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("#111315")
	var body_size := Vector3(1.72, 0.55, 3.75)
	var cabin_size := Vector3(1.43, 0.62, 1.85)
	var cabin_y := 0.99
	if vehicle_kind == "bus":
		body_size = Vector3(2.35, 1.35, 7.0)
		cabin_size = Vector3(2.05, 0.85, 4.9)
		cabin_y = 1.75
	elif vehicle_kind == "truck":
		body_size = Vector3(2.1, 0.9, 5.1)
		cabin_size = Vector3(1.9, 0.9, 1.8)
		cabin_y = 1.35
	elif vehicle_kind == "minivan":
		body_size = Vector3(1.85, 0.72, 4.45)
		cabin_size = Vector3(1.62, 0.78, 2.7)
		cabin_y = 1.24
	_add_box("Body", body_size, Vector3(0, body_size.y * 0.5, 0), body_mat)
	_add_box("Cabin", cabin_size, Vector3(0, cabin_y, 0.16), glass)
	_add_box("Roof", Vector3(cabin_size.x * 0.94, 0.1, cabin_size.z * 0.7), Vector3(0, cabin_y + cabin_size.y * 0.52, 0.2), body_mat)
	if vehicle_kind == "taxi":
		_add_box("TaxiRoofSign", Vector3(0.55, 0.2, 0.28), Vector3(0, cabin_y + cabin_size.y * 0.62, 0.1), StandardMaterial3D.new())
	if vehicle_kind == "police":
		_add_box("PoliceLightBar", Vector3(0.72, 0.17, 0.25), Vector3(0, cabin_y + cabin_size.y * 0.62, 0.12), StandardMaterial3D.new())
	var wheel_z := body_size.z * 0.29
	for side in [-1.0, 1.0]:
		for z in [-wheel_z, wheel_z]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.29 if vehicle_kind != "bus" else 0.46
			mesh.bottom_radius = mesh.top_radius
			mesh.height = 0.18
			mesh.material = black
			wheel.mesh = mesh
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(side * body_size.x * 0.5, mesh.top_radius, z)
			_visual_root.add_child(wheel)

func _add_box(label: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	item.mesh = mesh
	item.position = pos
	_visual_root.add_child(item)
