extends RefCounted

const Blocks = preload("res://scripts/blocks.gd")
const Farm = preload("res://scripts/farm_layout.gd")
const GROUND := 12
const ROADS := [48,120,192,264,336]
const LANDMARKS := [
	["TAMAN HARMONI",Vector3(207,13,227)],
	["MENARA CAKRAWALA",Vector3(146,13,164)],
	["GALERI KOTA",Vector3(213,13,162)],
	["TERMINAL UTARA",Vector3(288,13,100)],
	["PASAR BOULEVARD",Vector3(81,13,233)],
	["BALAI KOTA",Vector3(151,13,305)],
	["APARTEMEN TIMUR",Vector3(285,13,232)],
	["DEPOT LOGISTIK",Vector3(287,13,305)]
]

static func road_distance(value: int) -> int:
	var distance := 1000
	for road in ROADS: distance = mini(distance,absi(value-road))
	return distance

static func generate(w: Node3D) -> void:
	base(w,0,w.size)
	for item in buildings(): building(w,item)
	features(w)

static func generate_async(w: Node3D,progress: Callable) -> void:
	for x in range(0,w.size,16):
		base(w,x,x+16)
		progress.call("Membentangkan boulevard dan trotoar… %d%%" % int((x+16)*100.0/w.size))
		await w.get_tree().process_frame
	var list := buildings()
	for i in list.size():
		building(w,list[i])
		progress.call("Membangun distrik kota… %d / %d" % [i+1,list.size()])
		await w.get_tree().process_frame
	progress.call("Menata taman, terminal, dan fasilitas jalan…")
	features(w)
	await w.get_tree().process_frame

static func base(w: Node3D,start: int,end: int) -> void:
	var asphalt := Blocks.id("asphalt")
	var paving := Blocks.id("city_paving")
	var white := Blocks.id("road_white")
	var yellow := Blocks.id("road_yellow")
	for x in range(start,end):
		var dx := road_distance(x)
		for z in w.size:
			var dz := road_distance(z)
			var distance := mini(dx,dz)
			var top := 1
			if distance<=6:
				top = asphalt
				if (dx == 0 and dz>10 and z%8<4) or (dz == 0 and dx>10 and x%8<4): top = yellow
				if (dx == 6 and dz>10) or (dz == 6 and dx>10): top = white
				# Four zebra crossings around every junction, leaving the driving lanes connected.
				if (dx<=5 and dz in [8,9,10] and x%2 == 0) or (dz<=5 and dx in [8,9,10] and z%2 == 0): top = white
			elif distance<=10: top = paving
			for y in GROUND+1:
				w.blocks[x+w.size*(z+w.size*y)] = 9 if y == 0 else (top if y == GROUND else (2 if y>GROUND-3 else 3))

static func descriptor(x: int,z: int,width: int,depth: int,floors: int,style: int,name: String = "") -> Dictionary:
	return {"x":x,"z":z,"width":width,"depth":depth,"floors":floors,"style":style,"name":name}

static func buildings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ix in 4:
		for iz in 4:
			var x := 62+ix*72
			var z := 62+iz*72
			if Vector2i(ix,iz) in [Vector2i(2,2),Vector2i(3,0),Vector2i(0,3)]: continue
			if Vector2i(ix,iz) == Vector2i(1,1):
				result.append(descriptor(x,z,26,28,9,0,"MENARA CAKRAWALA"))
				result.append(descriptor(x+31,z+5,14,23,5,1))
			elif Vector2i(ix,iz) == Vector2i(2,1):
				result.append(descriptor(x,z,25,26,7,2,"GALERI KOTA"))
				result.append(descriptor(x+30,z+6,14,22,4,0))
			elif Vector2i(ix,iz) == Vector2i(1,3):
				result.append(descriptor(x+2,z+2,36,24,3,3,"BALAI KOTA"))
			elif Vector2i(ix,iz) == Vector2i(3,3):
				result.append(descriptor(x+2,z+2,35,22,1,4,"DEPOT LOGISTIK"))
			else:
				var floors := 3+posmod(ix*7+iz*3,4)
				if ix == 0: floors = 2 if iz == 2 else 3
				result.append(descriptor(x,z,20,25,floors,posmod(ix+iz,5)))
				result.append(descriptor(x+25,z+4,19,21,maxi(2,floors-1),posmod(ix+iz+2,5)))
	# Low-rise neighborhood around the complete 384-block map, beyond the inner grid.
	for i in 4:
		result.append(descriptor(12,70+i*72,19,23,2,i%5))
		result.append(descriptor(350,70+i*72,20,23,2,(i+2)%5))
		result.append(descriptor(70+i*72,12,25,19,2,(i+1)%5))
		result.append(descriptor(70+i*72,350,25,19,2,(i+3)%5))
	return result

