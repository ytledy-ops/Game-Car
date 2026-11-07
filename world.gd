extends Node3D

const PlayerCarScript = preload("res://scripts/player_car.gd")
const TrafficCarScript = preload("res://scripts/traffic_car.gd")
const HUDScript = preload("res://scripts/game_hud.gd")

var rng := RandomNumberGenerator.new()
var player_car: PlayerCar
var hud: GameHUD
var follow_camera: Camera3D
var camera_mode := 0
var _day_clock := 0.28
var _sun: DirectionalLight3D
var _world_environment: WorldEnvironment
var _road_loop: Array[Vector3] = []
var _street_lamps: Array[OmniLight3D] = []
var _delivery_active := false
var _delivery_target := Vector3(112, 0.2, 142)
var _delivery_marker: Node3D

func _ready() -> void:
	rng.randomize()
	camera_mode = clampi(int(SaveGame.get_value("camera_mode", 0)), 0, 3)
	_build_environment()
	_build_ground()
	_build_city_roads()
	_build_districts()
	_build_public_spaces()
	_build_street_furniture()
	_spawn_player()
	_spawn_traffic()
	_build_hud()
	_build_camera()
	SaveGame.set_value("player_car", "Chevrolet Cobalt", false)

func _process(delta: float) -> void:
	_day_clock = fmod(_day_clock + delta * 0.00022, 1.0)
	_update_daylight()
	if player_car != null and hud != null:
		player_car.call("set_controls", hud.get_controls())
		_update_camera(delta)
		_update_delivery()

func _build_environment() -> void:
	_world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#3274a7")
	sky_material.sky_horizon_color = Color("#d5a77e")
	sky_material.ground_bottom_color = Color("#252b31")
	sky_material.ground_horizon_color = Color("#9b9b91")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ambient_light_energy = 0.75
	environment.ambient_light_color = Color("#c5d4e3")
	_world_environment.environment = environment
	add_child(_world_environment)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-48, -28, 0)
	_sun.light_energy = 1.35
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 95.0
	add_child(_sun)

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var mesh_instance := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(760, 760)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#6f765d")
	material.roughness = 1.0
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.24
	ground.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(760, 0.4, 760)
	collision.shape = shape
	collision.position.y = -0.44
	ground.add_child(collision)
	add_child(ground)

func _build_city_roads() -> void:
	var loop_2d: Array[Vector2] = [
		Vector2(-190, -24), Vector2(-100, -72), Vector2(8, -56), Vector2(126, -18),
		Vector2(180, 62), Vector2(112, 142), Vector2(-18, 132), Vector2(-148, 72)
	]
	for point in loop_2d:
		_road_loop.append(Vector3(point.x, 0.08, point.y))
	_create_road_polyline(loop_2d, 15.0, true)
	_road_loop.append(_road_loop[0])
	var branches: Array[Dictionary] = [
		{"points": [Vector2(-100, -72), Vector2(-126, -132), Vector2(-75, -205), Vector2(5, -225)], "width": 10.0},
		{"points": [Vector2(8, -56), Vector2(40, -118), Vector2(112, -186), Vector2(214, -206)], "width": 12.0},
		{"points": [Vector2(-148, 72), Vector2(-215, 110), Vector2(-270, 75)], "width": 9.0},
		{"points": [Vector2(-18, 132), Vector2(-4, 205), Vector2(78, 245), Vector2(190, 226)], "width": 13.0},
		{"points": [Vector2(180, 62), Vector2(240, 104), Vector2(278, 174)], "width": 9.0},
		{"points": [Vector2(-190, -24), Vector2(-250, -66), Vector2(-280, -140)], "width": 9.0}
	]
	for branch in branches:
		_create_road_polyline(branch["points"], float(branch["width"]), true)
	_create_roundabout(Vector3(8, 0.0, -56), 8.0)
	_create_crosswalk(Vector3(-100, 0.13, -72), 0.0, 7.5)
	_create_crosswalk(Vector3(126, 0.13, -18), deg_to_rad(20), 7.5)
	_create_crosswalk(Vector3(-18, 0.13, 132), deg_to_rad(90), 7.5)

