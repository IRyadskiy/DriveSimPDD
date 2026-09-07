extends SceneTree

func _initialize() -> void:
	call_deferred("check_model")

func check_model() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene._process(0.016)
	var car = scene.car
	var model = car.get_node("Solaris2021Model")
	assert(model.mirrors.size() == 3)
	assert(scene.mirror_cameras.size() == 3)
	assert(model.needles.size() == 2)
	assert(model.telltales.size() == 16)
	assert(car.front_wheel_pivots.size() == 2)
	# The side of the car must be inside each side-mirror frustum.
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var body_point: Vector3 = car.global_transform * Vector3(side * 0.855, 0.90, 0.90)
		assert(scene.mirror_cameras[i].is_position_in_frustum(body_point), "Body missing from mirror frustum")
	var hood_point: Vector3 = car.global_transform * Vector3(-0.35, 0.94, -1.70)
	assert(scene.camera.is_position_in_frustum(hood_point), "Hood outside cockpit view")
	var eye: Vector3 = scene.camera.global_position
	assert(not blocked(model, eye, eye + car.global_basis * Vector3(0, 0, -5)), "Forward view blocked by body")
	car.engine_on = true
	car.ignition_on = true
	car.handbrake_on = false
	car.gear = "D"
	for i in 70:
		await physics_frame
	assert(car.speed > 0.2)
	Input.action_press("steer_left")
	for i in 25:
		await physics_frame
	assert(car.steering_wheel.rotation.z > 0.2)
	Input.action_release("steer_left")
	car.left_signal = true
	car._restart_blink()
	car._update_lights(0.01)
	model._process(0.016)
	assert(model.arrow_left.modulate.g > 0.8)
	assert(model.arrow_right.modulate.g < 0.3)
	car.reset_vehicle()
	assert(car.gear == "P")
	car.ignition_on = true
	car.lamp_test_left = 2.0
	assert(car.dashboard_states()["abs"])
	car._update_systems(2.1)
	assert(not car.dashboard_states()["abs"])
	assert(car.dashboard_states()["oil"] and car.dashboard_states()["battery"])
	car.engine_on = true
	car.seat_belt_on = true
	car.handbrake_on = false
	assert(not car.dashboard_states()["oil"] and not car.dashboard_states()["belt"])
	car.light_mode = 2
	car._update_lights(0.01)
	assert(car.dashboard_states()["low"] and car.headlamp_beams[0].visible)
	car.light_mode = 3
	car._update_lights(0.01)
	assert(car.dashboard_states()["high"] and not car.dashboard_states()["low"])
	assert(car.headlamp_beams[0].spot_range == 70.0)
	car.fog_front = true
	car.fog_rear = true
	car._update_lights(0.01)
	assert(car.fog_meshes[0].visible and car.fog_meshes[2].visible)
	car.fuel_liters = 4.0
	car.coolant_c = 115.0
	assert(car.dashboard_states()["fuel"] and car.dashboard_states()["temp"])
	car.coolant_c = 90.0
	car.gear = "D"
	car.speed = 5.0
	Input.action_press("accelerate")
	Input.action_press("brake_reverse")
	for i in 45:
		await physics_frame
	assert(absf(car.speed) < 0.1, "Brake must override throttle")
	Input.action_release("accelerate")
	Input.action_release("brake_reverse")
	car.reset_vehicle()
	scene._static_box(Vector3(8, 2, 0.3), car.global_position + Vector3(0, 1, -3.3), Color.GRAY)
	car.ignition_on = true
	car.engine_on = true
	car.handbrake_on = false
	car.gear = "D"
	Input.action_press("accelerate")
	for i in 100:
		await physics_frame
	assert(absf(car.speed) < 0.2, "Collision must stop reported forward speed")
	Input.action_release("accelerate")
	car.reset_vehicle()
	print("SOLARIS MODEL SMOKE PASS")
	scene.queue_free()
	await process_frame
	await process_frame
	quit()

func blocked(node: Node, origin: Vector3, target: Vector3) -> bool:
	if node is MeshInstance3D and node.visible:
		var mat: Material = node.mesh.surface_get_material(0)
		if mat is StandardMaterial3D and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
		var inverse: Transform3D = node.global_transform.affine_inverse()
		var start: Vector3 = inverse * origin
		var end: Vector3 = inverse * target
		var faces: PackedVector3Array = node.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			if Geometry3D.segment_intersects_triangle(start, end, faces[i], faces[i+1], faces[i+2]) != null:
				return true
	for child in node.get_children():
		if blocked(child, origin, target):
			return true
	return false