static func building(w: Node3D,item: Dictionary) -> void:
	var x: int = item["x"]
	var z: int = item["z"]
	var width: int = item["width"]
	var depth: int = item["depth"]
	var floors: int = item["floors"]
	var style: int = item["style"]
	var roof := GROUND+floors*6
	var wall := Blocks.id(["white_concrete","bricks","light_gray_concrete","smooth_sandstone","cyan_concrete"][style])
	var trim := Blocks.id("gray_concrete" if style in [0,2] else "smooth_quartz")
	var window := Blocks.id("facade_warm" if style in [1,3] else "facade_blue")
	Farm.fill(w,Vector3i(x-2,GROUND,z-2),Vector3i(x+width+1,GROUND,z+depth+2),"city_paving")
	for y in range(GROUND+1,roof):
		for xx in range(x,x+width):
			for zz in range(z,z+depth):
				var boundary := xx in [x,x+width-1] or zz in [z,z+depth-1]
				if not boundary and (y-GROUND)%6 != 0: continue
				var block := trim if (y-GROUND)%6 == 0 else wall
				if boundary and (y-GROUND)%6 in [2,3,4]:
					if (xx>x and xx<x+width-1 and (xx-x)%4 != 0) or (zz>z and zz<z+depth-1 and (zz-z)%4 != 0): block = window
				w._put(Vector3i(xx,y,zz),block)
	Farm.fill(w,Vector3i(x,roof,z),Vector3i(x+width-1,roof,z+depth-1),"light_gray_concrete")
	# Open ground-floor lobby, with a continuous two-wide staircase to the roof.
	var door := x+width/2
	Farm.fill(w,Vector3i(door-1,GROUND+1,z+depth-1),Vector3i(door+1,GROUND+3,z+depth-1),"air")
	Farm.fill(w,Vector3i(door-2,GROUND+4,z+depth),Vector3i(door+2,GROUND+4,z+depth+1),"gray_concrete")
	Farm.fill(w,Vector3i(x+2,GROUND+1,z+3),Vector3i(x+2,GROUND+1,z+7),"oak_planks")
	for floor_index in floors:
		var by := GROUND+floor_index*6
		var reverse := floor_index%2 == 1
		var sx := x+5 if reverse else x+2
		for step in 6:
			var zz := z+3+(5-step if reverse else step)
			# Clear the slab above each step for a standing player's headroom.
			Farm.fill(w,Vector3i(sx,by+step+2,zz),Vector3i(sx+1,mini(roof+1,by+step+4),zz),"air")
			Farm.fill(w,Vector3i(sx,by+step+1,zz),Vector3i(sx+1,by+step+1,zz),"smooth_stone")
		var landing_z := z+2 if reverse else z+9
		Farm.fill(w,Vector3i(x+2,by+6,landing_z),Vector3i(x+6,by+6,landing_z),"smooth_stone")
	# Parapet and rooftop plant room leave the staircase exit open.
	for xx in range(x,x+width):
		for zz in [z,z+depth-1]: w._put(Vector3i(xx,roof+1,zz),trim)
	for zz in range(z+1,z+depth-1):
		for xx in [x,x+width-1]: w._put(Vector3i(xx,roof+1,zz),trim)
	Farm.fill(w,Vector3i(x+width-7,roof+1,z+4),Vector3i(x+width-3,roof+2,z+8),"roof_vent")
	if floors>=7: Farm.fill(w,Vector3i(x+width-4,roof+3,z+6),Vector3i(x+width-4,roof+7,z+6),"iron_block")
	# Walkway from every entrance to the closest horizontal avenue.
	var road_z := 48
	for road in ROADS:
		if absi(road-(z+depth))<absi(road_z-(z+depth)): road_z = road
	for zz in range(mini(z+depth,road_z),maxi(z+depth,road_z)+1):
		if road_distance(zz)<=6: continue
		for xx in range(door-1,door+2): Farm.put(w,xx,GROUND,zz,"city_paving")

