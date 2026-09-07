extends Node3D

var car: TrainingCar
var camera: Camera3D
var exterior_camera := false
var look_yaw := 0.0
var look_pitch := 0.0
var mirror_cameras: Array[Camera3D] = []
var task_label: Label
var status_label: Label
var speed_label: Label
var gear_label: Label
var left_arrow: Label
var right_arrow: Label
var tasks := ["Заведите двигатель — E", "Пристегните ремень — B", "Снимите ручник — Space", "Включите ДХО — L", "Переведите АКПП в D — клавиша 4", "Начните движение — W", "Покиньте учебную парковку"]
var task_done := [false, false, false, false, false, false, false]

func _ready() -> void:
	_build_world()
	_build_hud()
	car.state_changed.connect(_update_hud)
	car.speed_changed.connect(func(kmh: float): speed_label.text = "%d км/ч" % roundi(kmh))
	_update_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not exterior_camera and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_yaw = clamp(look_yaw - event.relative.x * 0.0022, -1.75, 1.75)
		look_pitch = clamp(look_pitch - event.relative.y * 0.0018, -0.35, 0.30)
	if event.is_action_pressed("reset_car"):
		task_done.fill(false)
		look_yaw = 0.0
		look_pitch = 0.0
	if event.is_action_pressed("toggle_camera"):
		exterior_camera = not exterior_camera
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_delta: float) -> void:
	if exterior_camera:
		var desired := car.global_position + car.global_transform.basis * Vector3(0, 3.4, 7.2)
		camera.global_position = camera.global_position.lerp(desired, 0.075)
		camera.look_at(car.global_position + Vector3.UP * 0.9)
	else:
		camera.global_transform = car.global_transform * Transform3D(Basis.from_euler(Vector3(look_pitch, look_yaw, 0)), Vector3(-0.38, 1.23, 0.24))
	_update_mirrors()
	_update_hud()

func _build_world() -> void:
	var world := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("9ac6e8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color.WHITE; env.ambient_light_energy = 0.72
	world.environment = env; add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-52, -28, 0); sun.shadow_enabled = true; add_child(sun)
	_static_box(Vector3(28, 0.25, 32), Vector3(0, -0.15, 0), Color("30343a"))
	_static_box(Vector3(12, 0.22, 90), Vector3(0, -0.14, -52), Color("282b30"))
	_static_box(Vector3(34, 0.18, 120), Vector3(-23, -0.16, -38), Color("5d8b50"))
	_static_box(Vector3(34, 0.18, 120), Vector3(23, -0.16, -38), Color("5d8b50"))
	for x in [-9.0, -3.0, 3.0, 9.0]: _mark(Vector3(x, 0.015, 2), Vector3(0.09, 0.025, 8.0))
	for z in range(-94, -12, 8): _mark(Vector3(0, 0.015, float(z)), Vector3(0.14, 0.025, 4.0))
	_mark(Vector3(0, 0.02, -9), Vector3(12.0, 0.03, 0.18))
	car = TrainingCar.new(); car.name = "HyundaiSolarisTrainingCar"; car.position = Vector3(-6, 0, 4); add_child(car)
	camera = Camera3D.new(); camera.current = true; camera.fov = 72; camera.near = 0.025; add_child(camera)

func _build_hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var panel := ColorRect.new(); panel.color = Color(0.035, 0.055, 0.085, 0.78); panel.position = Vector2(18, 548); panel.size = Vector2(450, 154); layer.add_child(panel)
	_label(layer, Vector2(34, 556), 16, "АВТОШКОЛА • УЧЕБНАЯ ПАРКОВКА")
	task_label = _label(layer, Vector2(34, 584), 16, ""); task_label.size = Vector2(415, 40); task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label = _label(layer, Vector2(34, 625), 13, "")
	speed_label = _label(layer, Vector2(575, 650), 28, "0 км/ч")
	gear_label = _label(layer, Vector2(735, 650), 28, "D")
	_label(layer, Vector2(850, 681), 12, "1/2/3/4 — P/R/N/D  •  C — вид  •  мышь — обзор")
	left_arrow = _label(layer, Vector2(550, 601), 34, "◀")
	right_arrow = _label(layer, Vector2(740, 601), 34, "▶")
	_label(layer, Vector2(500, 570), 14, "Z — левый    X — правый    H — аварийка")
	# Центральное зеркало сверху; боковые — около краёв дверей.
	_build_mirror(layer, Vector2(14, 235), Vector2(205, 92), Vector3(-0.80, 1.22, -0.18), Vector3(-0.50, -0.03, 1))
	_build_mirror(layer, Vector2(500, 18), Vector2(280, 82), Vector3(0, 1.38, 0.45), Vector3(0, -0.02, 1))
	_build_mirror(layer, Vector2(1061, 235), Vector2(205, 92), Vector3(0.80, 1.22, -0.18), Vector3(0.50, -0.03, 1))

