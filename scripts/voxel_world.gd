extends Node3D

const Blocks = preload("res://scripts/blocks.gd")
const Farm = preload("res://scripts/farm_layout.gd")
const Shapes = preload("res://scripts/voxel_shapes.gd")
const Valley = preload("res://scripts/valley_layout.gd")
const FarLandscape = preload("res://scripts/far_landscape.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const City = preload("res://scripts/city_layout.gd")
const SIZE := 96
const HEIGHT := 40
const CHUNK := 16
const GENERATOR_VERSION := 1
const DIRECTIONS := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
# Counterclockwise corner normals; triangle indices below reverse to Godot's clockwise winding.
const CORNERS := [
	[Vector3(1,0,0), Vector3(1,1,0), Vector3(1,1,1), Vector3(1,0,1)],
	[Vector3(0,0,1), Vector3(0,1,1), Vector3(0,1,0), Vector3(0,0,0)],
	[Vector3(0,1,1), Vector3(1,1,1), Vector3(1,1,0), Vector3(0,1,0)],
	[Vector3(0,0,0), Vector3(1,0,0), Vector3(1,0,1), Vector3(0,0,1)],
	[Vector3(1,0,1), Vector3(1,1,1), Vector3(0,1,1), Vector3(0,0,1)],
	[Vector3(0,0,0), Vector3(0,1,0), Vector3(1,1,0), Vector3(1,0,0)]
]
const TRIANGLES := [0, 2, 1, 0, 3, 2]
const UV_CORNERS := [Vector2(0,1), Vector2(0,0), Vector2(1,0), Vector2(1,1)]
const FACE_LIGHT := [0.86, 0.78, 1.0, 0.55, 0.91, 0.81]

var blocks := PackedByteArray()
var changes: Dictionary = {}
var chunks: Dictionary = {}
var dirty_chunks: Array[Vector2i] = []
var world_seed := 20260905
var material: StandardMaterial3D
var emissive_cells: Dictionary = {}
var light_pool: Array[OmniLight3D] = []
var size := SIZE
var height := HEIGHT
var far_landscape: Node3D
var world_id := "classic"
var generator_version := GENERATOR_VERSION
var streaming := false
var build_queue: Array[Vector2i] = []
var stream_center := Vector2i(-100,-100)
const STREAM_RADIUS := 3

func configure(id: String) -> void:
	var item := Catalog.entry(id)
	assert(not item.is_empty())
	world_id = id
	size = item["size"]
	height = item["height"]
	generator_version = item["generator"]
	blocks.resize(size*height*size)

func _init() -> void:
	Blocks.setup()
	blocks.resize(SIZE * HEIGHT * SIZE)

func inside(p: Vector3i) -> bool:
	return p.x >= 0 and p.x < size and p.z >= 0 and p.z < size and p.y >= 0 and p.y < height

func index_of(p: Vector3i) -> int:
	return p.x + size * (p.z + size * p.y)

func get_block(p: Vector3i) -> int:
	return blocks[index_of(p)] if inside(p) else 0

func _put(p: Vector3i, block: int) -> void:
	if inside(p): blocks[index_of(p)] = block

func generate(seed_value: int) -> void:
	world_seed = seed_value
	blocks.fill(0)
	changes.clear()
	emissive_cells.clear()
	if world_id == "city":
		City.generate(self)
		return
	if world_id == "valley":
		Valley.generate(self)
		return
	if world_id == "farm":
		Farm.generate(self)
		return
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.frequency = 0.023
	noise.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var center_height := clampi(int(11 + noise.get_noise_2d(SIZE / 2, SIZE / 2) * 10), 5, 22)
	for x in SIZE:
		for z in SIZE:
			var h := clampi(int(11 + noise.get_noise_2d(x, z) * 10), 5, 22)
			var center_distance := Vector2(x - SIZE / 2, z - SIZE / 2).length()
			if center_distance < 7:
				h = roundi(lerpf(center_height, h, smoothstep(4,7,center_distance)))
			var sandy := h <= 7
			for y in h + 1:
				var block := 3
				if y == 0: block = 9
				elif y == h: block = 6 if sandy else 1
				elif y >= h - 3: block = 6 if sandy else 2
				_put(Vector3i(x,y,z), block)
	for x in range(4, SIZE - 4):
		for z in range(4, SIZE - 4):
			if Vector2(x - SIZE / 2, z - SIZE / 2).length() < 7: continue
			if rng.randf() > 0.009: continue
			var y := surface_height(x,z)
			if get_block(Vector3i(x,y,z)) != 1: continue
			var trunk := rng.randi_range(4, 6)
			for ly in range(y + trunk - 2, y + trunk + 2):
				var radius := 1 if ly == y + trunk + 1 else 2
				for lx in range(-radius, radius + 1):
					for lz in range(-radius, radius + 1):
						if abs(lx) == radius and abs(lz) == radius and rng.randf() < 0.5: continue
						var p := Vector3i(x + lx, ly, z + lz)
						if get_block(p) == 0: _put(p, 5)
			for ly in range(y + 1, y + trunk + 1): _put(Vector3i(x,ly,z), 4)

func surface_height(x: int, z: int) -> int:
	for y in range(height - 1, -1, -1):
		if get_block(Vector3i(x,y,z)) != 0: return y
	return 0

func spawn_position() -> Vector3:
	if world_id == "city": return Vector3(208.5,15.1,224.5)
	if world_id == "valley": return Vector3(192.5,23.1,208.5)
	if world_id == "farm": return Vector3(96.5,16.1,112.5)
	return Vector3(SIZE / 2.0 + 0.5, surface_height(SIZE / 2, SIZE / 2) + 2.1, SIZE / 2.0 + 0.5)

func set_block(p: Vector3i, block: int) -> bool:
	if not inside(p) or p.y == 0 or not Blocks.valid_edit(block) or get_block(p) == block: return false
	_put(p, block)
	if block > 0 and Blocks.entries[block]["emissive"]: emissive_cells[p] = block
	else: emissive_cells.erase(p)
	changes[str(index_of(p))] = block
	if is_instance_valid(far_landscape): far_landscape.mark_dirty(Vector2i(p.x/CHUNK,p.z/CHUNK))
	_mark_dirty(Vector2i(p.x / CHUNK, p.z / CHUNK))
	if p.x % CHUNK == 0: _mark_dirty(Vector2i(p.x / CHUNK - 1, p.z / CHUNK))
	if p.x % CHUNK == CHUNK - 1: _mark_dirty(Vector2i(p.x / CHUNK + 1, p.z / CHUNK))
	if p.z % CHUNK == 0: _mark_dirty(Vector2i(p.x / CHUNK, p.z / CHUNK - 1))
	if p.z % CHUNK == CHUNK - 1: _mark_dirty(Vector2i(p.x / CHUNK, p.z / CHUNK + 1))
	# Corner shading also samples diagonally adjacent chunks.
	if p.x % CHUNK in [0, CHUNK-1] and p.z % CHUNK in [0, CHUNK-1]:
		_mark_dirty(Vector2i(p.x/CHUNK + (-1 if p.x%CHUNK == 0 else 1), p.z/CHUNK + (-1 if p.z%CHUNK == 0 else 1)))
	return true

func _mark_dirty(key: Vector2i) -> void:
	if key.x < 0 or key.y < 0 or key.x >= size / CHUNK or key.y >= size / CHUNK: return
	if not dirty_chunks.has(key): dirty_chunks.append(key)

func _process(_delta: float) -> void:
	while not dirty_chunks.is_empty():
		var key: Vector2i = dirty_chunks.pop_front()
		if not streaming or chunks.has(key):
			build_chunk(key)
			return
	if not build_queue.is_empty(): build_chunk(build_queue.pop_front())

func update_stream(view_position: Vector3, force: bool = false) -> void:
	if not streaming: return
	var center := Vector2i(floori(view_position.x/CHUNK),floori(view_position.z/CHUNK))
	if center == stream_center and not force: return
	stream_center = center
	build_queue.clear()
	for x in range(maxi(0,center.x-STREAM_RADIUS),mini(size/CHUNK,center.x+STREAM_RADIUS+1)):
		for z in range(maxi(0,center.y-STREAM_RADIUS),mini(size/CHUNK,center.y+STREAM_RADIUS+1)):
			var key := Vector2i(x,z)
			if not chunks.has(key): build_queue.append(key)
	build_queue.sort_custom(func(a: Vector2i,b: Vector2i): return a.distance_squared_to(center) < b.distance_squared_to(center))
	for key: Vector2i in chunks.keys():
		if maxi(absi(key.x-center.x),absi(key.y-center.y)) > STREAM_RADIUS+1:
			remove_child(chunks[key])
			chunks[key].queue_free()
			chunks.erase(key)
			if is_instance_valid(far_landscape): far_landscape.show_patch(key)

func collision_ready(at: Vector3) -> bool:
	return not streaming or chunks.has(Vector2i(floori(at.x/CHUNK),floori(at.z/CHUNK)))

func build_chunk(key: Vector2i) -> void:
	if material == null: material = Blocks.make_material()
	var groups: Array = []
	for group in 2: groups.append([PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray()])
	var collision := PackedVector3Array()
	var special: Dictionary = {}
	var origin := Vector3i(key.x * CHUNK, 0, key.y * CHUNK)
	for lx in CHUNK:
		for lz in CHUNK:
			for y in height:
				var p := origin + Vector3i(lx,y,lz)
				var block := get_block(p)
				if block == 0: continue
				if Blocks.shape_of(block) != "cube":
					if not special.has(block): special[block] = []
					special[block].append(Vector3(lx,y,lz))
					if Blocks.is_solid(block):
						for f in 6:
							for i in TRIANGLES: collision.append(Vector3(lx,y,lz)+CORNERS[f][i])
					continue
				var group := 1 if Blocks.is_transparent(block) else 0
				for f in 6:
					if not Blocks.face_visible(block, get_block(p + DIRECTIONS[f])): continue
					var tile: int = Blocks.tile_for(block, DIRECTIONS[f])
					var corner_shades: Array[float] = []
					for corner in CORNERS[f]: corner_shades.append(vertex_shade(p, DIRECTIONS[f], corner) * FACE_LIGHT[f])
					var triangles := TRIANGLES if corner_shades[0]+corner_shades[2] >= corner_shades[1]+corner_shades[3] else [0,3,1,1,3,2]
					for i in triangles:
						var vertex: Vector3 = Vector3(lx,y,lz) + CORNERS[f][i]
						groups[group][0].append(vertex)
						groups[group][1].append(Vector3(DIRECTIONS[f]))
						groups[group][2].append(Blocks.uv_for(tile, UV_CORNERS[i]))
						var shade: float = corner_shades[i]
						groups[group][3].append(Color(shade, shade, shade))
						if Blocks.is_solid(block): collision.append(vertex)
	var node: StaticBody3D
	if chunks.has(key):
		node = chunks[key]
	else:
		node = StaticBody3D.new()
		node.name = "Chunk_%d_%d" % [key.x, key.y]
		node.position = Vector3(origin)
		node.collision_layer = 1
		node.add_child(MeshInstance3D.new())
		node.add_child(CollisionShape3D.new())
		add_child(node)
		chunks[key] = node
	var mesh_node := node.get_child(0) as MeshInstance3D
	var collider := node.get_child(1) as CollisionShape3D
	for child in node.get_children().slice(2):
		node.remove_child(child)
		child.queue_free()
	for block: int in special:
		var batch := MultiMeshInstance3D.new()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = Shapes.mesh_for(block)
		multimesh.instance_count = special[block].size()
		for i in special[block].size(): multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,special[block][i]))
		batch.multimesh = multimesh
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if not Blocks.is_solid(block) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.add_child(batch)
	if groups[0][0].is_empty() and groups[1][0].is_empty():
		mesh_node.mesh = null
	var mesh := ArrayMesh.new()
	for group in 2:
		if groups[group][0].is_empty(): continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = groups[group][0]
		arrays[Mesh.ARRAY_NORMAL] = groups[group][1]
		arrays[Mesh.ARRAY_TEX_UV] = groups[group][2]
		arrays[Mesh.ARRAY_COLOR] = groups[group][3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1, Blocks.make_material(group == 1))
	mesh_node.mesh = mesh if mesh.get_surface_count() > 0 else null
	if collision.is_empty(): collider.shape = null
	else:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(collision)
		collider.shape = shape
	if is_instance_valid(far_landscape): far_landscape.hide_patch(key)