func _create_road_polyline(points: Array, width: float, sidewalks: bool) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var delta := b - a
		var length := delta.length()
		if length < 1.0:
			continue
		var yaw := atan2(delta.x, delta.y)
		var midpoint := Vector3((a.x + b.x) * 0.5, 0.015, (a.y + b.y) * 0.5)
		_add_static_box("Road", Vector3(width, 0.12, length + 1.2), midpoint, yaw, Color("#303438"), true)
		var right := Vector3(1, 0, 0).rotated(Vector3.UP, yaw)
		if sidewalks:
			for side in [-1.0, 1.0]:
				var side_pos := midpoint + right * side * (width * 0.5 + 1.35)
				_add_static_box("Sidewalk", Vector3(2.5, 0.18, length + 1.2), Vector3(side_pos.x, 0.11, side_pos.z), yaw, Color("#858783"), false)
				_add_static_box("Kerb", Vector3(0.16, 0.24, length + 1.2), Vector3(midpoint.x + right.x * side * (width * 0.5), 0.14, midpoint.z + right.z * side * (width * 0.5)), yaw, Color("#c1c2b9"), false)
		var dash_count := int(length / 15.0)
		for dash in range(dash_count):
			var t := (float(dash) + 0.5) / float(dash_count)
			var pos_2d := a.lerp(b, t)
			_add_mesh_box("RoadMarking", Vector3(0.16, 0.018, 4.2), Vector3(pos_2d.x, 0.092, pos_2d.y), yaw, Color("#d9d6c9"))

func _add_static_box(label: String, size: Vector3, pos: Vector3, yaw: float, color: Color, collision: bool) -> void:
	var root := StaticBody3D.new() if collision else Node3D.new()
	root.name = label
	root.position = pos
	root.rotation.y = yaw
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color, 0.94)
	visual.mesh = mesh
	root.add_child(visual)
	if collision:
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		root.add_child(shape_node)
	add_child(root)

func _add_mesh_box(label: String, size: Vector3, pos: Vector3, yaw: float, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color, 0.8)
	visual.mesh = mesh
	visual.position = pos
	visual.rotation.y = yaw
	add_child(visual)
	return visual

func _create_crosswalk(center: Vector3, yaw: float, road_width: float) -> void:
	var right := Vector3(1, 0, 0).rotated(Vector3.UP, yaw)
	for i in range(8):
		var offset := (float(i) - 3.5) * 0.78
		var pos := center + right * offset
		_add_mesh_box("CrosswalkStripe", Vector3(0.42, 0.022, 4.3), Vector3(pos.x, 0.105, pos.z), yaw, Color("#efeee7"))

func _create_roundabout(center: Vector3, radius: float) -> void:
	var island := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius + 0.35
	cylinder.height = 0.32
	cylinder.radial_segments = 40
	cylinder.material = _material(Color("#67765a"), 1.0)
	island.mesh = cylinder
	island.position = center + Vector3(0, 0.12, 0)
	add_child(island)
	var center_tree := _create_tree(center + Vector3(0, 0.3, 0), 1.25)
	center_tree.scale = Vector3(1.4, 1.6, 1.4)

func _build_districts() -> void:
	var districts: Array[Dictionary] = [
		{"center": Vector2(-140, -145), "count": 6, "style": "panel"},
		{"center": Vector2(96, -135), "count": 6, "style": "modern"},
		{"center": Vector2(165, 170), "count": 5, "style": "mixed"},
		{"center": Vector2(-250, 155), "count": 7, "style": "private"},
		{"center": Vector2(-5, 245), "count": 4, "style": "commercial"}
	]
	for district in districts:
		var center: Vector2 = district["center"]
		var count: int = district["count"]
		var district_style: String = district["style"]
		for i in range(count):
			var angle := TAU * float(i) / float(count) + rng.randf_range(-0.24, 0.24)
			var distance := rng.randf_range(23.0, 72.0)
			var pos := center + Vector2(cos(angle), sin(angle)) * distance
			pos.x += rng.randf_range(-9.0, 9.0)
			pos.y += rng.randf_range(-8.0, 8.0)
			_create_building(Vector3(pos.x, 0, pos.y), district_style, i)
		for i in range(5):
			var tree_angle := rng.randf_range(0.0, TAU)
			var tree_dist := rng.randf_range(78.0, 105.0)
			var tree_pos := center + Vector2(cos(tree_angle), sin(tree_angle)) * tree_dist
			_create_tree(Vector3(tree_pos.x, 0, tree_pos.y), rng.randf_range(0.85, 1.2))

