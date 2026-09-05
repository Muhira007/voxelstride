extends RefCounted

const Blocks = preload("res://scripts/blocks.gd")
const GROUND := 13
const PENS := [
	{"species":"cow","name":"Sapi","rect":Rect2i(116,54,15,15),"count":5},
	{"species":"sheep","name":"Domba","rect":Rect2i(135,54,15,15),"count":5},
	{"species":"pig","name":"Babi","rect":Rect2i(116,73,15,15),"count":4},
	{"species":"chicken","name":"Ayam","rect":Rect2i(135,73,15,15),"count":6}
]
const HOMES := [Vector2i(71,107),Vector2i(71,123),Vector2i(71,139),Vector2i(108,111),Vector2i(126,111),Vector2i(126,133)]

static func put(w: Node3D, x: int, y: int, z: int, key: String) -> void:
	w._put(Vector3i(x,y,z),Blocks.id(key))

static func fill(w: Node3D, a: Vector3i, b: Vector3i, key: String) -> void:
	var block := Blocks.id(key)
	for x in range(a.x,b.x+1):
		for z in range(a.z,b.z+1):
			for y in range(a.y,b.y+1): w._put(Vector3i(x,y,z),block)

static func generate(w: Node3D) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = w.world_seed
	noise.frequency = 0.028
	for x in w.size:
		for z in w.size:
			var edge := maxf(absf(x-96),absf(z-96))
			var h := GROUND+roundi(noise.get_noise_2d(x,z)*7*smoothstep(67,93,edge))
			for y in h+1:
				w._put(Vector3i(x,y,z),9 if y == 0 else (1 if y == h else (2 if y>h-3 else 3)))
	# Roads connect every district; the southwest meadow stays open for the player.
	fill(w,Vector3i(95,13,29),Vector3i(98,13,166),"coarse_dirt")
	fill(w,Vector3i(39,13,96),Vector3i(157,13,99),"coarse_dirt")
	fill(w,Vector3i(110,13,47),Vector3i(153,13,50),"gravel")
	fill(w,Vector3i(110,13,49),Vector3i(112,13,99),"gravel")
	fill(w,Vector3i(132,13,50),Vector3i(133,13,92),"coarse_dirt")
	fill(w,Vector3i(112,13,70),Vector3i(152,13,71),"coarse_dirt")
	fill(w,Vector3i(84,13,100),Vector3i(86,13,153),"coarse_dirt")
	fill(w,Vector3i(99,13,124),Vector3i(145,13,126),"coarse_dirt")
	fill(w,Vector3i(88,13,89),Vector3i(107,13,108),"cobblestone")
	for i in HOMES.size():
		var p: Vector2i = HOMES[i]
		house(w,p,9,9,"birch_planks" if i%2 == 0 else "oak_planks","bricks" if i%3 == 0 else "spruce_planks")
		fill(w,Vector3i(p.x+3,13,p.y+9),Vector3i(p.x+5,13,p.y+11),"gravel")
		fill(w,Vector3i(mini(p.x+4,96),13,p.y+11),Vector3i(maxi(p.x+4,96),13,p.y+12),"coarse_dirt")
		for x in [p.x,p.x+1,p.x+7,p.x+8]:
			put(w,x,14,p.y+9,"meadow_flower")
		fill(w,Vector3i(p.x-2,14,p.y),Vector3i(p.x-2,14,p.y+5),"oak_leaves")
	# Four irrigated crop plots; clear row spacing keeps geometry modest.
	for i in 4:
		var ox := 49+(i%2)*20
		var oz := 54+(i/2)*20
		field(w,Vector2i(ox,oz),["wheat_crop","carrot_crop","potato_crop","pumpkin"][i])
	# Orchard, lumbung and village market.
	for x in [47,55,63,71,79]:
		for z in [36,44]: tree(w,x,z,true)
	house(w,Vector2i(117,32),20,12,"red_terracotta","spruce_planks")
	fill(w,Vector3i(121,14,35),Vector3i(125,15,39),"hay_bale")
	fill(w,Vector3i(120,13,44),Vector3i(130,13,49),"gravel")
	fill(w,Vector3i(125,14,43),Vector3i(128,17,43),"air")
	for x in [124,129]: fill(w,Vector3i(x,14,43),Vector3i(x,20,43),"stripped_birch_log")
	fill(w,Vector3i(124,20,43),Vector3i(129,20,43),"stripped_birch_log")
	house(w,Vector2i(146,104),7,8,"spruce_planks","deepslate_tiles")
	for pen in PENS: enclosure(w,pen)
	well(w)
	windmill(w)
	for x in [90,101]: stall(w,Vector2i(x,118),"red_wool" if x == 90 else "yellow_wool")
	# A shallow ornamental pond, with a walkable timber bridge (no swimming mechanics).
	for x in range(110,125):
		for z in range(147,164):
			var d := Vector2((x-117)/7.0,(z-155)/8.0).length()
			if d < 1:
				put(w,x,13,z,"water")
				put(w,x,12,z,"clay")
			elif d < 1.25: put(w,x,13,z,"sand")
	fill(w,Vector3i(116,14,145),Vector3i(118,14,165),"oak_planks")
	fill(w,Vector3i(95,13,164),Vector3i(118,13,166),"coarse_dirt")
	for z in range(146,166):
		put(w,115,15,z,"oak_fence")
		put(w,119,15,z,"oak_fence")
	# Fixed tree/flower placement, excluding all built districts and the open meadow.
	var rng := RandomNumberGenerator.new()
	rng.seed = w.world_seed+718
	for i in 140:
		var x := rng.randi_range(7,184)
		var z := rng.randi_range(7,184)
		if Rect2i(35,28,124,144).has_point(Vector2i(x,z)): continue
		tree(w,x,z,false)
	for p in [Vector2i(65,106),Vector2i(65,130),Vector2i(65,148),Vector2i(119,135),Vector2i(145,144),Vector2i(151,128),Vector2i(44,103),Vector2i(108,143),Vector2i(92,153),Vector2i(106,54)]:
		tree(w,p.x,p.y,false)
	# Low flower borders distinguish the village lanes from the empty building meadow.
	for z in range(31,91,4): put(w,93,14,z,"meadow_flower")
	for x in range(40,85,3): put(w,x,14,101,"meadow_flower")
	for p in [Vector2i(90,91),Vector2i(105,91),Vector2i(90,106),Vector2i(105,106)]:
		fill(w,Vector3i(p.x,13,p.y),Vector3i(p.x+1,13,p.y+1),"grass")
		put(w,p.x,14,p.y,"meadow_flower")
	for z in [36,57,79,113,138,158]:
		fill(w,Vector3i(100,14,z),Vector3i(100,17,z),"oak_fence")
		put(w,100,18,z,"sea_lantern")
		w.emissive_cells[Vector3i(100,18,z)] = Blocks.id("sea_lantern")