func generate_valley_async(seed_value: int, progress: Callable) -> void:
	world_seed = seed_value
	blocks.fill(0)
	changes.clear()
	emissive_cells.clear()
	await Valley.generate_async(self,progress)

func prepare_distant_landscape(progress: Callable) -> void:
	far_landscape = FarLandscape.new()
	add_child(far_landscape)
	await far_landscape.prepare(self,progress)

func generate_city_async(seed_value: int, progress: Callable) -> void:
	world_seed = seed_value
	blocks.fill(0)
	changes.clear()
	emissive_cells.clear()
	await City.generate_async(self,progress)

func vertex_shade(p: Vector3i, normal: Vector3i, corner: Vector3) -> float:
	var tangents: Array[Vector3i] = []
	for axis in 3:
		if normal[axis] == 0:
			var tangent := Vector3i.ZERO
			tangent[axis] = -1 if corner[axis] < 0.5 else 1
			tangents.append(tangent)
	var outside := p + normal
	var a := int(Blocks.occludes(get_block(outside+tangents[0])))
	var b := int(Blocks.occludes(get_block(outside+tangents[1])))
	var c := int(Blocks.occludes(get_block(outside+tangents[0]+tangents[1])))
	return 0.52 if a == 1 and b == 1 else 1.0 - 0.16 * (a+b+c)