func _create_building(world_pos: Vector3, district_style: String, variant: int) -> void:
	var is_private := district_style == "private"
	var is_commercial := district_style == "commercial" and variant % 2 == 0
	var floors := rng.randi_range(1, 2) if is_private else rng.randi_range(3, 7)
	if district_style == "modern":
		floors = rng.randi_range(6, 11)
	if is_commercial:
		floors = rng.randi_range(1, 3)
	var width := rng.randf_range(10.0, 19.0) if not is_private else rng.randf_range(8.0, 12.0)
	var depth := rng.randf_range(9.0, 16.0) if not is_private else rng.randf_range(8.0, 12.0)
	var height := float(floors) * (2.6 if not is_private else 2.9)
	var building := StaticBody3D.new()
	building.name = "Building_%s_%02d" % [district_style, variant]
	building.position = world_pos
	building.rotation.y = rng.randf_range(-0.35, 0.35)
	add_child(building)
	var wall_palette: Array[Color] = [Color("#b9b5a9"), Color("#a6a9aa"), Color("#d0c4ad"), Color("#8d9a9b"), Color("#c1b6a6"), Color("#8c8a7f")]
	if district_style == "modern":
		wall_palette = [Color("#c9d0d4"), Color("#8d9fa8"), Color("#d8dce0"), Color("#7e8c91"), Color("#c0b9ab")]
	if district_style == "private":
		wall_palette = [Color("#d7c7ad"), Color("#c0b09c"), Color("#a8b6a6"), Color("#d8d4c8")]
	var wall_mat := _material(wall_palette[rng.randi_range(0, wall_palette.size() - 1)], 0.92)
	var core := MeshInstance3D.new()
	core.name = "FacadeCore"
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(width, height, depth)
	core_mesh.material = wall_mat
	core.mesh = core_mesh
	core.position.y = height * 0.5
	building.add_child(core)
	var core_collision := CollisionShape3D.new()
	var core_shape := BoxShape3D.new()
	core_shape.size = Vector3(width, height, depth)
	core_collision.shape = core_shape
	core_collision.position.y = height * 0.5
	building.add_child(core_collision)
	var glass_mat := _material(Color("#334c58") if not is_private else Color("#42545a"), 0.18, 0.18)
	var frame_mat := _material(Color("#e1dfd7") if not is_private else Color("#6c6258"), 0.75)
	var balcony_mat := _material(Color("#777f80"), 0.66, 0.25)
	var front_z := -depth * 0.5 - 0.055
	var columns := clampi(int(width / 2.45), 3, 6)
	var rows := floors if not is_private else floors - 1
	var frame_positions: Array[Vector3] = []
	var glass_positions: Array[Vector3] = []
	var sill_positions: Array[Vector3] = []
	var balcony_slabs: Array[Vector3] = []
	var balcony_rails: Array[Vector3] = []
	var balcony_sides: Array[Vector3] = []
	var window_w := minf(0.9, width / float(columns) * 0.58)
	var window_h := 1.12 if not is_private else 0.88
	for row in range(maxi(rows, 1)):
		var y := 0.55 + float(row) * 2.55
		for col in range(columns):
			var x := -width * 0.5 + (float(col) + 0.5) * width / float(columns)
			frame_positions.append(Vector3(x, y + 0.25, front_z - 0.015))
			glass_positions.append(Vector3(x, y + 0.25, front_z - 0.065))
			sill_positions.append(Vector3(x, y - 0.34, front_z - 0.08))
			if not is_private and row > 0 and rng.randf() > 0.65:
				balcony_slabs.append(Vector3(x, y - 0.5, front_z - 0.3))
				balcony_rails.append(Vector3(x, y - 0.02, front_z - 0.52))
				balcony_sides.append(Vector3(x - (window_w + 0.9) * 0.5, y - 0.26, front_z - 0.31))
				balcony_sides.append(Vector3(x + (window_w + 0.9) * 0.5, y - 0.26, front_z - 0.31))
	_add_multimesh(building, "WindowFrames", Vector3(window_w + 0.13, window_h + 0.13, 0.08), frame_mat, frame_positions)
	_add_multimesh(building, "WindowGlass", Vector3(window_w, window_h, 0.045), glass_mat, glass_positions)
	_add_multimesh(building, "WindowSills", Vector3(window_w + 0.25, 0.08, 0.18), frame_mat, sill_positions)
	_add_multimesh(building, "BalconySlabs", Vector3(window_w + 0.9, 0.12, 0.48), balcony_mat, balcony_slabs)
	_add_multimesh(building, "BalconyRails", Vector3(window_w + 0.9, 0.07, 0.07), balcony_mat, balcony_rails)
	_add_multimesh(building, "BalconySideRails", Vector3(0.07, 0.48, 0.42), balcony_mat, balcony_sides)
	if not is_private:
		var side_positions: Array[Vector3] = []
		for side in [-1.0, 1.0]:
			var side_x := side * (width * 0.5 + 0.05)
			for row in range(floors):
				var y := 0.65 + float(row) * 2.55
				for col in range(maxi(2, int(depth / 3.2))):
					var z := -depth * 0.5 + (float(col) + 0.5) * depth / float(maxi(2, int(depth / 3.2)))
					side_positions.append(Vector3(side_x, y, z))
		_add_multimesh(building, "SideWindows", Vector3(0.05, 0.9, 0.82), glass_mat, side_positions)
	else:
		var roof_mat := _material(Color("#514b46"), 0.9)
		for side in [-1.0, 1.0]:
			var roof_panel := MeshInstance3D.new()
			var roof_mesh := BoxMesh.new()
			roof_mesh.size = Vector3(width * 0.57, 0.16, depth + 0.9)
			roof_mesh.material = roof_mat
			roof_panel.mesh = roof_mesh
			roof_panel.position = Vector3(side * width * 0.23, height + 0.48, 0)
			roof_panel.rotation.z = deg_to_rad(side * -26.0)
			building.add_child(roof_panel)
	if is_commercial:
		_add_building_box(building, "ShopSign", Vector3(width * 0.64, 0.48, 0.16), Vector3(0, 1.65, front_z - 0.11), _material(Color("#31566a"), 0.6))
		var sign := Label3D.new()
		sign.text = ["МАРКЕТ", "24/7", "АЗЫК-ТҮЛІК", "СУПЕРМАРКЕТ"][variant % 4]
		sign.font_size = 34
		sign.pixel_size = 0.004
		sign.modulate = Color.WHITE
		sign.position = Vector3(0, 1.65, front_z - 0.21)
		building.add_child(sign)
	else:
		_add_building_box(building, "EntranceCanopy", Vector3(2.4, 0.14, 0.9), Vector3(0, 1.65, front_z - 0.45), _material(Color("#535b60"), 0.7))
		_add_building_box(building, "EntranceDoor", Vector3(1.1, 1.9, 0.07), Vector3(0, 0.96, front_z - 0.09), _material(Color("#273c43"), 0.25, 0.2))
		if floors >= 6:
			for i in range(3):
				_add_building_box(building, "RoofVent", Vector3(0.65, 0.85, 0.75), Vector3(rng.randf_range(-width * 0.3, width * 0.3), height + 0.45, rng.randf_range(-depth * 0.3, depth * 0.3)), _material(Color("#777d7d"), 0.85))