static func house(w: Node3D, p: Vector2i, width: int, depth: int, wall: String, roof: String) -> void:
	fill(w,Vector3i(p.x,13,p.y),Vector3i(p.x+width-1,13,p.y+depth-1),"stone_bricks")
	for x in range(p.x,p.x+width):
		for z in range(p.y,p.y+depth):
			for y in range(14,18):
				if x in [p.x,p.x+width-1] or z in [p.y,p.y+depth-1]:
					var key := "stone_bricks" if y == 14 else wall
					if x in [p.x,p.x+width-1] and z in [p.y,p.y+depth-1]: key = "oak_log"
					elif y in [15,16] and ((x-p.x)%4 == 2 or (z-p.y)%4 == 2): key = "glass"
					put(w,x,y,z,key)
	# Two-block high open doorway; interiors are accessible, not sealed models.
	fill(w,Vector3i(p.x+width/2,14,p.y+depth-1),Vector3i(p.x+width/2+1,16,p.y+depth-1),"air")
	for step in range((width+1)/2+1):
		var left := p.x-1+step
		var right := p.x+width-step
		fill(w,Vector3i(left,18+step,p.y-1),Vector3i(left,18+step,p.y+depth),roof)
		fill(w,Vector3i(right,18+step,p.y-1),Vector3i(right,18+step,p.y+depth),roof)
		if left+1<right:
			fill(w,Vector3i(left+1,18+step,p.y),Vector3i(right-1,18+step,p.y),wall)
			fill(w,Vector3i(left+1,18+step,p.y+depth-1),Vector3i(right-1,18+step,p.y+depth-1),wall)
	put(w,p.x+1,14,p.y+1,"oak_planks")
	put(w,p.x+2,14,p.y+1,"red_wool")
	put(w,p.x+width-2,14,p.y+2,"hay_bale")