static func features(w: Node3D) -> void:
	# Central park: cross paths, low planting beds, benches and a shallow fountain.
	park(w,Vector2i(204,204),48)
	park(w,Vector2i(62,278),44)
	# Terminal and bus bays; parked vehicles are separate collision objects.
	Farm.fill(w,Vector3i(278,GROUND,62),Vector3i(324,GROUND,108),"asphalt")
	for x in range(280,323,8):
		Farm.fill(w,Vector3i(x,GROUND,70),Vector3i(x,GROUND,86),"road_white")
	Farm.fill(w,Vector3i(280,GROUND,93),Vector3i(322,GROUND,105),"city_paving")
	for x in [281,301,321]: Farm.fill(w,Vector3i(x,13,96),Vector3i(x,17,96),"iron_block")
	Farm.fill(w,Vector3i(279,18,94),Vector3i(323,18,101),"cyan_concrete")
	for x in range(284,319,8): Farm.fill(w,Vector3i(x,13,97),Vector3i(x+3,13,97),"oak_planks")
	# City furniture and intersections: no lamps/posts in the carriageway.
	for road in ROADS:
		for offset in range(22,369,24):
			if road_distance(offset)<14: continue
			for p in [Vector2i(road+9,offset),Vector2i(offset,road-9)]:
				Farm.fill(w,Vector3i(p.x,13,p.y),Vector3i(p.x,16,p.y),"iron_block")
				Farm.put(w,p.x,17,p.y,"sea_lantern")
				w.emissive_cells[Vector3i(p.x,17,p.y)] = Blocks.id("sea_lantern")
		for cross in ROADS:
			Farm.fill(w,Vector3i(road+8,13,cross+8),Vector3i(road+8,16,cross+8),"gray_concrete")
			Farm.put(w,road+8,17,cross+8,"red_concrete")
			Farm.put(w,road+8,16,cross+8,"yellow_concrete")
	# Street trees are sparse and kept away from entrances and junctions.
	for x in range(18,374,24):
		for z in [28,376]:
			if road_distance(x)>13: Farm.tree(w,x,z,false)
	for z in range(22,375,25):
		for x in [5,378]:
			if road_distance(z)>13: Farm.tree(w,x,z,false)
	# Shop awnings on the west district, using existing editable materials.
	for x in [66,91]:
		Farm.fill(w,Vector3i(x,17,231),Vector3i(x+10,17,233),"red_wool" if x == 66 else "yellow_wool")

static func park(w: Node3D,p: Vector2i,width: int) -> void:
	var center := p+Vector2i(width/2,width/2)
	for x in range(p.x,p.x+width):
		for z in range(p.y,p.y+width):
			if absi(x-center.x)<=2 or absi(z-center.y)<=2 or x in [p.x,p.x+width-1] or z in [p.y,p.y+width-1]: Farm.put(w,x,GROUND,z,"city_paving")
	for x in range(center.x-6,center.x+7):
		for z in range(center.y-6,center.y+7):
			if maxi(absi(x-center.x),absi(z-center.y)) == 6: Farm.put(w,x,13,z,"smooth_quartz")
			else: Farm.put(w,x,12,z,"water")
	Farm.fill(w,Vector3i(center.x,13,center.y),Vector3i(center.x,16,center.y),"quartz_pillar")
	for dx in [-14,14]:
		for dz in [-14,14]:
			Farm.tree(w,center.x+dx,center.y+dz,false)
			for x in range(center.x+dx-3,center.x+dx+4): Farm.put(w,x,13,center.y+dz+4,"meadow_flower")
	for dz in [-10,10]:
		Farm.fill(w,Vector3i(center.x-4,13,center.y+dz),Vector3i(center.x+3,13,center.y+dz),"oak_planks")
		Farm.fill(w,Vector3i(center.x-4,14,center.y+dz+1),Vector3i(center.x+3,14,center.y+dz+1),"oak_planks")
