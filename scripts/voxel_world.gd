extends Node3D

const Blocks = preload("res://scripts/blocks.gd")
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

func _init() -> void:
	Blocks.setup()
	blocks.resize(SIZE * HEIGHT * SIZE)

func inside(p: Vector3i) -> bool:
	return p.x >= 0 and p.x < SIZE and p.z >= 0 and p.z < SIZE and p.y >= 0 and p.y < HEIGHT

func index_of(p: Vector3i) -> int:
	return p.x + SIZE * (p.z + SIZE * p.y)

func get_block(p: Vector3i) -> int:
	return blocks[index_of(p)] if inside(p) else 0

func _put(p: Vector3i, block: int) -> void:
	if inside(p): blocks[index_of(p)] = block

func generate(seed_value: int) -> void:
	world_seed = seed_value
	blocks.fill(0)
	changes.clear()
	emissive_cells.clear()
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
	for y in range(HEIGHT - 1, -1, -1):
		if get_block(Vector3i(x,y,z)) != 0: return y
	return 0

func spawn_position() -> Vector3:
	return Vector3(SIZE / 2.0 + 0.5, surface_height(SIZE / 2, SIZE / 2) + 2.1, SIZE / 2.0 + 0.5)

func set_block(p: Vector3i, block: int) -> bool:
	if not inside(p) or p.y == 0 or not Blocks.valid_edit(block) or get_block(p) == block: return false
	_put(p, block)
	if block > 0 and Blocks.entries[block]["emissive"]: emissive_cells[p] = block
	else: emissive_cells.erase(p)
	changes[str(index_of(p))] = block
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
	if key.x < 0 or key.y < 0 or key.x >= SIZE / CHUNK or key.y >= SIZE / CHUNK: return
	if not dirty_chunks.has(key): dirty_chunks.append(key)

func _process(_delta: float) -> void:
	if not dirty_chunks.is_empty(): build_chunk(dirty_chunks.pop_front())

func build_chunk(key: Vector2i) -> void:
	if material == null: material = Blocks.make_material()
	var groups: Array = []
	for group in 2: groups.append([PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedColorArray()])
	var collision := PackedVector3Array()
	var origin := Vector3i(key.x * CHUNK, 0, key.y * CHUNK)
	for lx in CHUNK:
		for lz in CHUNK:
			for y in HEIGHT:
				var p := origin + Vector3i(lx,y,lz)
				var block := get_block(p)
				if block == 0: continue
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
						collision.append(vertex)
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
	if collision.is_empty():
		mesh_node.mesh = null
		collider.shape = null
		return
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
	mesh_node.mesh = mesh
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision)
	collider.shape = shape

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
		if index >= SIZE * SIZE and index < blocks.size() and is_finite(float(value)) and float(value) == int(value) and Blocks.valid_edit(int(value)):
			blocks[index] = int(value)
			changes[str(index)] = int(value)
			var cell := Vector3i(index % SIZE, index / (SIZE*SIZE), (index / SIZE) % SIZE)
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