func make_block_mesh(block: int) -> ArrayMesh:
	if Blocks.shape_of(block) != "cube":
		var source := Shapes.mesh_for(block)
		var arrays := source.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size(): vertices[i] -= Vector3.ONE*0.5
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var mat := source.surface_get_material(0).duplicate() as StandardMaterial3D
		mat.no_depth_test = true
		mat.render_priority = 10
		mesh.surface_set_material(0,mat)
		return mesh
	if material == null: material = Blocks.make_material()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var held_material := Blocks.make_material(Blocks.is_transparent(block)).duplicate() as StandardMaterial3D
	held_material.no_depth_test = true
	held_material.render_priority = 10
	surface.set_material(held_material)
	for f in 6:
		for i in TRIANGLES:
			surface.set_normal(Vector3(DIRECTIONS[f]))
			surface.set_uv(Blocks.uv_for(Blocks.tile_for(block,DIRECTIONS[f]), UV_CORNERS[i]))
			surface.set_color(Color.WHITE)
			surface.add_vertex(CORNERS[f][i]-Vector3.ONE*0.5)
	return surface.commit()

func raycast(origin: Vector3, direction: Vector3, reach: float = 6.0) -> Dictionary:
	# Grid traversal hits the current voxel data immediately, even before a mesh rebuild.
	var cell := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i(signi(int(signf(direction.x))), signi(int(signf(direction.y))), signi(int(signf(direction.z))))
	var t_delta := Vector3(INF, INF, INF)
	var t_max := Vector3(INF, INF, INF)
	for axis in 3:
		if absf(direction[axis]) > 0.000001:
			t_delta[axis] = absf(1.0 / direction[axis])
			var edge: float = float(cell[axis] + (1 if step[axis] > 0 else 0))
			t_max[axis] = (edge - origin[axis]) / direction[axis]
	var previous := cell
	var distance := 0.0
	while distance <= reach:
		if get_block(cell) != 0: return {"cell": cell, "previous": previous, "block": get_block(cell), "distance": distance}
		previous = cell
		var axis := 0
		if t_max.y < t_max.x: axis = 1
		if t_max.z < t_max[axis]: axis = 2
		distance = t_max[axis]
		cell[axis] += step[axis]
		t_max[axis] += t_delta[axis]
	return {}