func _add_multimesh(parent: Node3D, node_name: String, mesh_size: Vector3, material: Material, positions: Array[Vector3]) -> void:
	if positions.is_empty():
		return
	var box := BoxMesh.new()
	box.size = mesh_size
	box.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = box
	multi.instance_count = positions.size()
	for i in range(positions.size()):
		var transform := Transform3D.IDENTITY
		transform.origin = positions[i]
		multi.set_instance_transform(i, transform)
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	parent.add_child(instance)

func _add_balcony(parent: Node3D, x: float, y: float, z: float, width: float, material: Material) -> void:
	_add_building_box(parent, "BalconySlab", Vector3(width, 0.12, 0.48), Vector3(x, y, z - 0.18), material)
	_add_building_box(parent, "BalconyRail", Vector3(width, 0.07, 0.07), Vector3(x, y + 0.48, z - 0.4), material)
	_add_building_box(parent, "BalconySideRailL", Vector3(0.07, 0.48, 0.42), Vector3(x - width * 0.5, y + 0.24, z - 0.2), material)
	_add_building_box(parent, "BalconySideRailR", Vector3(0.07, 0.48, 0.42), Vector3(x + width * 0.5, y + 0.24, z - 0.2), material)

func _add_building_box(parent: Node3D, node_name: String, size: Vector3, local_pos: Vector3, material: Material) -> void:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	item.mesh = mesh
	item.position = local_pos
	parent.add_child(item)