func _update_hud() -> void:
	left_arrow.modulate = Color("57ff78") if car.blink_visible and (car.left_signal or car.hazards_on) else Color("344039")
	right_arrow.modulate = Color("57ff78") if car.blink_visible and (car.right_signal or car.hazards_on) else Color("344039")
	var current := [car.engine_on, car.seat_belt_on, not car.handbrake_on, car.drl_on, car.gear == "D", abs(car.speed) > 0.7, car.global_position.z < -11]
	for i in task_done.size():
		task_done[i] = task_done[i] or current[i]
	var next := task_done.find(false)
	task_label.text = "Задание выполнено!" if next == -1 else "Шаг %d/7: %s" % [next + 1, tasks[next]]
	status_label.text = "АКПП: %s   Двигатель: %s   Ремень: %s\nРучник: %s   ДХО: %s   Сигналы: %s" % [car.gear, _on(car.engine_on), _on(car.seat_belt_on), _on(car.handbrake_on), _on(car.drl_on), _signals()]
	gear_label.text = "АКПП  %s" % car.gear

func _build_mirror(layer: CanvasLayer, pos: Vector2, size: Vector2, local_pos: Vector3, local_direction: Vector3) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(size.x), int(size.y))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = get_viewport().world_3d
	add_child(viewport)
	var mirror_camera := Camera3D.new()
	mirror_camera.fov = 58
	mirror_camera.set_meta("local_pos", local_pos)
	mirror_camera.set_meta("local_direction", local_direction.normalized())
	viewport.add_child(mirror_camera)
	mirror_cameras.append(mirror_camera)
	var frame := ColorRect.new(); frame.color = Color("151a20"); frame.position = pos - Vector2(4, 4); frame.size = size + Vector2(8, 8); layer.add_child(frame)
	var view := TextureRect.new(); view.position = pos; view.size = size; view.texture = viewport.get_texture(); view.flip_h = true; view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; layer.add_child(view)

func _update_mirrors() -> void:
	for mirror_camera in mirror_cameras:
		var local_pos: Vector3 = mirror_camera.get_meta("local_pos")
		var local_direction: Vector3 = mirror_camera.get_meta("local_direction")
		var origin := car.global_transform * local_pos
		var direction := car.global_basis * local_direction
		mirror_camera.look_at_from_position(origin, origin + direction, car.global_basis.y)

func _signals() -> String:
	if car.hazards_on: return "аварийка"
	if car.left_signal: return "левый"
	if car.right_signal: return "правый"
	return "выкл"

func _on(value: bool) -> String: return "ВКЛ" if value else "выкл"

func _label(layer: CanvasLayer, pos: Vector2, size: int, text: String) -> Label:
	var label := Label.new(); label.position = pos; label.text = text; label.add_theme_font_size_override("font_size", size); layer.add_child(label); return label

func _static_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new(); body.position = pos; body.add_child(_box(size, color))
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; body.add_child(collision); add_child(body)

func _mark(pos: Vector3, size: Vector3) -> void:
	var item := _box(size, Color("f4f4e9")); item.position = pos; add_child(item)

func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new(); var mesh := BoxMesh.new(); var mat := StandardMaterial3D.new()
	mat.albedo_color = color; mat.roughness = 0.82; mesh.size = size; mesh.material = mat; item.mesh = mesh; return item
