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
	var model = preload("res://scripts/solaris_model.gd").new()
	model.name = "Solaris2021Model"
	add_child(model)
	model.build(self)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, LENGTH)
	collision.shape = shape
	collision.position.y = HEIGHT * 0.5
	add_child(collision)
