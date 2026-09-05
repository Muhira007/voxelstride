extends RefCounted

const Blocks = preload("res://scripts/blocks.gd")
const Farm = preload("res://scripts/farm_layout.gd")
const OFFSET := Vector3i(96,7,96)
const FALL := Vector3(252,39,94)
const FALL_TOP := 56
const FALL_BOTTOM := 21
const POOL := Vector2(252,111)
const LANDMARKS := [
	["DESA LEMBAH",Vector2i(192,208)],
	["AIR TERJUN UTARA",Vector2i(231,112)],
	["JALUR PUNCAK",Vector2i(216,62)],
	["KEBUN BERTINGKAT",Vector2i(101,173)],
	["PONDOK HUTAN",Vector2i(80,242)],
	["DANAU SELATAN",Vector2i(290,349)],
	["MENARA PANDANG",Vector2i(325,222)]
]

# Isolated copy buffer: existing farm generator is reused without changing either old world.
class FarmStamp extends Node3D:
	var size := 192
	var world_seed := 20260905
	var blocks := PackedByteArray()
	var emissive_cells := {}
	func _init(seed_value: int) -> void:
		world_seed = seed_value
		blocks.resize(192*192*40)
	func _put(p: Vector3i, block: int) -> void:
		if p.x>=0 and p.x<192 and p.z>=0 and p.z<192 and p.y>=0 and p.y<40: blocks[p.x+192*(p.z+192*p.y)] = block
	func get_block(p: Vector3i) -> int:
		if p.x<0 or p.x>=192 or p.z<0 or p.z>=192 or p.y<0 or p.y>=40: return 0
		return blocks[p.x+192*(p.z+192*p.y)]
	func surface_height(x: int,z: int) -> int:
		for y in range(39,-1,-1):
			if get_block(Vector3i(x,y,z)) != 0: return y
		return 0

