extends Node3D

# One simplified patch per chunk; only displayed where full editable geometry is absent.
const Geometry = preload("res://scripts/box_geometry.gd")
const Blocks = preload("res://scripts/blocks.gd")
const City = preload("res://scripts/city_layout.gd")
const STEP := 4
var world: Node3D
var patches := {}
var dirty := {}
var city_buildings: Array[Dictionary] = []

func prepare(w: Node3D,progress: Callable) -> void:
	world = w
	if w.world_id == "city": city_buildings = City.buildings()
	for x in world.size/16:
		for z in world.size/16: build_patch(Vector2i(x,z))
		progress.call("Menyiapkan pemandangan jauh… %d%%" % int((x+1)*100.0/(world.size/16)))
		await get_tree().process_frame

func build_patch(key: Vector2i) -> void:
	if world.world_id == "city":
		build_city_patch(key)
		return
	var s := Geometry.start()
	for lx in range(0,16,STEP):
		for lz in range(0,16,STEP):
			var x := key.x*16+lx
			var z := key.y*16+lz
			var h: int = world.surface_height(x+STEP/2,z+STEP/2)
			var block: int = world.get_block(Vector3i(x+STEP/2,h,z+STEP/2))
			var canopy := h if block in [5,183] else 0
			if canopy > 0:
				while h>0 and world.get_block(Vector3i(x+STEP/2,h,z+STEP/2)) in [0,4,5,183]: h -= 1
				block = world.get_block(Vector3i(x+STEP/2,h,z+STEP/2))
			# Compatibility does not honor vertex_color_is_srgb; convert explicitly.
			var color: Color = Blocks.COLORS[block].srgb_to_linear()
			# Tile tops plus vertical skirts to adjacent samples: no transparent holes at the horizon.
			var side: Color = Blocks.COLORS[2].srgb_to_linear() if block == 1 else color.darkened(0.12)
			var center := Vector3(lx+STEP/2.0,(h+1)/2.0,lz+STEP/2.0)
			var extent := Vector3(STEP,h+1,STEP)
			for f in 6:
				for i in [0,2,1,0,3,2]:
					s.set_normal(Geometry.NORMALS[f])
					s.set_color(color if f == 2 else side)
					s.add_vertex(center+(Geometry.FACES[f][i]-Vector3.ONE*0.5)*extent)
			if canopy > 0:
				Geometry.box(s,Vector3(center.x,(h+canopy)/2.0,center.z),Vector3(0.8,canopy-h,0.8),Blocks.COLORS[4].srgb_to_linear())
				Geometry.box(s,Vector3(center.x,canopy-0.5,center.z),Vector3(3.8,3,3.8),Blocks.COLORS[5].srgb_to_linear())
	var patch: MeshInstance3D
	if patches.has(key): patch = patches[key]
	else:
		patch = MeshInstance3D.new()
		patch.position = Vector3(key.x*16,0,key.y*16)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)
		patches[key] = patch
	patch.mesh = s.commit()
	patch.visible = not world.chunks.has(key)
	dirty.erase(key)

func build_city_patch(key: Vector2i) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(Blocks.make_material())
	for lx in range(0,16,STEP):
		for lz in range(0,16,STEP):
			var x := key.x*16+lx
			var z := key.y*16+lz
			var h: int = world.surface_height(x+2,z+2)
			var top: int = world.get_block(Vector3i(x+2,h,z+2))
			var building := {}
			for item in city_buildings:
				if Rect2i(item["x"],item["z"],item["width"],item["depth"]).has_point(Vector2i(x+2,z+2)):
					building = item
					break
			city_face(surface,Vector3(lx,h,lz),Vector3(STEP,1,STEP),2,top)
			for f in [0,1,4,5]:
				var direction: Vector3 = Geometry.NORMALS[f]
				var nx := x+2+int(direction.x)*STEP
				var nz := z+2+int(direction.z)*STEP
				var neighbor: int = world.surface_height(nx,nz)+1 if nx>=0 and nx<world.size and nz>=0 and nz<world.size else 0
				if neighbor>=h+1: continue
				var y := neighbor
				while y<h+1:
					var block := top
					var end := h+1
					if not building.is_empty() and y>=13:
						var phase := (y-12)%6
						end = mini(h+1,y+1)
						block = Blocks.id("facade_warm" if building["style"] in [1,3] else "facade_blue") if phase in [2,3,4] else Blocks.id(["white_concrete","bricks","light_gray_concrete","smooth_sandstone","cyan_concrete"][building["style"]])
						if phase == 0: block = Blocks.id("gray_concrete")
					elif not building.is_empty(): end = mini(h+1,13); block = 3
					city_face(surface,Vector3(lx,y,lz),Vector3(STEP,end-y,STEP),f,block)
					y = end
	var patch: MeshInstance3D
	if patches.has(key): patch = patches[key]
	else:
		patch = MeshInstance3D.new()
		patch.position = Vector3(key.x*16,0,key.y*16)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)
		patches[key] = patch
	patch.mesh = surface.commit()
	patch.visible = not world.chunks.has(key)
	dirty.erase(key)

func city_face(surface: SurfaceTool,origin: Vector3,extent: Vector3,face: int,block: int) -> void:
	var tile := Blocks.tile_for(block,Vector3i(Geometry.NORMALS[face]))
	var uv := [Vector2(0,1),Vector2(0,0),Vector2(1,0),Vector2(1,1)]
	if face == 2: uv = [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
	var shade: float = [0.86,0.78,1.0,0.55,0.91,0.81][face]
	for i in [0,2,1,0,3,2]:
		surface.set_normal(Geometry.NORMALS[face])
		surface.set_color(Color(shade,shade,shade))
		surface.set_uv(Blocks.uv_for(tile,uv[i]))
		surface.add_vertex(origin+Geometry.FACES[face][i]*extent)

func mark_dirty(key: Vector2i) -> void:
	dirty[key] = true
	# City side faces depend on heights in adjacent patches, including samples
	# inset from a chunk boundary. Invalidate those dependencies after edits too.
	if world.world_id == "city":
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var neighbor: Vector2i = key+offset
			if neighbor.x>=0 and neighbor.y>=0 and neighbor.x<world.size/16 and neighbor.y<world.size/16:
				dirty[neighbor] = true

func hide_patch(key: Vector2i) -> void:
	if patches.has(key): patches[key].hide()

func show_patch(key: Vector2i) -> void:
	if dirty.has(key): build_patch(key)
	if patches.has(key): patches[key].show()
