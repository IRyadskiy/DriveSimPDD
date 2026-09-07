class_name TrainingCar
extends CharacterBody3D

signal state_changed
signal speed_changed(kmh: float)

const LENGTH := 4.405
const WIDTH := 1.729
const HEIGHT := 1.469
const WHEEL_BASE := 2.600
const MAX_SPEED := 18.0

var engine_on := false
var seat_belt_on := false
var drl_on := false
var handbrake_on := true
var left_signal := false
var right_signal := false
var hazards_on := false
var speed := 0.0
var steering := 0.0
var start_transform := Transform3D.IDENTITY
var blink_time := 0.0
var blink_visible := false
var front_lights: Array[MeshInstance3D] = []
var left_lights: Array[MeshInstance3D] = []
var right_lights: Array[MeshInstance3D] = []

func _ready() -> void:
	start_transform = global_transform
	_build_car()

func _physics_process(delta: float) -> void:
	_handle_switches()
	_drive(delta)
	_update_lights(delta)

func _handle_switches() -> void:
	if Input.is_action_just_pressed("toggle_engine"):
		engine_on = not engine_on; state_changed.emit()
	if Input.is_action_just_pressed("toggle_belt"):
		seat_belt_on = not seat_belt_on; state_changed.emit()
	if Input.is_action_just_pressed("toggle_drl"):
		drl_on = not drl_on; state_changed.emit()
	if Input.is_action_just_pressed("toggle_handbrake"):
		handbrake_on = not handbrake_on; state_changed.emit()
	if Input.is_action_just_pressed("left_indicator"):
		left_signal = not left_signal; right_signal = false; hazards_on = false; state_changed.emit()
	if Input.is_action_just_pressed("right_indicator"):
		right_signal = not right_signal; left_signal = false; hazards_on = false; state_changed.emit()
	if Input.is_action_just_pressed("hazard"):
		hazards_on = not hazards_on; left_signal = false; right_signal = false; state_changed.emit()
	if Input.is_action_just_pressed("reset_car"):
		global_transform = start_transform; speed = 0.0; velocity = Vector3.ZERO

func _drive(delta: float) -> void:
	var throttle := Input.get_axis("brake_reverse", "accelerate")
	steering = move_toward(steering, Input.get_axis("steer_right", "steer_left"), delta * 3.0)
	if not engine_on or handbrake_on:
		speed = move_toward(speed, 0.0, delta * 8.0)
	elif throttle > 0.0:
		speed = move_toward(speed, MAX_SPEED * throttle, delta * 4.2)
	elif throttle < 0.0:
		speed = move_toward(speed, -5.0, delta * (8.0 if speed > 0.5 else 3.0))
	else:
		speed = move_toward(speed, 0.0, delta * 1.25)
	if abs(speed) > 0.08:
		rotate_y(steering * speed / WHEEL_BASE * 0.42 * delta)
	velocity = -global_transform.basis.z * speed
	velocity.y = -0.5
	move_and_slide()
	speed_changed.emit(abs(speed) * 3.6)

func _update_lights(delta: float) -> void:
	for lamp in front_lights: lamp.visible = drl_on
	blink_time += delta
	if blink_time >= 0.45:
		blink_time = 0.0; blink_visible = not blink_visible
	for lamp in left_lights: lamp.visible = blink_visible and (left_signal or hazards_on)
	for lamp in right_lights: lamp.visible = blink_visible and (right_signal or hazards_on)

func _build_car() -> void:
	var body_mat := _material(Color("d9dde3"), 0.22, 0.55)
	var glass_mat := _material(Color("111c25"), 0.08, 0.15)
	var lamp_mat := _emissive(Color("c7eeff"))
	var turn_mat := _emissive(Color("ff7b00"))
	_add_box(Vector3(WIDTH, 0.54, LENGTH), Vector3(0, 0.62, 0), body_mat)
	_add_box(Vector3(1.52, 0.60, 2.16), Vector3(0, 1.12, 0.12), glass_mat)
	_add_box(Vector3(1.42, 0.12, 1.65), Vector3(0, 1.45, 0.10), body_mat)
	_add_box(Vector3(1.62, 0.14, 1.05), Vector3(0, 0.96, -1.55), body_mat)
	_add_box(Vector3(1.58, 0.16, 0.72), Vector3(0, 0.96, 1.74), body_mat)
	for x in [-0.82, 0.82]:
		for z in [-WHEEL_BASE * 0.5, WHEEL_BASE * 0.5]: _add_wheel(Vector3(x, 0.42, z))
	for x in [-0.57, 0.57]: front_lights.append(_add_box(Vector3(0.38, 0.12, 0.05), Vector3(x, 0.75, -2.225), lamp_mat))
	left_lights.append(_add_box(Vector3(0.16, 0.10, 0.055), Vector3(-0.75, 0.72, -2.23), turn_mat))
	right_lights.append(_add_box(Vector3(0.16, 0.10, 0.055), Vector3(0.75, 0.72, -2.23), turn_mat))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(WIDTH, HEIGHT, LENGTH)
	collision.shape = shape; collision.position.y = HEIGHT * 0.5; add_child(collision)

func _add_box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new(); var mesh := BoxMesh.new()
	mesh.size = size; mesh.material = material; item.mesh = mesh; item.position = pos; add_child(item)
	return item

func _add_wheel(pos: Vector3) -> void:
	var item := MeshInstance3D.new(); var mesh := CylinderMesh.new()
	mesh.top_radius = 0.31; mesh.bottom_radius = 0.31; mesh.height = 0.18; mesh.radial_segments = 24
	mesh.material = _material(Color("17191c"), 0.05, 0.85)
	item.mesh = mesh; item.position = pos; item.rotation_degrees.z = 90.0; add_child(item)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.metallic = metallic; mat.roughness = roughness
	return mat

func _emissive(color: Color) -> StandardMaterial3D:
	var mat := _material(color, 0.0, 0.15); mat.emission_enabled = true; mat.emission = color; mat.emission_energy_multiplier = 4.0
	return mat

