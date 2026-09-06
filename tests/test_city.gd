extends SceneTree

const World = preload("res://scripts/voxel_world.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Layout = preload("res://scripts/city_layout.gd")
const Traffic = preload("res://scripts/city_traffic.gd")
const Player = preload("res://scripts/player.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Picker = preload("res://scripts/world_picker.gd")
const Store = preload("res://scripts/save_store.gd")
const Far = preload("res://scripts/far_landscape.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CITY FAIL: "+label)

func run() -> void:
	var city := World.new()
	city.configure("city")
	root.add_child(city)
	city.set_process(false)
	city.generate(20260905)
	check(city.size == 384 and city.height == 80 and city.generator_version == 4,"384 x 384 city has independent generator and height")
	check(city.blocks.size() == 384*384*80 and city.changes.is_empty(),"city data fits byte storage without saved generated edits")
	var generated := city.blocks.duplicate()
	var updates := []
	await city.generate_city_async(20260905,func(message: String): updates.append(message))
	check(generated == city.blocks,"async and sync city generation are byte-identical")
	check(updates.size()>=60,"city loading yields between terrain strips and buildings")
	check(Blocks.id("meadow_flower") == 188 and Blocks.id("asphalt") == 189,"released block IDs are unchanged")
	for key in ["asphalt","city_paving","road_white","road_yellow","facade_blue","facade_warm","roof_vent"]:
		check(city.blocks.has(Blocks.id(key)) and Blocks.is_solid(Blocks.id(key)),"city uses solid new material "+key)
	check(not Blocks.is_transparent(Blocks.id("facade_blue")),"facade panels avoid transparent multilayer rendering")
	for road in Layout.ROADS:
		var clear := true
		for step in range(1,383):
			for y in range(13,17):
				if city.get_block(Vector3i(road,y,step)) != 0 or city.get_block(Vector3i(step,y,road)) != 0: clear = false
		check(clear,"avenue %d traverses the full map with headroom" % road)
	check(city.surface_height(150,150)>60,"central tower creates a tall skyline")
	check(city.get_block(Vector3i(228,12,227)) == Blocks.id("water"),"park fountain is present")
	check(city.get_block(Vector3i(301,18,96)) == Blocks.id("cyan_concrete"),"terminal canopy present")
	var list := Layout.buildings()
	check(list.size()>=35,"city has many distinct accessible buildings")
	for building in list:
		var door := Vector3i(building["x"]+building["width"]/2,13,building["z"]+building["depth"]-1)
		check(city.get_block(door) == 0 and city.get_block(door+Vector3i.UP) == 0 and Blocks.is_solid(city.get_block(door+Vector3i.DOWN)),"open supported entrance at %s" % door)
	# Verify every stair step and its landing, including the nine-floor tower roof exit.
	var stair_ok := true
	for building in list:
		for floor_index in building["floors"]:
			var reverse: bool = floor_index%2 == 1
			var x: int = building["x"]+(5 if reverse else 2)
			for step in 6:
				var p := Vector3i(x,12+floor_index*6+step+1,building["z"]+3+(5-step if reverse else step))
				if not Blocks.is_solid(city.get_block(p)) or Blocks.is_solid(city.get_block(p+Vector3i.UP)) or Blocks.is_solid(city.get_block(p+Vector3i.UP*2)): stair_ok = false
	check(stair_ok,"stairs provide solid steps and two-block headroom all the way to roofs")
	var far := Far.new()
	city.add_child(far)
	far.world = city
	city.far_landscape = far
	city.set_block(Vector3i(18,74,18),3)
	check(far.dirty.size() == 5 and far.dirty.has(Vector2i(0,1)) and far.dirty.has(Vector2i(2,1)) and far.dirty.has(Vector2i(1,0)) and far.dirty.has(Vector2i(1,2)),"city edits invalidate adjacent far-face height dependencies")
	far.dirty.clear()
	city.set_block(Vector3i(2,74,2),3)
	check(far.dirty.size() == 3 and far.dirty.has(Vector2i.ZERO) and far.dirty.has(Vector2i(1,0)) and far.dirty.has(Vector2i(0,1)),"far dependency invalidation stays inside world boundaries")
	city.set_block(Vector3i(18,74,18),0)
	city.set_block(Vector3i(2,74,2),0)
	city.far_landscape = null
	far.queue_free()
	var player := Player.new()
	player.world = city
	root.add_child(player)
	player.position = city.spawn_position()
	var traffic := Traffic.new()
	root.add_child(traffic)
	traffic.populate(city,player)
	check(traffic.vehicles.size() == 22 and traffic.snapshot().size() == 10,"ten moving and twelve parked vehicles")
	var counts := {"car":0,"bus":0,"van":0}
	for car in traffic.vehicles: counts[car.kind] += 1
	check(counts == {"car":12,"bus":5,"van":5},"cars buses and commercial vans are populated")
	for route in 2:
		var car: CharacterBody3D = traffic.vehicles[2 if route == 0 else 7]
		var old: float = car.distance
		var clear := true
		# Sample a bus-sized envelope around the entire ring, not just spawn points.
		for d in range(0,int(Traffic.perimeter(route)),4):
			car.distance = float(d)
			traffic.place(car)
			var direction := (Traffic.point(route,d+0.5)-car.position).normalized()
			var box: AABB = car.bounds(car.position).grow(0.18)
			for x in range(floori(box.position.x),ceili(box.end.x)):
				for z in range(floori(box.position.z),ceili(box.end.z)):
					if not Blocks.is_solid(city.get_block(Vector3i(x,12,z))): clear = false
					for y in range(13,16):
						if Blocks.is_solid(city.get_block(Vector3i(x,y,z))): clear = false
			check(direction.length()>0.99,"route %d direction stays normalized at %d" % [route,d])
		car.distance = old
		traffic.place(car)
		check(clear,"bus envelope has road support and clearance around loop %d" % route)
	var first: CharacterBody3D = traffic.vehicles[0]
	first.distance = 30
	traffic.place(first)
	var before := first.position
	traffic.enabled = true
	traffic._physics_process(0.1)
	check(first.position.distance_to(before)>0.4,"vehicle actually advances on its route")
	player.position = first.position+Vector3(4,0,0)
	check(not traffic.route_clear(first,first.position+Vector3(0.1,0,0),Vector3.RIGHT),"vehicle yields to player ahead")
	player.position = city.spawn_position()
	var obstruction := Vector3i(first.position+Vector3(2,0,0))
	city.set_block(obstruction,3)
	check(not traffic.route_clear(first,first.position+Vector3(0.1,0,0),Vector3.RIGHT),"edited voxel blocks vehicle before mesh rebuild")
	city.set_block(obstruction,0)
	var road := Vector3i(first.position)+Vector3i.DOWN
	var road_block: int = city.get_block(road)
	city.set_block(road,0)
	check(not traffic.route_clear(first,first.position,Vector3.RIGHT),"vehicle stops before an edited road hole")
	city.set_block(road,road_block)
	traffic.pause()
	before = first.position
	traffic._physics_process(1)
	check(first.position == before,"pause freezes traffic")
	check(traffic.overlaps(Vector3i(first.position)+Vector3i.UP),"vehicle bounds protect against placing inside cars")
	var saved := traffic.snapshot()
	check(traffic.restore(saved[0]),"vehicle route progress restores")
	for bad in [null,{}, {"id":0,"route":0,"distance":INF},{"id":0.5,"route":0,"distance":0},{"id":0,"route":1,"distance":10},{"id":0,"route":0,"distance":-1}]:
		check(not traffic.restore(bad),"malformed route snapshot rejected")
	await test_picker()
	test_saves(city,traffic)
	traffic.queue_free()
	player.queue_free()
	city.queue_free()
	print("CITY %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)

func test_picker() -> void:
	check(Catalog.ENTRIES.size() == Catalog.WORLD_IDS.size(),"catalog and save allowlist match")
	var ids := {}
	var paths := {}
	for item in Catalog.ENTRIES:
		ids[item["id"]] = true
		paths[item["path"]] = true
	check(ids.size() == 4 and paths.size() == 4,"four unique stable world identities and paths")
	check(Catalog.filtered("Perkotaan").size() == 1 and Catalog.filtered("Alam").size() == 2,"world categories filter correctly")
	check(Catalog.filtered("Semua","  HARMONI ")[0]["id"] == "city" and Catalog.filtered("Pedesaan","harmoni").is_empty(),"search trims case and combines with categories")
	check(Catalog.entry("../escape").is_empty(),"unknown template cannot choose arbitrary save path")
	var picker := Picker.new()
	root.add_child(picker)
	picker.open("farm",["farm","classic"])
	check(picker.cards.size() == 3 and picker.page_count() == 2 and picker.previous.disabled,"first catalog page has bounded cards")
	picker.turn_page(1)
	check(picker.cards.size() == 1 and picker.selected_id == "classic" and picker.next.disabled,"last page shows remaining world and clamps navigation")
	picker.turn_page(1)
	check(picker.page == 1,"cannot paginate past end")
	picker.reveal("farm")
	check(picker.page == 0 and picker.selected_id == "farm" and picker.launch.text.begins_with("Lanjutkan"),"resume identity follows stable ID rather than page position")
	picker.search.text = "not-a-world"
	picker.refresh()
	check(picker.cards.is_empty() and picker.launch.disabled and picker.selected_id.is_empty(),"empty search has no stale launch target")
	picker.reset_filters()
	check(picker.matches.size() == 4 and picker.cards.size() == 3,"reset restores catalog")
	# Future-size synthetic catalog: no additional UI buttons or hardcoded pages needed.
	var many := []
	for i in 17:
		var item: Dictionary = Catalog.ENTRIES[0].duplicate()
		item["id"] = "fixture-"+str(i)
		many.append(item)
	picker.source = many
	picker.refresh()
	check(picker.page_count() == 6,"seventeen templates produce six pages automatically")
	picker.turn_page(5)
	check(picker.cards.size() == 2 and picker.page == 5,"future last page handles partial row")
	picker.set_category(1)
	check(picker.page == 0 and picker.cards.is_empty(),"filter resets a high page safely")
	picker.source = Catalog.ENTRIES
	picker.reset_filters()
	picker.queue_free()
	await process_frame

func test_saves(city: Node3D,traffic: Node3D) -> void:
	var store := Store.new()
	var directory := "user://test-city-"+str(Time.get_ticks_usec())
	var hashes := {}
	for id in Catalog.WORLD_IDS:
		check(store.prepare_world(id,directory),"prepare isolated "+id+" slot")
		if id != "city":
			store.write_save(payload(id),store.world_path(id,directory))
			hashes[id] = FileAccess.get_sha256(store.world_path(id,directory))
	var at := Vector3i(381,75,381)
	check(city.set_block(at,Blocks.id("facade_blue")),"city supports distant high-altitude edits")
	var data := payload("city")
	data["changes"] = city.changes.duplicate()
	data["vehicles"] = traffic.snapshot()
	var path := store.world_path("city",directory)
	check(store.write_save(data,path),"city save includes edits and vehicle progress")
	var loaded := store.read_world("city",directory)
	check(loaded.get("vehicles",[]).size() == 10 and loaded.get("generator") == 4,"city identity and traffic round trip")
	city.apply_changes(loaded.get("changes",{}))
	check(city.get_block(at) == Blocks.id("facade_blue"),"city material IDs restore at high indices")
	for id in hashes: check(FileAccess.get_sha256(store.world_path(id,directory)) == hashes[id],"city writes leave "+id+" save byte-identical")
	store.write_save(data,path)
	var corrupt := FileAccess.open(path,FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	check(not store.read_world("city",directory).is_empty() and not store.last_error.is_empty(),"city recovers its own backup")
	var invalid_path := directory.path_join("invalid.json")
	for field in ["world_size","world_height","generator","vehicles"]:
		var invalid := data.duplicate(true)
		invalid[field] = -1
		store.write_save(invalid,invalid_path)
		check(store._read_valid(invalid_path).is_empty(),"reject invalid city "+field)
	for sub in [directory.path_join("worlds"),directory]:
		var dir := DirAccess.open(sub)
		for file in dir.get_files(): dir.remove(file)
		DirAccess.remove_absolute(sub)

func payload(id: String) -> Dictionary:
	var item := Catalog.entry(id)
	return {"version":3,"world_id":id,"world_size":item["size"],"world_height":item["height"],"generator":item["generator"],"seed":20260905,"changes":{},"position":[208.5,13.1,224.5],"yaw":0,"pitch":0,"selected":0,"hotbar":[1,2,3,4,5,6,7,8],"animals":[]}
