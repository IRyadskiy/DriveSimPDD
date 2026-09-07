extends Node3D
## Original procedural reconstruction inspired by Solaris II facelift.
## Coordinates: metres, +Y up, -Z forward. Not an OEM/CAD model.

var car: CharacterBody3D
var paint: StandardMaterial3D
var leather: StandardMaterial3D
var plastic: StandardMaterial3D
var silver: StandardMaterial3D
var black: StandardMaterial3D
var glass: StandardMaterial3D
var white: StandardMaterial3D
var needles: Array[Node3D] = []
var dash_text: Label3D
var warning_text: Label3D
var arrow_left: Label3D
var arrow_right: Label3D
var selector: Node3D
var mirrors: Array[Node3D] = []
var telltales: Dictionary = {}

func build(owner_car: CharacterBody3D) -> void:
	car = owner_car
	paint = material(Color("e7ebee"), 0.48, 0.25)
	leather = material(Color("191c20"), 0.0, 0.85)
	plastic = material(Color("292d32"), 0.05, 0.65)
	silver = material(Color("969ca4"), 0.75, 0.27)
	black = material(Color("080b0e"), 0.05, 0.64)
	white = material(Color("e4eeff"), 0.0, 0.45)
	glass = material(Color(0.35, 0.49, 0.57, 0.12), 0.15, 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	build_body()
	for side in [-1.0, 1.0]:
		car.fog_meshes.append(box(Vector3(0.12,0.06,0.04), Vector3(side * 0.64,0.43,-2.25), white))
	car.fog_meshes.append(box(Vector3(0.12,0.05,0.04), Vector3(-0.48,0.43,2.25), material(Color("f82628"),0,0.2)))
	build_interior()
	build_wheels()
	build_mirrors()
	merge_static_surfaces()

func merge_static_surfaces() -> void:
	# Keep moving parts and mirrors separate; batch static cabin/body by material.
	var batches: Dictionary = {}
	for node in get_children():
		if not node is MeshInstance3D:
			continue
		if node.has_meta("telltale"):
			continue
		if node in car.front_lights or node in car.left_lights or node in car.right_lights or node in car.brake_lights or node in car.reverse_lights or node in car.fog_meshes:
			continue
		var mat: Material = node.mesh.surface_get_material(0)
		if mat == glass:
			continue
		var key: int = mat.get_instance_id()
		if not batches.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(mat)
			batches[key] = st
		batches[key].append_from(node.mesh, 0, node.transform)
		remove_child(node)
		node.queue_free()
	for st in batches.values():
		mesh_item(st.commit(), Vector3.ZERO)

func material(color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	return mat

func mesh_item(mesh: Mesh, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = pos
	parent.add_child(item)
	return item

func box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	return mesh_item(mesh, pos, parent)

func ellipsoid(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 32
	mesh.rings = 16
	mesh.material = mat
	var item := mesh_item(mesh, pos, parent)
	item.scale = size
	return item

func tube(a: Vector3, b: Vector3, radius: float, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	mesh.material = mat
	var item := mesh_item(mesh, (a + b) * 0.5, parent)
	item.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return item

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [a, b, c, a, c, d, c, b, a, d, c, a]:
		st.add_vertex(p)
	st.generate_normals()
	st.set_material(mat)
	return mesh_item(st.commit(), Vector3.ZERO)

func label(text: String, pos: Vector3, size: int, scale_px: float, color: Color = Color.WHITE, parent: Node3D = self) -> Label3D:
	var item := Label3D.new()
	item.text = text
	item.font_size = size
	item.pixel_size = scale_px
	item.modulate = color
	item.outline_size = 0
	item.position = pos
	parent.add_child(item)
	return item

func build_body() -> void:
	# Body side surfaces have real wheel openings rather than a solid box.
	for side in [-1.0, 1.0]:
		for i in 112:
			var z0: float = -2.20 + float(i) * 4.40 / 112.0
			var z1: float = -2.20 + float(i + 1) * 4.40 / 112.0
			var x0: float = side * (0.86 - 0.10 * pow(absf(z0) / 2.20, 5))
			var x1: float = side * (0.86 - 0.10 * pow(absf(z1) / 2.20, 5))
			var low0: float = arch_height(z0)
			var low1: float = arch_height(z1)
			var high0: float = 0.94 - 0.08 * pow(absf(z0) / 2.20, 4)
			var high1: float = 0.94 - 0.08 * pow(absf(z1) / 2.20, 4)
			quad(Vector3(x0, low0, z0), Vector3(x1, low1, z1), Vector3(x1, high1, z1), Vector3(x0, high0, z0), paint)
		for z in [-1.3, 1.3]:
			for i in 32:
				var a: float = PI * float(i) / 32.0
				var b: float = PI * float(i + 1) / 32.0
				tube(Vector3(side * 0.859, 0.34 + sin(a) * 0.36, z + cos(a) * 0.36), Vector3(side * 0.859, 0.34 + sin(b) * 0.36, z + cos(b) * 0.36), 0.012, paint)
		# Door seams, handles and sill crease.
		for z in [-0.92, 0.22, 1.15]:
			tube(Vector3(side * 0.863, 0.38, z), Vector3(side * 0.863, 0.92, z), 0.0025, black)
		for z in [-0.04, 0.92]:
			ellipsoid(Vector3(0.028, 0.036, 0.14), Vector3(side * 0.873, 0.84, z), silver)
		# Sloping A/C pillars, B pillar and transparent window panels.
		tube(Vector3(side * 0.79, 0.95, -1.01), Vector3(side * 0.63, 1.45, -0.32), 0.035, paint)
		tube(Vector3(side * 0.63, 1.45, -0.32), Vector3(side * 0.64, 1.44, 0.86), 0.028, paint)
		tube(Vector3(side * 0.64, 1.44, 0.86), Vector3(side * 0.79, 0.99, 1.52), 0.062, paint)
		tube(Vector3(side * 0.79, 0.94, 0.25), Vector3(side * 0.65, 1.45, 0.25), 0.025, black)
		quad(Vector3(side * 0.79, 0.95, -0.99), Vector3(side * 0.64, 1.43, -0.30), Vector3(side * 0.65, 1.43, 0.22), Vector3(side * 0.80, 0.96, 0.22), glass)
		quad(Vector3(side * 0.80, 0.96, 0.29), Vector3(side * 0.65, 1.43, 0.29), Vector3(side * 0.64, 1.42, 0.83), Vector3(side * 0.79, 0.99, 1.47), glass)
		box(Vector3(0.04, 0.08, 2.05), Vector3(side * 0.84, 0.29, 0.10), paint)
	# Curved hood, trunk and roof: continuous tessellated surfaces.
	curved_panel(-2.18, -1.00, 0.77, 0.79, 0.84, 0.99, 0.035, paint)
	curved_panel(1.44, 2.18, 0.78, 0.77, 1.00, 0.88, 0.025, paint)
	curved_panel(-0.33, 0.90, 0.63, 0.64, 1.445, 1.445, 0.025, paint)
	quad(Vector3(-0.63, 1.445, 0.90), Vector3(0.63, 1.445, 0.90), Vector3(0.77, 1.00, 1.44), Vector3(-0.77, 1.00, 1.44), glass)
	# Windscreen kept optically clear; physical perimeter and wipers remain.
	for side in [-1.0, 1.0]:
		tube(Vector3(side * 0.48, 1.00, -1.00), Vector3(side * 0.19, 1.01, -1.02), 0.008, black)
		tube(Vector3(side * 0.42, 0.88, -2.09), Vector3(side * 0.55, 0.998, -1.04), 0.0025, silver)
	ellipsoid(Vector3(1.61, 0.40, 0.19), Vector3(0, 0.60, -2.15), paint)
	ellipsoid(Vector3(1.64, 0.42, 0.19), Vector3(0, 0.59, 2.15), paint)
	box(Vector3(1.05, 0.31, 0.025), Vector3(0, 0.58, -2.248), black)
	for i in 15:
		for j in 4:
			var x: float = -0.48 + float(i) * 0.068
			var y: float = 0.46 + float(j) * 0.068
			tube(Vector3(x - 0.020, y, -2.267), Vector3(x, y + 0.020, -2.267), 0.004, silver)
			tube(Vector3(x, y + 0.020, -2.267), Vector3(x + 0.020, y, -2.267), 0.004, silver)
	var badge := label("H", Vector3(0, 0.76, -2.27), 48, 0.0022, Color("bfc6d0"))
	badge.rotation.y = PI
	label("SOLARIS", Vector3(0, 0.88, 2.245), 28, 0.0015, Color("bfc6d0"))
	for side in [-1.0, 1.0]:
		var front := ellipsoid(Vector3(0.39, 0.13, 0.13), Vector3(side * 0.61, 0.82, -2.16), silver)
		front.rotation.z = side * 0.10
		var lamp := box(Vector3(0.28, 0.025, 0.028), Vector3(side * 0.63, 0.79, -2.232), white)
		car.front_lights.append(lamp)
		var red := material(Color("a90e19"), 0.2, 0.2)
		ellipsoid(Vector3(0.42, 0.13, 0.15), Vector3(side * 0.59, 0.86, 2.14), red)
		car.brake_lights.append(box(Vector3(0.27, 0.03, 0.03), Vector3(side * 0.59, 0.86, 2.222), material(Color("ff2739"), 0, 0.2)))
		car.reverse_lights.append(box(Vector3(0.07, 0.04, 0.03), Vector3(side * 0.34, 0.84, 2.222), white))
		var lights: Array[MeshInstance3D] = car.left_lights if side < 0.0 else car.right_lights
		for z in [-2.23, 2.22]:
			lights.append(box(Vector3(0.09, 0.04, 0.025), Vector3(side * 0.77, 0.81, z), material(Color("ff9f16"), 0, 0.3)))
	box(Vector3(1.42, 0.045, 2.18), Vector3(0, 0.32, 0.17), black)

func arch_height(z: float) -> float:
	var distance: float = minf(absf(z + 1.3), absf(z - 1.3))
	if distance < 0.36:
		return 0.34 + sqrt(0.36 * 0.36 - distance * distance)
	return 0.30

func curved_panel(z0: float, z1: float, w0: float, w1: float, y0: float, y1: float, crown: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 12:
		for i in 32:
			for uv in [Vector2(i, j), Vector2(i, j+1), Vector2(i+1,j+1), Vector2(i,j), Vector2(i+1,j+1), Vector2(i+1,j)]:
				var u: float = uv.x / 32.0 * 2.0 - 1.0
				var v: float = uv.y / 12.0
				st.add_vertex(Vector3(u * lerpf(w0, w1, v), lerpf(y0, y1, v) + crown * (1.0 - u*u), lerpf(z0, z1, v)))
	st.generate_normals()
	st.set_material(mat)
	mesh_item(st.commit(), Vector3.ZERO)

func rounded_panel(size: Vector2, radius: float, depth: float, pos: Vector3, mat: Material) -> void:
	var points: Array[Vector2] = []
	for corner in 4:
		var cx: float = (size.x * 0.5 - radius) * (1.0 if corner in [0,3] else -1.0)
		var cy: float = (size.y * 0.5 - radius) * (1.0 if corner in [0,1] else -1.0)
		for step in 9:
			var angle: float = (corner * 90.0 + step * 90.0 / 8.0) * PI / 180.0
			points.append(Vector2(cx + cos(angle)*radius, cy + sin(angle)*radius))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var a := Vector3(points[i].x,points[i].y,depth*0.5)
		var p: Vector2 = points[(i+1)%points.size()]
		var b := Vector3(p.x,p.y,depth*0.5)
		var c: Vector3 = b - Vector3(0,0,depth)
		var d: Vector3 = a - Vector3(0,0,depth)
		for vertex in [Vector3(0,0,depth*0.5), b, a, a,b,c,a,c,d]:
			st.add_vertex(vertex)
	st.set_material(mat)
	st.generate_normals()
	mesh_item(st.commit(), pos)

func build_dash_shell() -> void:
	box(Vector3(1.40,0.47,0.05), Vector3(0,0.55,-0.83), leather)
	box(Vector3(1.38,0.03,1.60), Vector3(0,0.34,0.04), leather)
	# Closed cross-section avoids the overlapping flattened spheres of the prototype.
	var profile: Array[Vector2] = [Vector2(-1.01,0.96), Vector2(-0.89,0.977), Vector2(-0.68,0.972), Vector2(-0.58,0.948), Vector2(-0.555,0.915), Vector2(-0.555,0.73), Vector2(-0.90,0.72)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		for j in profile.size():
			var k: int = (j + 1) % profile.size()
			for index in [Vector2i(i,j), Vector2i(i+1,j), Vector2i(i+1,k), Vector2i(i,j), Vector2i(i+1,k), Vector2i(i,k)]:
				var x: float = -0.73 + index.x * 1.46 / 32.0
				var p: Vector2 = profile[index.y]
				st.add_vertex(Vector3(x, p.y - 0.04 * pow(absf(x)/0.73, 4), p.x - 0.05 * pow(absf(x)/0.73, 4)))
	st.set_material(leather)
	st.generate_normals()
	mesh_item(st.commit(), Vector3.ZERO)
	# Flush glove-box panel, instead of exposed cross-bars.
	box(Vector3(0.44,0.145,0.015), Vector3(0.43,0.795,-0.56), plastic)
	box(Vector3(0.09,0.012,0.014), Vector3(0.43,0.83,-0.549), black)

func build_telltales() -> void:
	var keys: Array[String] = ["drl","low","high","fog","rear_fog","brake","belt","oil","battery","check","abs","airbag","eps","esp","fuel","temp"]
	var amber := Color("ffc247")
	var red := Color("ff4545")
	for i in keys.size():
		var key: String = keys[i]
		var color: Color = amber
		if key in ["brake","belt","oil","battery","airbag","temp"]: color = red
		if key in ["drl","low","fog"]: color = Color("4be587")
		if key == "high": color = Color("4d99ff")
		var pos := Vector3(-0.565 + (i % 8) * 0.054, 0.938 - (i / 8) * 0.027, -0.516)
		var glyph: String = icon_path(key)
		if glyph.is_empty():
			var text_icon := label(key.to_upper(), pos, 19, 0.00065, color)
			telltales[key] = text_icon
		else:
			var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="48" viewBox="0 0 64 48"><g fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">' + glyph + '</g></svg>'
			var img := Image.new()
			img.load_svg_from_string(svg)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_texture = ImageTexture.create_from_image(img)
			mat.albedo_color = color
			var mesh := QuadMesh.new()
			mesh.size = Vector2(0.029, 0.022)
			mesh.material = mat
			var item := mesh_item(mesh, pos)
			item.set_meta("telltale", true)
			telltales[key] = item

func icon_path(key: String) -> String:
	match key:
		"low", "high", "fog", "rear_fog":
			var beams: String = '<path d="M9 12 H25 M9 24 H25 M9 36 H25"/>' if key == "high" else '<path d="M8 19 L25 11 M8 31 L25 23 M8 43 L25 35"/>'
			if key in ["fog","rear_fog"]: beams += '<path d="M17 8 Q10 15 17 22 T17 39"/>'
			return '<path d="M32 8 Q60 8 60 24 Q60 40 32 40 Z"/>' + beams
		"battery": return '<path d="M7 13 H57 V40 H7 Z M16 13 V8 H25 V13 M40 13 V8 H49 V13 M14 24 H26 M20 18 V30 M39 24 H50"/>'
		"oil": return '<path d="M10 17 H39 L45 25 L55 21 L44 38 H18 L10 27 Z M23 17 V11 H34 M7 18 H3 V28 H10 M55 33 Q64 43 55 44 Q49 42 55 33"/>'
		"brake": return '<circle cx="32" cy="24" r="15"/><path d="M10 7 Q0 24 10 41 M54 7 Q64 24 54 41 M32 14 V27 M32 33 V34"/>'
		"belt": return '<circle cx="31" cy="9" r="5"/><path d="M23 18 H39 L43 33 H19 Z M22 33 L17 43 M39 33 L44 43 M16 16 L43 40"/>'
		"fuel": return '<path d="M11 42 V8 H35 V42 M8 42 H40 M15 12 H31 V24 H15 Z M35 28 H44 V38 Q55 45 55 34 V18 L47 10 M50 13 V23 H55"/>'
		"temp": return '<path d="M28 9 A4 4 0 0 1 36 9 V27 A9 9 0 1 1 28 27 Z M36 12 H43 M36 20 H43 M4 43 Q11 35 18 43 T32 43 T46 43 T60 43"/>'
		"check": return '<path d="M7 21 H15 V13 H39 L45 20 H54 V15 H60 V36 H54 L49 41 H19 L12 33 H7 Z M23 13 V7 H36 M3 22 V34"/>'
		"airbag": return '<circle cx="19" cy="10" r="5"/><circle cx="45" cy="22" r="10"/><path d="M13 20 L19 31 H32 L35 42 M10 17 V36 H26"/>'
	return ""

func build_interior() -> void:
	# Soft sculpted top, broad horizontal trim, raised infotainment screen.
	build_dash_shell()
	tube(Vector3(-0.65, 0.844, -0.562), Vector3(0.65, 0.844, -0.562), 0.004, silver)
	var cluster := ellipsoid(Vector3(0.55, 0.27, 0.20), Vector3(-0.36, 1.005, -0.75), black)
	cluster.name = "InstrumentBinnacle"
	rounded_panel(Vector2(0.54,0.233), 0.055, 0.016, Vector3(-0.36,1.012,-0.548), black)
	gauge(Vector3(-0.482, 1.006, -0.525), "RPM", 8)
	gauge(Vector3(-0.258, 1.006, -0.525), "km/h", 8)
	dash_text = label("P\n0 km/h", Vector3(-0.368, 1.005, -0.510), 30, 0.00085, Color("a8d4ff"))
	warning_text = label("", Vector3(-0.368, 0.962, -0.510), 17, 0.00050, Color("a8d4ff"))
	build_telltales()
	arrow_left = label("◀", Vector3(-0.422, 1.082, -0.515), 28, 0.0007)
	arrow_right = label("▶", Vector3(-0.314, 1.082, -0.515), 28, 0.0007)
	rounded_panel(Vector2(0.33,0.197), 0.016, 0.038, Vector3(0.13,1.015,-0.651), black)
	box(Vector3(0.293, 0.166, 0.018), Vector3(0.13, 1.022, -0.515), material(Color("101c2d"), 0.1, 0.35))
	label("12:00", Vector3(0.13, 1.05, -0.612), 38, 0.0010, Color("a4caff"))
	label("RADIO     MEDIA     SETUP", Vector3(0.13, 0.988, -0.612), 18, 0.0006)
	for x in [-0.049, 0.309]:
		knob(Vector3(x, 0.935, -0.613), 0.018)
	for x in [-0.635, -0.02, 0.26, 0.635]:
		vent(Vector3(x, 0.873, -0.576), 0.12)
	box(Vector3(0.042, 0.036, 0.02), Vector3(0.12, 0.874, -0.572), black)
	label("△", Vector3(0.12, 0.874, -0.559), 28, 0.0010, Color("ed4e4c"))
	box(Vector3(0.335, 0.186, 0.095), Vector3(0.12, 0.73, -0.557), plastic)
	for x in [0.006, 0.235]:
		knob(Vector3(x, 0.75, -0.506), 0.030)
	label("21.0\nAUTO   A/C", Vector3(0.12, 0.755, -0.501), 24, 0.0008, Color("b1dfff"))
	box(Vector3(0.12, 0.025, 0.015), Vector3(0.12, 0.663, -0.501), black)
	label("USB   12V", Vector3(0.12, 0.663, -0.489), 18, 0.0007)
	ellipsoid(Vector3(0.27, 0.21, 1.0), Vector3(0.04, 0.46, -0.08), plastic)
	box(Vector3(0.19, 0.02, 0.26), Vector3(0.055, 0.575, -0.22), silver)
	box(Vector3(0.14, 0.024, 0.23), Vector3(0.055, 0.589, -0.22), black)
	selector = Node3D.new()
	selector.position = Vector3(0.055, 0.60, -0.23)
	add_child(selector)
	tube(Vector3.ZERO, Vector3(0, 0.13, 0), 0.009, silver, selector)
	ellipsoid(Vector3(0.055, 0.065, 0.08), Vector3(0, 0.13, 0), leather, selector)
	var gear_marks := label("P  R  N  D", Vector3(-0.034, 0.607, -0.22), 24, 0.0006)
	gear_marks.rotation_degrees = Vector3(-90, 0, 90)
	for z in [0.12, 0.28]:
		var cup := ring(0.037, 0.043, black, self)
		cup.position = Vector3(0.04, 0.56, z)
	tube(Vector3(-0.07, 0.53, 0.18), Vector3(-0.07, 0.61, -0.02), 0.021, leather)
	for side in [-1.0, 1.0]:
		seat(Vector3(side * 0.39, 0, 0.40))
		ellipsoid(Vector3(0.09, 0.45, 1.04), Vector3(side * 0.75, 0.64, -0.16), plastic)
		box(Vector3(0.06, 0.09, 0.56), Vector3(side * 0.70, 0.72, -0.12), leather)
		tube(Vector3(side * 0.695, 0.86, -0.48), Vector3(side * 0.695, 0.85, -0.29), 0.009, silver)
		box(Vector3(0.036, 0.013, 0.12), Vector3(side * 0.674, 0.77, -0.17), black)
		for z in [-0.205, -0.17, -0.135]:
			box(Vector3(0.025, 0.010, 0.020), Vector3(side * 0.674, 0.782, z), silver)
		# Interior pillar liner follows the body, away from driver's eye.
		tube(Vector3(side * 0.760, 0.95, -1.00), Vector3(side * 0.595, 1.43, -0.31), 0.035, plastic)
	ellipsoid(Vector3(1.35, 0.17, 0.45), Vector3(0, 0.48, 1.10), leather)
	ellipsoid(Vector3(1.35, 0.58, 0.16), Vector3(0, 0.80, 1.35), leather)
	for x in [-0.46, 0.46]:
		ellipsoid(Vector3(0.25, 0.20, 0.12), Vector3(x, 1.12, 1.37), leather)
	build_steering()

func seat(pos: Vector3) -> void:
	ellipsoid(Vector3(0.49, 0.16, 0.55), pos + Vector3(0, 0.49, 0), leather)
	ellipsoid(Vector3(0.48, 0.64, 0.18), pos + Vector3(0, 0.83, 0.24), leather).rotation_degrees.x = 10
	for x in [-0.19, 0.19]:
		ellipsoid(Vector3(0.09, 0.56, 0.16), pos + Vector3(x, 0.82, 0.18), plastic)
	ellipsoid(Vector3(0.27, 0.22, 0.14), pos + Vector3(0, 1.20, 0.29), leather)

func ring(inner: float, outer: float, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 64
	mesh.ring_segments = 16
	mesh.material = mat
	return mesh_item(mesh, Vector3.ZERO, parent)

func knob(pos: Vector3, radius: float) -> void:
	var item := ring(radius * 0.82, radius, silver, self)
	item.position = pos
	item.rotation.x = PI / 2.0
	ellipsoid(Vector3(radius * 1.65, radius * 1.65, 0.022), pos, black)

func vent(pos: Vector3, width: float) -> void:
	box(Vector3(width + 0.010, 0.06, 0.025), pos, silver)
	box(Vector3(width, 0.05, 0.028), pos + Vector3(0, 0, 0.005), black)
	for i in 5:
		box(Vector3(width - 0.01, 0.003, 0.014), pos + Vector3(0, -0.020 + i * 0.01, 0.024), plastic)

func gauge(pos: Vector3, caption: String, divisions: int) -> void:
	var rim := ring(0.073, 0.079, silver, self)
	rim.position = pos
	rim.rotation.x = PI / 2
	ellipsoid(Vector3(0.145, 0.145, 0.018), pos, black)
	for i in 41:
		var angle: float = deg_to_rad(-130.0 + i * 6.5)
		var radial := Vector3(sin(angle), cos(angle), 0)
		tube(pos + radial * (0.056 if i % 5 == 0 else 0.063) + Vector3(0,0,0.012), pos + radial * 0.070 + Vector3(0,0,0.012), 0.0010, white)
	for i in divisions + 1:
		var angle: float = deg_to_rad(-130.0 + float(i) * 260.0 / divisions)
		label(str(i * (1 if caption == "RPM" else 30)), pos + Vector3(sin(angle)*0.044, cos(angle)*0.044, 0.016), 20, 0.00065)
	label(caption, pos + Vector3(0, -0.033, 0.016), 18, 0.0005)
	var needle := Node3D.new()
	needle.position = pos + Vector3(0, 0, 0.023)
	add_child(needle)
	tube(Vector3(0, -0.008, 0), Vector3(0, 0.056, 0), 0.0018, material(Color("fa493d"), 0, 0.5), needle)
	ellipsoid(Vector3(0.010, 0.010, 0.006), Vector3.ZERO, silver, needle)
	needles.append(needle)

func build_steering() -> void:
	var shaft := Node3D.new()
	shaft.position = Vector3(-0.37, 0.845, -0.365)
	shaft.rotation_degrees.x = -15.0
	add_child(shaft)
	car.steering_wheel = Node3D.new()
	shaft.add_child(car.steering_wheel)
	var wheel: Node3D = car.steering_wheel
	var rim := ring(0.160, 0.185, leather, wheel)
	rim.rotation.x = PI / 2.0
	for side in [-1.0, 1.0]:
		tube(Vector3(side * 0.04, -0.005, 0), Vector3(side * 0.166, 0.019, 0), 0.021, plastic, wheel)
		tube(Vector3(side * 0.045, -0.045, 0), Vector3(side * 0.073, -0.149, 0), 0.010, silver, wheel)
		for row in 3:
			box(Vector3(0.031, 0.012, 0.008), Vector3(side * 0.111, 0.018 - row * 0.016, 0.020), black, wheel)
		label("+\n−", Vector3(side * 0.11, 0.008, 0.026), 18, 0.00055, Color.WHITE, wheel)
	ellipsoid(Vector3(0.135, 0.115, 0.055), Vector3(0, -0.010, 0.015), leather, wheel)
	var emblem := ring(0.019, 0.021, silver, wheel)
	emblem.rotation.x = PI / 2
	emblem.scale.x = 1.6
	emblem.position.z = 0.045
	label("H", Vector3(0, 0, 0.047), 26, 0.0010, Color("c7cbd1"), wheel)
	label("AIRBAG", Vector3(0, -0.040, 0.045), 16, 0.0005, Color("6b7179"), wheel)
	for side in [-1.0, 1.0]:
		tube(Vector3(-0.37 + side * 0.055, 0.94, -0.50), Vector3(-0.37 + side * 0.22, 0.95, -0.48), 0.012, black)
		label("◀ ▶" if side < 0 else "WIPER", Vector3(-0.37 + side * 0.19, 0.958, -0.46), 18, 0.00045)

func build_wheels() -> void:
	for side in [-1.0, 1.0]:
		for z in [-1.3, 1.3]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.79, 0.32, z)
			add_child(pivot)
			if z < 0:
				car.front_wheel_pivots.append(pivot)
			var tire := ring(0.205, 0.315, black, pivot)
			tire.rotation.z = PI / 2
			var rim := ring(0.187, 0.205, silver, pivot)
			rim.rotation.z = PI / 2
			rim.position.x = side * 0.074
			for i in 10:
				var angle: float = float(i) * TAU / 10.0
				tube(Vector3(side * 0.082, 0, 0), Vector3(side * 0.082, sin(angle)*0.19, cos(angle)*0.19), 0.012, silver, pivot)

func build_mirrors() -> void:
	for side in [-1.0, 1.0]:
		tube(Vector3(side * 0.80, 1.03, -0.78), Vector3(side * 0.94, 1.04, -0.75), 0.023, black)
		var mount := Node3D.new()
		mount.position = Vector3(side * 0.965, 1.065, -0.75)
		mount.rotation.y = side * -0.28
		add_child(mount)
		ellipsoid(Vector3(0.25, 0.145, 0.13), Vector3(0,0,-0.04), paint, mount)
		box(Vector3(0.218, 0.119, 0.020), Vector3(0,0,0.022), black, mount)
		mount.set_meta("size", Vector2(0.202, 0.104))
		mount.set_meta("camera_pos", Vector3(side * 0.99, 1.07, -0.68))
		mount.set_meta("direction", Vector3(side * 0.16, -0.075, 1))
		mirrors.append(mount)
	var center := Node3D.new()
	center.position = Vector3(0.06, 1.345, -0.56)
	center.rotation.y = -0.15
	add_child(center)
	box(Vector3(0.255, 0.085, 0.030), Vector3.ZERO, black, center)
	tube(Vector3(0.06,1.35,-0.57), Vector3(0.06,1.445,-0.43), 0.009, black)
	center.set_meta("size", Vector2(0.235,0.067))
	center.set_meta("camera_pos", Vector3(0.06,1.32,-0.51))
	center.set_meta("direction", Vector3(0, -0.06, 1))
	mirrors.append(center)

func _process(_delta: float) -> void:
	if car == null or needles.size() < 2:
		return
	var kmh: float = absf(car.speed) * 3.6
	var rpm: float = car.rpm / 1000.0
	needles[0].rotation.z = deg_to_rad(130.0 - clampf(rpm / 8.0,0,1)*260.0)
	needles[1].rotation.z = deg_to_rad(130.0 - clampf(kmh / 240.0,0,1)*260.0)
	dash_text.text = "%s\n%d km/h" % [car.gear, roundi(kmh)]
	dash_text.visible = car.ignition_on
	warning_text.visible = car.ignition_on
	warning_text.text = "%d L   %d°C" % [roundi(car.fuel_liters), roundi(car.coolant_c)]
	var states: Dictionary = car.dashboard_states()
	for key in telltales:
		telltales[key].visible = states.get(key, false)
	arrow_left.modulate = Color("49fa76") if car.blink_visible and (car.left_signal or car.hazards_on) else Color("14251a")
	arrow_right.modulate = Color("49fa76") if car.blink_visible and (car.right_signal or car.hazards_on) else Color("14251a")
	selector.rotation.x = deg_to_rad(float(["P","R","N","D"].find(car.gear)) * 8.0 - 12.0)
