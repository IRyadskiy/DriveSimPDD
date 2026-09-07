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
var gear := "P"
var speed := 0.0
var steering := 0.0
var start_transform := Transform3D.IDENTITY
var blink_time := 0.0
var blink_visible := false
var front_lights: Array[MeshInstance3D] = []
var left_lights: Array[MeshInstance3D] = []
var right_lights: Array[MeshInstance3D] = []
var steering_wheel: Node3D
var front_wheel_pivots: Array[Node3D] = []
var cancel_armed := false
var indicator_audio: AudioStreamPlayer
var brake_lights: Array[MeshInstance3D] = []
var reverse_lights: Array[MeshInstance3D] = []

func _ready() -> void:
	start_transform = global_transform
	_build_car()
	_build_indicator_audio()
	floor_snap_length = 0.25

func _physics_process(delta: float) -> void:
	_handle_switches()
	_drive(delta)
	_update_lights(delta)

func _handle_switches() -> void:
	if Input.is_action_just_pressed("toggle_engine"):
		if engine_on:
			engine_on = false; state_changed.emit()
		elif gear == "P" or gear == "N":
			engine_on = true; state_changed.emit()
	if Input.is_action_just_pressed("toggle_belt"):
		seat_belt_on = not seat_belt_on; state_changed.emit()
	if Input.is_action_just_pressed("toggle_drl"):
		drl_on = not drl_on; state_changed.emit()
	if Input.is_action_just_pressed("toggle_handbrake"):
		handbrake_on = not handbrake_on; state_changed.emit()
	if Input.is_action_just_pressed("left_indicator"):
		left_signal = not left_signal; right_signal = false; hazards_on = false; _restart_blink(); state_changed.emit()
	if Input.is_action_just_pressed("right_indicator"):
		right_signal = not right_signal; left_signal = false; hazards_on = false; _restart_blink(); state_changed.emit()
	if Input.is_action_just_pressed("hazard"):
		hazards_on = not hazards_on; left_signal = false; right_signal = false; _restart_blink(); state_changed.emit()
	if Input.is_action_just_pressed("gear_p") and abs(speed) < 0.3:
		gear = "P"; state_changed.emit()
	if Input.is_action_just_pressed("gear_r") and abs(speed) < 0.3:
		gear = "R"; state_changed.emit()
	if Input.is_action_just_pressed("gear_n"):
		gear = "N"; state_changed.emit()
	if Input.is_action_just_pressed("gear_d") and abs(speed) < 0.3:
		gear = "D"; state_changed.emit()
	if Input.is_action_just_pressed("reset_car"):
		reset_vehicle()

func reset_vehicle() -> void:
	global_transform = start_transform
	speed = 0.0
	velocity = Vector3.ZERO
	steering = 0.0
	gear = "P"
	handbrake_on = true
	engine_on = false
	seat_belt_on = false
	drl_on = false
	left_signal = false
	right_signal = false
	hazards_on = false
	cancel_armed = false
	blink_visible = false
	state_changed.emit()

func _drive(delta: float) -> void:
	var throttle: float = Input.get_action_strength("accelerate")
	var brake: float = Input.get_action_strength("brake_reverse")
	var steer_input: float = Input.get_axis("steer_right", "steer_left")
	var steer_rate: float = 1.4 if absf(steer_input) > 0.01 else 1.0 + absf(speed) * 0.09
	steering = move_toward(steering, steer_input, delta * steer_rate)
	var drag: float = 0.16 + speed * speed * 0.003
	if handbrake_on or gear == "P":
		speed = move_toward(speed, 0.0, delta * 12.0)
	elif brake > 0.0:
		speed = move_toward(speed, 0.0, delta * (9.0 * brake + drag))
	elif engine_on and (gear == "D" or gear == "R"):
		var direction: float = 1.0 if gear == "D" else -1.0
		var limit: float = MAX_SPEED if gear == "D" else 5.0
		if throttle > 0.0:
			speed = move_toward(speed, direction * limit, delta * 3.2 * throttle)
		else:
			# Automatic transmission creep; brake always wins over throttle.
			speed = move_toward(speed, direction * 1.1, delta * (0.65 + drag))
	else:
		# Neutral and engine-off coast instead of applying an invisible brake.
		speed = move_toward(speed, 0.0, delta * drag)
	var road_angle: float = steering * deg_to_rad(32.0) / (1.0 + absf(speed) * 0.055)
	if is_on_floor():
		rotate_y(speed / WHEEL_BASE * tan(road_angle) * delta)
	var vertical_speed: float = velocity.y - 9.81 * delta
	if is_on_floor():
		vertical_speed = -0.1
	velocity = -global_basis.z * speed
	velocity.y = vertical_speed
	move_and_slide()
	if is_on_wall():
		speed = velocity.dot(-global_basis.z)
	steering_wheel.rotation.z = steering * deg_to_rad(450.0)
	for pivot in front_wheel_pivots:
		pivot.rotation.y = road_angle
	_update_indicator_cancel()
	speed_changed.emit(get_real_velocity().length() * 3.6)
	if global_position.y < -12.0:
		reset_vehicle()