func _build_public_spaces() -> void:
	var park_centers: Array[Vector3] = [Vector3(-36, 0, 35), Vector3(225, 0, -112), Vector3(-225, 0, -205)]
	for center in park_centers:
		var lawn := MeshInstance3D.new()
		var lawn_mesh := BoxMesh.new()
		lawn_mesh.size = Vector3(42, 0.12, 34)
		lawn_mesh.material = _material(Color("#536d4c"), 1.0)
		lawn.mesh = lawn_mesh
		lawn.position = center + Vector3(0, 0.02, 0)
		add_child(lawn)
		for i in range(12):
			var p := Vector3(center.x + rng.randf_range(-17, 17), 0, center.z + rng.randf_range(-13, 13))
			_create_tree(p, rng.randf_range(0.72, 1.15))
		for i in range(6):
			var path := MeshInstance3D.new()
			var path_mesh := BoxMesh.new()
			path_mesh.size = Vector3(1.5, 0.06, 12.0)
			path_mesh.material = _material(Color("#a59d8d"), 0.96)
			path.mesh = path_mesh
			path.position = center + Vector3(rng.randf_range(-16, 16), 0.11, rng.randf_range(-12, 12))
			path.rotation.y = rng.randf_range(-0.6, 0.6)
			add_child(path)

func _build_street_furniture() -> void:
	for point in _road_loop:
		if rng.randf() > 0.38:
			var offset := Vector3(rng.randf_range(-9, 9), 0, rng.randf_range(-9, 9))
			_create_streetlight(point + offset)
	_create_bus_stop(Vector3(-70, 0, -83), 0.2)
	_create_bus_stop(Vector3(152, 0, 47), -0.45)
	_create_fuel_station(Vector3(240, 0, -165))
	_create_car_wash(Vector3(-235, 0, -120))

func _create_tree(pos: Vector3, scale_value: float) -> Node3D:
	var tree := Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE * scale_value
	add_child(tree)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 2.2
	trunk_mesh.material = _material(Color("#59422f"), 1.0)
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.1
	tree.add_child(trunk)
	var foliage := MeshInstance3D.new()
	var foliage_mesh := SphereMesh.new()
	foliage_mesh.radius = 1.2
	foliage_mesh.height = 2.2
	foliage_mesh.material = _material([Color("#466b46"), Color("#56784b"), Color("#3e6248")][rng.randi_range(0, 2)], 1.0)
	foliage.mesh = foliage_mesh
	foliage.position.y = 2.55
	tree.add_child(foliage)
	return tree