static func field(w: Node3D, p: Vector2i, crop: String) -> void:
	fill(w,Vector3i(p.x-1,13,p.y-1),Vector3i(p.x+16,13,p.y+16),"oak_log")
	fill(w,Vector3i(p.x,13,p.y),Vector3i(p.x+15,13,p.y+15),"farm_soil")
	for x in range(p.x,p.x+16):
		for z in range(p.y,p.y+16):
			if (x-p.x)%4 == 0: put(w,x,13,z,"water")
			elif z%2 == 0 and (crop != "pumpkin" or x%2 == 0): put(w,x,14,z,crop)
	fill(w,Vector3i(p.x-1,14,p.y+7),Vector3i(p.x+16,14,p.y+7),"oak_planks")

static func enclosure(w: Node3D, pen: Dictionary) -> void:
	var r: Rect2i = pen["rect"]
	for x in range(r.position.x,r.end.x):
		for z in range(r.position.y,r.end.y):
			if x in [r.position.x,r.end.x-1] or z in [r.position.y,r.end.y-1]: put(w,x,14,z,"oak_fence")
	fill(w,Vector3i(r.position.x+2,14,r.position.y+2),Vector3i(r.position.x+5,14,r.position.y+2),"hay_bale")
	fill(w,Vector3i(r.end.x-5,13,r.position.y+2),Vector3i(r.end.x-2,13,r.position.y+2),"water")
	for x in [r.position.x+2,r.position.x+6]:
		fill(w,Vector3i(x,14,r.end.y-5),Vector3i(x,16,r.end.y-2),"air")
		fill(w,Vector3i(x,14,r.end.y-3),Vector3i(x,16,r.end.y-3),"oak_log")
	fill(w,Vector3i(r.position.x+1,17,r.end.y-6),Vector3i(r.position.x+7,17,r.end.y-2),"spruce_planks")

static func tree(w: Node3D, x: int, z: int, fruit: bool) -> void:
	var base: int = w.surface_height(x,z)
	if w.get_block(Vector3i(x,base,z)) != 1: return
	for y in range(base+3,base+6):
		for dx in range(-2,3):
			for dz in range(-2,3):
				if absi(dx)+absi(dz) < 4: put(w,x+dx,y,z+dz,"apple_leaves" if fruit else "oak_leaves")
	fill(w,Vector3i(x,base+1,z),Vector3i(x,base+4,z),"oak_log")

static func well(w: Node3D) -> void:
	fill(w,Vector3i(93,14,95),Vector3i(99,14,101),"stone_bricks")
	fill(w,Vector3i(95,14,97),Vector3i(97,14,99),"water")
	for x in [93,99]: fill(w,Vector3i(x,15,98),Vector3i(x,18,98),"oak_log")
	fill(w,Vector3i(92,19,94),Vector3i(100,19,102),"spruce_planks")
	fill(w,Vector3i(93,20,95),Vector3i(99,20,101),"spruce_planks")

static func windmill(w: Node3D) -> void:
	for y in range(14,29):
		var inset := 0 if y<21 else 1
		for x in range(85+inset,92-inset):
			for z in range(34+inset,41-inset):
				if x in [85+inset,91-inset] or z in [34+inset,40-inset]: put(w,x,y,z,"white_terracotta")
	fill(w,Vector3i(87,14,40),Vector3i(88,16,40),"air")
	fill(w,Vector3i(86,29,35),Vector3i(90,29,39),"spruce_planks")
	fill(w,Vector3i(87,30,36),Vector3i(89,30,38),"spruce_planks")
	# Four iconic sails, built from editable blocks.
	for i in range(-6,7):
		put(w,88+i,24,41,"oak_log")
		put(w,88,24+i,41,"oak_log")
		if abs(i)>1:
			put(w,88+i,25,41,"white_wool")
			put(w,89,24+i,41,"white_wool")

static func stall(w: Node3D, p: Vector2i, cloth: String) -> void:
	for x in [p.x,p.x+5]:
		for z in [p.y,p.y+3]: fill(w,Vector3i(x,14,z),Vector3i(x,16,z),"oak_fence")
	for x in range(p.x,p.x+6): fill(w,Vector3i(x,17,p.y),Vector3i(x,17,p.y+3),cloth if x%2 == 0 else "white_wool")
	fill(w,Vector3i(p.x+1,14,p.y+1),Vector3i(p.x+4,14,p.y+1),"oak_planks")
	put(w,p.x+1,15,p.y+1,"pumpkin")
	put(w,p.x+4,15,p.y+1,"hay_bale")