func _update_indicator_cancel() -> void:
	if hazards_on or not (left_signal or right_signal):
		cancel_armed = false
		return
	if absf(speed) > 0.3:
		if (left_signal and steering > 0.35) or (right_signal and steering < -0.35):
			cancel_armed = true
	if cancel_armed and absf(steering) < 0.08:
		left_signal = false
		right_signal = false
		cancel_armed = false
		state_changed.emit()

func _restart_blink() -> void:
	cancel_armed = false
	blink_time = 0.45
	blink_visible = false

func _build_indicator_audio() -> void:
	indicator_audio = AudioStreamPlayer.new()
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_8_BITS
	wave.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(1323)
	for i in samples.size():
		var envelope: float = exp(-float(i) / 210.0)
		var sample: int = roundi(sin(float(i) * TAU * 1600.0 / 22050.0) * 75.0 * envelope)
		samples[i] = sample & 255
	wave.data = samples
	indicator_audio.stream = wave
	indicator_audio.volume_db = -16.0
	add_child(indicator_audio)

func _update_lights(delta: float) -> void:
	for lamp in front_lights: lamp.visible = drl_on
	var active: bool = left_signal or right_signal or hazards_on
	if active:
		blink_time += delta
		if blink_time >= 0.45:
			blink_time = 0.0
			blink_visible = not blink_visible
			indicator_audio.pitch_scale = 1.0 if blink_visible else 0.8
			indicator_audio.play()
	else:
		blink_visible = false
		blink_time = 0.0
	for lamp in left_lights: lamp.visible = blink_visible and (left_signal or hazards_on)
	for lamp in right_lights: lamp.visible = blink_visible and (right_signal or hazards_on)
	for lamp in brake_lights: lamp.visible = Input.is_action_pressed("brake_reverse")
	for lamp in reverse_lights: lamp.visible = engine_on and gear == "R"

func _build_car() -> void:
	var body_mat := _material(Color("d9dde3"), 0.22, 0.55)
	var lamp_mat := _emissive(Color("c7eeff"))
	var turn_mat := _emissive(Color("ff7b00"))
	_add_box(Vector3(WIDTH, 0.54, LENGTH), Vector3(0, 0.62, 0), body_mat)
	_add_box(Vector3(1.42, 0.06, 1.28), Vector3(0, 1.50, 0.46), body_mat)
	_add_box(Vector3(1.62, 0.14, 1.05), Vector3(0, 0.96, -1.55), body_mat)
	_add_box(Vector3(1.58, 0.16, 0.72), Vector3(0, 0.96, 1.74), body_mat)
	_build_cockpit()
	for x in [-0.82, 0.82]:
		for z in [-WHEEL_BASE * 0.5, WHEEL_BASE * 0.5]: _add_wheel(Vector3(x, 0.42, z))
	for x in [-0.57, 0.57]: front_lights.append(_add_box(Vector3(0.38, 0.12, 0.05), Vector3(x, 0.75, -2.225), lamp_mat))
	left_lights.append(_add_box(Vector3(0.16, 0.10, 0.055), Vector3(-0.75, 0.72, -2.23), turn_mat))
	right_lights.append(_add_box(Vector3(0.16, 0.10, 0.055), Vector3(0.75, 0.72, -2.23), turn_mat))
	for x in [-0.70, 0.70]:
		var lamps: Array[MeshInstance3D] = left_lights if x < 0.0 else right_lights
		lamps.append(_add_box(Vector3(0.13, 0.10, 0.055), Vector3(x, 0.72, 2.23), turn_mat))
		lamps.append(_add_box(Vector3(0.04, 0.055, 0.13), Vector3(signf(x) * 0.87, 0.83, -0.65), turn_mat))
		brake_lights.append(_add_box(Vector3(0.22, 0.12, 0.055), Vector3(x * 0.7, 0.73, 2.23), _emissive(Color("ff2010"))))
		reverse_lights.append(_add_box(Vector3(0.10, 0.08, 0.055), Vector3(x * 0.4, 0.73, 2.23), lamp_mat))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(WIDTH, HEIGHT, LENGTH)
	collision.shape = shape; collision.position.y = HEIGHT * 0.5; add_child(collision)