func _create_streetlight(pos: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.055
	pole_mesh.bottom_radius = 0.085
	pole_mesh.height = 6.6
	pole_mesh.material = _material(Color("#42494c"), 0.55, 0.5)
	pole.mesh = pole_mesh
	pole.position = pos + Vector3(0, 3.3, 0)
	add_child(pole)
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(1.05, 0.08, 0.08)
	arm_mesh.material = pole_mesh.material
	arm.mesh = arm_mesh
	arm.position = pos + Vector3(0.42, 6.5, 0)
	add_child(arm)
	var lamp := OmniLight3D.new()
	lamp.position = pos + Vector3(0.82, 6.3, 0)
	lamp.light_energy = 0.55
	lamp.omni_range = 9.0
	lamp.visible = false
	add_child(lamp)
	_street_lamps.append(lamp)

func _create_bus_stop(pos: Vector3, yaw: float) -> void:
	var stop := Node3D.new()
	stop.position = pos
	stop.rotation.y = yaw
	add_child(stop)
	_add_local_box(stop, "ShelterFloor", Vector3(5.2, 0.15, 2.0), Vector3(0, 0.18, 0), _material(Color("#85847e")))
	_add_local_box(stop, "ShelterRoof", Vector3(5.2, 0.18, 2.0), Vector3(0, 2.65, 0), _material(Color("#46545b"), 0.6, 0.3))
	_add_local_box(stop, "GlassBack", Vector3(5.0, 2.25, 0.06), Vector3(0, 1.4, 0.88), _material(Color(0.35, 0.55, 0.65, 0.42), 0.2))
	_add_local_box(stop, "Bench", Vector3(2.8, 0.16, 0.45), Vector3(0, 0.7, 0.3), _material(Color("#51473c")))
	var sign := Label3D.new()
	sign.text = "АВТОБУС"
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.position = Vector3(0, 2.2, -1.05)
	stop.add_child(sign)

func _create_fuel_station(pos: Vector3) -> void:
	var station := Node3D.new()
	station.position = pos
	add_child(station)
	_add_local_box(station, "FuelShop", Vector3(17, 4.5, 10), Vector3(0, 2.25, -7), _material(Color("#d1d0c4")))
	_add_local_box(station, "Canopy", Vector3(19, 0.5, 11), Vector3(0, 5.2, 1), _material(Color("#c64a3e"), 0.55))
	for x in [-5.5, 0.0, 5.5]:
		_add_local_box(station, "Pump", Vector3(1.15, 1.7, 1.0), Vector3(x, 1.0, 1.0), _material(Color("#e5e6df"), 0.5))
		_add_local_box(station, "PumpScreen", Vector3(0.8, 0.42, 0.06), Vector3(x, 1.35, 0.49), _material(Color("#243c45"), 0.2))
	var sign := Label3D.new()
	sign.text = "АЗС  •  FUEL"
	sign.font_size = 50
	sign.pixel_size = 0.004
	sign.position = Vector3(0, 6.2, -12.2)
	station.add_child(sign)

func _create_car_wash(pos: Vector3) -> void:
	var wash := Node3D.new()
	wash.position = pos
	add_child(wash)
	_add_local_box(wash, "WashBuilding", Vector3(12, 4, 8), Vector3(0, 2, 0), _material(Color("#9ca6a7")))
	_add_local_box(wash, "WashOpening", Vector3(7, 3, 0.12), Vector3(0, 1.8, -4.1), _material(Color("#263944")))
	_add_local_box(wash, "WashSign", Vector3(7, 0.5, 0.22), Vector3(0, 4.15, -4.1), _material(Color("#275e7d")))

func _add_local_box(parent: Node3D, label: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	item.mesh = mesh
	item.position = pos
	parent.add_child(item)

func _spawn_player() -> void:
	player_car = PlayerCarScript.new()
	player_car.name = "Player_Chevrolet_Cobalt_Prototype"
	player_car.position = Vector3(-53, 0.9, -65)
	add_child(player_car)
	var saved_plate := str(SaveGame.get_value("plate", "777XAH02"))
	player_car.call("set_plate", saved_plate)

func _spawn_traffic() -> void:
	var colors: Array[Color] = [Color("#f0eee8"), Color("#1d252b"), Color("#6f2425"), Color("#8d9699"), Color("#244b62"), Color("#c2a76c"), Color("#46634d"), Color("#e1e1dc")]
	var types: Array[String] = ["sedan", "sedan", "taxi", "bus", "truck", "sedan", "police", "minivan"]
	for i in range(8):
		var traffic: TrafficCar = TrafficCarScript.new()
		traffic.name = "Traffic_%02d" % i
		traffic.route = _road_loop.duplicate()
		traffic.target_index = (i * maxi(1, int(_road_loop.size() / 8.0))) % _road_loop.size()
		traffic.cruise_speed = rng.randf_range(7.0, 13.0) if types[i] != "bus" and types[i] != "truck" else rng.randf_range(5.0, 8.0)
		traffic.vehicle_kind = types[i]
		traffic.paint_color = colors[i]
		traffic.position = _road_loop[traffic.target_index] + Vector3(0, 0.2, 0)
		add_child(traffic)
	for i in range(5):
		var parked: TrafficCar = TrafficCarScript.new()
		parked.name = "ParkedCar_%02d" % i
		parked.vehicle_kind = "sedan"
		parked.paint_color = colors[(i + 2) % colors.size()]
		parked.position = Vector3(-205 + i * 5.2, 0.15, 145)
		add_child(parked)

func _build_hud() -> void:
	hud = HUDScript.new()
	hud.name = "GameHUD"
	add_child(hud)
	hud.bind_player(player_car)
	hud.bind_world(self)

func _build_camera() -> void:
	follow_camera = Camera3D.new()
	follow_camera.name = "ChaseCamera"
	follow_camera.current = true
	follow_camera.fov = 72.0
	follow_camera.position = Vector3(0, 4, 8)
	add_child(follow_camera)
	_update_camera(1.0)


func begin_delivery() -> void:
	if _delivery_active:
		hud.set_status("Доставка уже активна. Едь к жёлтой метке на карте.")
		return
	_delivery_active = true
	_delivery_marker = Node3D.new()
	_delivery_marker.name = "DeliveryDestination"
	_delivery_marker.position = _delivery_target
	add_child(_delivery_marker)
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 4.2
	ring_mesh.bottom_radius = 4.2
	ring_mesh.height = 0.12
	ring_mesh.radial_segments = 32
	var ring_mat := _material(Color("#f6c542"), 0.42, 0.2)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color("#8f6414")
	ring_mesh.material = ring_mat
	ring.mesh = ring_mesh
	ring.position.y = 0.1
	_delivery_marker.add_child(ring)
	var beacon := OmniLight3D.new()
	beacon.position.y = 3.5
	beacon.light_color = Color("#ffc83d")
	beacon.light_energy = 2.0
	beacon.omni_range = 8.0
	_delivery_marker.add_child(beacon)
	var marker_label := Label3D.new()
	marker_label.text = "ДОСТАВКА"
	marker_label.font_size = 42
	marker_label.pixel_size = 0.004
	marker_label.position.y = 5.0
	_delivery_marker.add_child(marker_label)
	hud.set_status("Доставка начата: доберись до жёлтой метки и получи 1 500 ₸.")

func _update_delivery() -> void:
	if not _delivery_active or player_car == null:
		return
	if player_car.global_position.distance_to(_delivery_target) < 10.0:
		_delivery_active = false
		if is_instance_valid(_delivery_marker):
			_delivery_marker.queue_free()
		var balance := int(SaveGame.get_value("money", 20000)) + 1500
		SaveGame.set_value("money", balance)
		hud.set_money_balance(balance)
		hud.set_status("Доставка завершена. Начислено +1 500 ₸.")

func cycle_camera() -> void:
	camera_mode = (camera_mode + 1) % 4
	SaveGame.set_value("camera_mode", camera_mode)
	if hud != null:
		var names := ["КАМЕРА: СЗАДИ", "КАМЕРА: КАПОТ", "КАМЕРА: САЛОН", "КАМЕРА: СВЕРХУ"]
		hud.set_status(names[camera_mode])

func _update_camera(delta: float) -> void:
	if player_car == null or follow_camera == null:
		return
	var local_offset := Vector3(0, 4.2, 8.5)
	var look_offset := Vector3(0, 0.7, 0)
	match camera_mode:
		1:
			local_offset = Vector3(0, 1.05, -1.7)
			look_offset = Vector3(0, 0.8, -12.0)
		2:
			local_offset = Vector3(0, 1.25, 0.18)
			look_offset = Vector3(0, 1.1, -18.0)
		3:
			local_offset = Vector3(0, 14.0, 0.1)
			look_offset = Vector3(0, 0, -1.0)
	var target_position := player_car.global_transform * local_offset
	var target_look := player_car.global_transform * look_offset
	follow_camera.global_position = follow_camera.global_position.lerp(target_position, minf(delta * 5.0, 1.0))
	follow_camera.look_at(target_look, Vector3.UP)

func _update_daylight() -> void:
	if _sun == null:
		return
	var angle := _day_clock * TAU
	_sun.rotation.x = -0.25 - sin(angle) * 0.72
	_sun.rotation.y = -0.5 + cos(angle) * 0.75
	_sun.light_energy = clampf(0.18 + maxf(0.0, sin(angle)) * 1.25, 0.08, 1.35)
	var night := _sun.light_energy < 0.35
	for lamp in _street_lamps:
		lamp.visible = night

func _material(color: Color, roughness: float = 0.75, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