func apply_changes(saved: Dictionary) -> void:
	changes.clear()
	for key in saved:
		var key_string := str(key)
		if not key_string.is_valid_int(): continue
		var index := int(key_string)
		var value: Variant = saved[key]
		if not (value is float or value is int): continue
		if index >= size * size and index < blocks.size() and is_finite(float(value)) and float(value) == int(value) and Blocks.valid_edit(int(value)):
			blocks[index] = int(value)
			changes[str(index)] = int(value)
			var cell := Vector3i(index % size, index / (size*size), (index / size) % size)
			if int(value) > 0 and Blocks.entries[int(value)]["emissive"]: emissive_cells[cell] = int(value)
			else: emissive_cells.erase(cell)

func update_local_lights(view_position: Vector3) -> void:
	var nearby: Array[Vector3i] = []
	for cell: Vector3i in emissive_cells:
		if Vector3(cell).distance_squared_to(view_position) < 24*24: nearby.append(cell)
	nearby.sort_custom(func(a: Vector3i,b: Vector3i): return Vector3(a).distance_squared_to(view_position) < Vector3(b).distance_squared_to(view_position))
	var count := mini(8,nearby.size())
	while light_pool.size() < count:
		var light := OmniLight3D.new()
		light.omni_range = 5
		light.light_energy = 0.85
		light.shadow_enabled = false
		add_child(light)
		light_pool.append(light)
	for i in light_pool.size():
		light_pool[i].visible = i < count
		if i < count:
			light_pool[i].position = Vector3(nearby[i]) + Vector3.ONE * 0.5
			light_pool[i].light_color = Blocks.COLORS[emissive_cells[nearby[i]]].lightened(0.25)
