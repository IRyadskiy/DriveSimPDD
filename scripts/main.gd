extends Node3D

var car: TrainingCar
var camera: Camera3D
var task_label: Label
var status_label: Label
var speed_label: Label
var tasks := ["Заведите двигатель — E", "Пристегните ремень — B", "Снимите ручник — Space", "Включите ДХО — L", "Начните движение — W", "Покиньте учебную парковку"]
var task_done := [false, false, false, false, false, false]

func _ready() -> void:
	_build_world()
	_build_hud()
	car.state_changed.connect(_update_hud)
	car.speed_changed.connect(func(kmh: float): speed_label.text = "%d км/ч" % roundi(kmh))
	_update_hud()

func _process(_delta: float) -> void:
	var desired := car.global_position + car.global_transform.basis * Vector3(0, 3.4, 7.2)
	camera.global_position = camera.global_position.lerp(desired, 0.075)
	camera.look_at(car.global_position + Vector3.UP * 0.9)
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
	camera = Camera3D.new(); camera.current = true; camera.fov = 66; camera.position = Vector3(-6, 3.5, 11); add_child(camera)

func _build_hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var panel := ColorRect.new(); panel.color = Color(0.035, 0.055, 0.085, 0.90); panel.position = Vector2(24, 24); panel.size = Vector2(430, 230); layer.add_child(panel)
	_label(layer, Vector2(46, 40), 24, "АВТОШКОЛА • УЧЕБНАЯ ПАРКОВКА")
	task_label = _label(layer, Vector2(46, 82), 20, ""); task_label.size = Vector2(390, 55); task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label = _label(layer, Vector2(46, 145), 16, "")
	speed_label = _label(layer, Vector2(46, 208), 20, "0 км/ч")
	_label(layer, Vector2(480, 28), 16, "W/S — газ/тормоз  •  A/D — руль  •  Z/X — поворотники  •  H — аварийка  •  R — сброс")

func _update_hud() -> void:
	var current := [car.engine_on, car.seat_belt_on, not car.handbrake_on, car.drl_on, abs(car.speed) > 0.7, car.global_position.z < -11]
	for i in task_done.size():
		task_done[i] = task_done[i] or current[i]
	var next := task_done.find(false)
	task_label.text = "Задание выполнено!" if next == -1 else "Шаг %d/6: %s" % [next + 1, tasks[next]]
	status_label.text = "Двигатель: %s   Ремень: %s\nРучник: %s   ДХО: %s\nСигналы: %s" % [_on(car.engine_on), _on(car.seat_belt_on), _on(car.handbrake_on), _on(car.drl_on), _signals()]

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