static func noise_for(seed_value: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.024
	noise.fractal_octaves = 3
	return noise

static func ground_height(x: int,z: int,noise: FastNoiseLite) -> int:
	var n := noise.get_noise_2d(x,z)
	var north := 35.0*(1.0-smoothstep(60,123,z))
	var west := 23.0*(1.0-smoothstep(55,130,x))
	var east := 30.0*smoothstep(268,335,x)
	var south := 10.0*smoothstep(288,367,z)
	var hills := maxf(maxf(north,west),maxf(east,south))
	var h := 20.0+hills+n*(2.0+hills*0.23)
	# Blend into the village pad, no cliff at a rectangular stamp boundary.
	var distance := Vector2(maxf(maxf(130-x,x-255),0),maxf(maxf(124-z,z-270),0)).length()
	h = lerpf(20,h,smoothstep(0,24,distance))
	var shelf := (1.0-smoothstep(11,30,absf(x-252)))*(1.0-smoothstep(92,112,z))
	h = lerpf(h,maxf(h,55),shelf)
	return clampi(roundi(h),8,70)

static func generate(w: Node3D) -> void:
	var noise := noise_for(w.world_seed)
	base_columns(w,noise,0,w.size)
	features(w)

static func generate_async(w: Node3D,progress: Callable) -> void:
	var noise := noise_for(w.world_seed)
	for x in range(0,w.size,12):
		base_columns(w,noise,x,mini(x+12,w.size))
		progress.call("Membentuk bukit dan lembah… %d%%" % int((x+12)*100.0/w.size))
		await w.get_tree().process_frame
	progress.call("Menata desa, sungai, kebun, dan jalur…")
	await w.get_tree().process_frame
	features(w)
	await w.get_tree().process_frame

static func base_columns(w: Node3D,noise: FastNoiseLite,start: int,end: int) -> void:
	for x in range(start,end):
		for z in w.size:
			var h := ground_height(x,z,noise)
			for y in h+1:
				w.blocks[x+w.size*(z+w.size*y)] = 9 if y == 0 else (1 if y == h else (2 if y>=h-3 else 3))

static func river_x(z: int) -> float:
	return 252+18*sin((z-110)*0.018)+0.12*(z-110)

static func features(w: Node3D) -> void:
	var stamp := FarmStamp.new(w.world_seed)
	Farm.generate(stamp)
	for x in range(35,160):
		for z in range(28,172):
			for y in range(13,40):
				var block := stamp.get_block(Vector3i(x,y,z))
				if block != 0: w._put(Vector3i(x,y,z)+OFFSET,block)
	for cell: Vector3i in stamp.emissive_cells: w.emissive_cells[cell+OFFSET] = stamp.emissive_cells[cell]
	stamp.free()
	# River carved independently of the village, broad banks and a shallow bed throughout.
	for z in range(108,364):
		var cx := roundi(river_x(z))
		for x in range(cx-7,cx+8):
			var edge := absi(x-cx)
			if edge<=4: carve_water(w,x,z,20,18)
			else: column(w,x,z,20+(edge-5),"sand" if edge == 5 else "grass")
	for x in range(236,269):
		for z in range(98,128):
			var d := Vector2((x-252)/15.0,(z-112)/13.0).length()
			if d<1: carve_water(w,x,z,20,18)
			elif d<1.15: column(w,x,z,21,"gravel")
	# Open the pool's gravel rim where the downstream river exits.
	for z in range(116,131):
		for x in range(roundi(river_x(z))-3,roundi(river_x(z))+4): carve_water(w,x,z,20,18)
	for x in range(256,329):
		for z in range(291,364):
			var d := Vector2((x-292)/19.0,(z-327)/18.0).length()
			if d<1: carve_water(w,x,z,20,18)
			elif d<1.75:
				var natural: int = w.surface_height(x,z)
				if w.get_block(Vector3i(x,natural,z)) == Blocks.id("water"): continue
				var shore := roundi(lerpf(21,natural,smoothstep(1.12,1.75,d)))
				column(w,x,z,shore,"sand" if d<1.12 else "grass")
	# Join the southern lake to the river, including a low walkable shoreline.
	for x in range(roundi(river_x(327)),293):
		for z in range(324,331): carve_water(w,x,z,20,18)
	# Source channel ends in one prominent 35-block drop, backed by stone.
	for x in range(247,257):
		for z in range(59,94): carve_water(w,x,z,55,53)
	for x in range(246,259):
		for y in range(21,56): Farm.put(w,x,y,93,"stone")
	for x in range(247,257): Farm.put(w,x,55,93,"water")
	# Clear splash apron and maintain contiguous water between cliff and pool.
	for x in range(247,257):
		for z in range(94,111): carve_water(w,x,z,20,18)
	# Terraced crops in the western foothills, connected by a stepped walking path.
	for i in 3:
		var x := 96-i*14
		var h := 23+i*4
		for xx in range(x,x+12):
			for z in range(150,185):
				column(w,xx,z,h,"farm_soil")
				if xx == x+2: Farm.put(w,xx,h,z,"water")
				elif z%2 == 0: Farm.put(w,xx,h+1,z,["wheat_crop","carrot_crop","potato_crop"][i])
	# Continuous graded trails; each sample changes elevation by at most one voxel.
	trail(w,[Vector2i(201,193),Vector2i(228,193),Vector2i(228,147),Vector2i(236,147),Vector2i(236,117),Vector2i(230,108)])
	trail(w,[Vector2i(236,147),Vector2i(238,124),Vector2i(222,117),Vector2i(209,105),Vector2i(198,85),Vector2i(216,62),Vector2i(241,64)])
	trail(w,[Vector2i(145,193),Vector2i(106,193),Vector2i(88,191),Vector2i(73,188),Vector2i(64,181)])
	trail(w,[Vector2i(181,249),Vector2i(163,253),Vector2i(139,253),Vector2i(103,242),Vector2i(80,242)])
	trail(w,[Vector2i(192,262),Vector2i(235,281),Vector2i(262,292),Vector2i(282,292),Vector2i(312,303),Vector2i(317,326),Vector2i(310,349),Vector2i(280,349),Vector2i(280,347)])
	trail(w,[Vector2i(240,193),Vector2i(267,204),Vector2i(294,204),Vector2i(307,222),Vector2i(325,222)])
	bridge(w,Vector2i(roundi(river_x(204)),204),20)
	bridge(w,Vector2i(roundi(river_x(292)),292),20)
	# Cabin and lookout destinations use local ground elevations.
	building(w,Vector2i(76,233),9,8,false)
	building(w,Vector2i(323,207),8,8,true)
	# Forest belts, respecting paths and water; never stamp over the village or terraces.
	var rng := RandomNumberGenerator.new()
	rng.seed = w.world_seed+2027
	for i in 1200:
		var x := rng.randi_range(8,375)
		var z := rng.randi_range(8,375)
		if Rect2i(124,120,138,152).has_point(Vector2i(x,z)) or Rect2i(58,140,59,57).has_point(Vector2i(x,z)): continue
		if x>232 and x<272 and z<110: continue
		if x>123 and x<263 and z>276: continue # open southern pasture
		if rng.randf()>0.64 and z>100: continue
		var y: int = w.surface_height(x,z)
		if y>64 or w.get_block(Vector3i(x,y,z))!=1: continue
		var clear := true
		for dx in range(-3,4):
			for dz in range(-3,4):
				var top: int = w.get_block(Vector3i(x+dx,w.surface_height(x+dx,z+dz),z+dz))
				if top not in [1,2,3]: clear = false
		if clear: Farm.tree(w,x,z,false)

static func column(w: Node3D,x: int,z: int,h: int,key: String) -> void:
	var top := Blocks.id(key)
	for y in range(1,w.height): w._put(Vector3i(x,y,z),0 if y>h else (top if y==h else (2 if y>h-3 else 3)))

static func carve_water(w: Node3D,x: int,z: int,level: int,bed: int) -> void:
	column(w,x,z,bed,"clay")
	for y in range(bed+1,level+1): Farm.put(w,x,y,z,"water")

static func trail(w: Node3D,points: Array) -> void:
	# Sample before carving: otherwise the previous 3-wide stamp flattens the next sample
	# and turns an uphill path into a deep trench.
	var samples: Array[Vector2i] = []
	var heights: Array[int] = []
	for i in range(points.size()-1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i+1]
		var steps := ceili(a.distance_to(b))
		for j in steps+1:
			var p := Vector2i(a.lerp(b,float(j)/maxi(steps,1)).round())
			if not samples.is_empty() and samples.back() == p: continue
			samples.append(p)
			heights.append(w.surface_height(p.x,p.y))
	for i in range(1,heights.size()): heights[i] = clampi(heights[i],heights[i-1]-1,heights[i-1]+1)
	for i in samples.size():
		var p := samples[i]
		var h := heights[i]
		for dx in range(-1,2):
			for dz in range(-1,2):
				var x := p.x+dx
				var z := p.y+dz
				var top: int = w.surface_height(x,z)
				if w.get_block(Vector3i(x,top,z)) != Blocks.id("water"): column(w,x,z,h,"coarse_dirt")

static func bridge(w: Node3D,p: Vector2i,level: int) -> void:
	for x in range(p.x-9,p.x+10):
		for z in range(p.y-1,p.y+2): Farm.put(w,x,level+1,z,"oak_planks")
		for z in [p.y-2,p.y+2]: Farm.put(w,x,level+2,z,"oak_fence")

static func building(w: Node3D,p: Vector2i,width: int,depth: int,tower: bool) -> void:
	var h: int = w.surface_height(p.x+(2 if tower else 4),p.y+depth+(7 if tower else 1))
	for x in range(p.x-2,p.x+width+2):
		for z in range(p.y-2,p.y+depth+(8 if tower else 2)): column(w,x,z,h,"gravel")
	if not tower:
		for x in range(p.x,p.x+width):
			for z in range(p.y,p.y+depth):
				for y in range(h+1,h+5):
					if x in [p.x,p.x+width-1] or z in [p.y,p.y+depth-1]: Farm.put(w,x,y,z,"oak_log" if x in [p.x,p.x+width-1] else "spruce_planks")
		Farm.fill(w,Vector3i(p.x+3,h+1,p.y+depth-1),Vector3i(p.x+4,h+3,p.y+depth-1),"air")
		for i in 5:
			for x in [p.x-1+i,p.x+width-i]: Farm.fill(w,Vector3i(x,h+5+i,p.y-1),Vector3i(x,h+5+i,p.y+depth),"spruce_planks")
	else:
		for x in [p.x,p.x+width-1]:
			for z in [p.y,p.y+depth-1]: Farm.fill(w,Vector3i(x,h+1,z),Vector3i(x,h+8,z),"oak_log")
		Farm.fill(w,Vector3i(p.x,h+8,p.y),Vector3i(p.x+width-1,h+8,p.y+depth-1),"oak_planks")
		for i in 8:
			Farm.put(w,p.x+2,h+1+i,p.y+depth+6-i,"oak_planks")
			Farm.put(w,p.x+3,h+1+i,p.y+depth+6-i,"oak_planks")
		for x in range(p.x,p.x+width):
			for z in [p.y,p.y+depth-1]:
				if z == p.y+depth-1 and x in [p.x+2,p.x+3]: continue
				Farm.put(w,x,h+9,z,"oak_fence")
		for z in range(p.y+1,p.y+depth-1):
			for x in [p.x,p.x+width-1]: Farm.put(w,x,h+9,z,"oak_fence")