func _build_cockpit() -> void:
	var dark := _material(Color("171b20"), 0.02, 0.72)
	var trim := _material(Color("2b3036"), 0.03, 0.58)
	var seat_mat := _material(Color("242a31"), 0.0, 0.92)
	# Низкая панель оставляет открытым лобовое стекло и линию дороги.
	_add_box(Vector3(1.48, 0.14, 0.48), Vector3(0, 0.83, -0.72), dark)
	_add_box_rotated(Vector3(1.46, 0.08, 0.34), Vector3(0, 0.91, -0.68), Vector3(-8, 0, 0), trim)
	# Лобовые стойки и верхняя кромка крыши задают настоящий проём стекла.
	_add_box_rotated(Vector3(0.075, 0.92, 0.09), Vector3(-0.76, 1.19, -0.82), Vector3(-28, 0, -5), dark)
	_add_box_rotated(Vector3(0.075, 0.92, 0.09), Vector3(0.76, 1.19, -0.82), Vector3(-28, 0, 5), dark)
	_add_box(Vector3(1.40, 0.08, 0.10), Vector3(0, 1.50, -0.20), dark)
	# Центральная консоль, тоннель и приборный щиток.
	_add_box(Vector3(0.30, 0.38, 0.34), Vector3(0.12, 0.69, -0.59), trim)
	_add_box(Vector3(0.24, 0.13, 0.72), Vector3(0.0, 0.52, 0.05), trim)
	_add_box(Vector3(0.50, 0.16, 0.12), Vector3(-0.39, 0.96, -0.72), dark)
	_add_instrument(Vector3(-0.50, 0.96, -0.648))
	_add_instrument(Vector3(-0.29, 0.96, -0.648))
	_add_box(Vector3(0.52, 0.12, 0.62), Vector3(-0.39, 0.54, 0.33), seat_mat)
	_add_box(Vector3(0.52, 0.12, 0.62), Vector3(0.39, 0.54, 0.33), seat_mat)
	_add_box(Vector3(0.52, 0.72, 0.12), Vector3(-0.39, 0.88, 0.60), seat_mat)
	_add_box(Vector3(0.52, 0.72, 0.12), Vector3(0.39, 0.88, 0.60), seat_mat)
	# Tilt is on the parent; wheel, hub and spokes rotate on one local shaft.
	var shaft := Node3D.new()
	shaft.position = Vector3(-0.40, 0.98, -0.39)
	shaft.rotation_degrees.x = -12.0
	add_child(shaft)
	steering_wheel = Node3D.new()
	shaft.add_child(steering_wheel)
	var rim := MeshInstance3D.new()
	var wheel_mesh := TorusMesh.new()
	wheel_mesh.inner_radius = 0.158
	wheel_mesh.outer_radius = 0.188
	wheel_mesh.rings = 48
	wheel_mesh.ring_segments = 12
	wheel_mesh.material = dark
	rim.mesh = wheel_mesh
	rim.rotation_degrees.x = 90.0
	steering_wheel.add_child(rim)
	for spec in [Vector3(0.29, 0.035, 0.035), Vector3(0.035, 0.16, 0.035), Vector3(0.105, 0.085, 0.06)]:
		var part := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = spec
		mesh.material = trim
		part.mesh = mesh
		if spec.y > 0.1:
			part.position.y = -0.075
		steering_wheel.add_child(part)

func _add_instrument(pos: Vector3) -> void:
	var item := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.085; mesh.bottom_radius = 0.085; mesh.height = 0.018; mesh.radial_segments = 32
	mesh.material = _emissive(Color("8fd4ff"))
	item.mesh = mesh; item.position = pos; item.rotation_degrees.x = 90.0; add_child(item)

func _add_box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new(); var mesh := BoxMesh.new()
	mesh.size = size; mesh.material = material; item.mesh = mesh; item.position = pos; add_child(item)
	return item

func _add_box_rotated(size: Vector3, pos: Vector3, rotation: Vector3, material: Material) -> MeshInstance3D:
	var item := _add_box(size, pos, material)
	item.rotation_degrees = rotation
	return item

func _add_wheel(pos: Vector3) -> void:
	var item := MeshInstance3D.new(); var mesh := CylinderMesh.new()
	mesh.top_radius = 0.31; mesh.bottom_radius = 0.31; mesh.height = 0.18; mesh.radial_segments = 24
	mesh.material = _material(Color("17191c"), 0.05, 0.85)
	item.mesh = mesh
	item.rotation_degrees.z = 90.0
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	pivot.add_child(item)
	if pos.z < 0.0:
		front_wheel_pivots.append(pivot)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.metallic = metallic; mat.roughness = roughness
	return mat

func _emissive(color: Color) -> StandardMaterial3D:
	var mat := _material(color, 0.0, 0.15); mat.emission_enabled = true; mat.emission = color; mat.emission_energy_multiplier = 4.0
	return mat
