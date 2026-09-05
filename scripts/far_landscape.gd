extends Node3D

# One simplified patch per chunk; only displayed where full editable geometry is absent.
const Geometry = preload("res://scripts/box_geometry.gd")
const Blocks = preload("res://scripts/blocks.gd")
const STEP := 4
var world: Node3D
var patches := {}
var dirty := {}

func prepare(w: Node3D,progress: Callable) -> void:
	world = w
	for x in world.size/16:
		for z in world.size/16: build_patch(Vector2i(x,z))
		progress.call("Menyiapkan pemandangan jauh… %d%%" % int((x+1)*100.0/(world.size/16)))
		await get_tree().process_frame

func build_patch(key: Vector2i) -> void:
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

func mark_dirty(key: Vector2i) -> void:
	dirty[key] = true

func hide_patch(key: Vector2i) -> void:
	if patches.has(key): patches[key].hide()

func show_patch(key: Vector2i) -> void:
	if dirty.has(key): build_patch(key)
	if patches.has(key): patches[key].show()
