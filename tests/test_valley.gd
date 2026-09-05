extends SceneTree

const World = preload("res://scripts/voxel_world.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Layout = preload("res://scripts/valley_layout.gd")
const Farm = preload("res://scripts/farm_layout.gd")
const Store = preload("res://scripts/save_store.gd")
const Herd = preload("res://scripts/farm_herd.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("VALLEY FAIL: "+label)

func run() -> void:
	var valley := World.new()
	valley.configure("valley")
	root.add_child(valley)
	valley.set_process(false)
	valley.generate(20260905)
	check(valley.size == 384 and valley.height == 80 and valley.blocks.size() == 384*384*80,"384 square area, eighty-block height and correct storage")
	check(valley.generator_version == 3 and valley.changes.is_empty(),"separate generator with no generated edits")
	check(valley.inside(Vector3i(383,79,383)) and not valley.inside(Vector3i(384,79,383)) and not valley.inside(Vector3i(383,80,383)),"expanded bounds enforced")
	var generated := valley.blocks.duplicate()
	var progress := []
	await valley.generate_valley_async(20260905,func(message: String): progress.append(message))
	check(generated == valley.blocks,"synchronous and incremental generation are byte-identical")
	check(progress.size()>=33,"terrain generation yields with progress updates")
	var spawn := Vector3i(valley.spawn_position())
	check(valley.get_block(Vector3i(spawn.x,20,spawn.z)) != 0 and valley.get_block(spawn) == 0,"village spawn is supported and clear")
	check(valley.surface_height(250,60)>=55 and valley.surface_height(350,210)>40,"northern and eastern hills rise above village")
	var farm := World.new()
	farm.configure("farm")
	root.add_child(farm)
	farm.set_process(false)
	farm.generate(20260905)
	# Every voxel in the old houses, barn, well and pens must survive the valley stamp.
	var regions := [Rect2i(116,31,22,14),Rect2i(92,94,9,9)]
	for p: Vector2i in Farm.HOMES: regions.append(Rect2i(p-Vector2i.ONE,Vector2i(11,11)))
	for pen in Farm.PENS: regions.append(pen["rect"])
	for rect: Rect2i in regions:
		var same := true
		for x in range(rect.position.x,rect.end.x):
			for z in range(rect.position.y,rect.end.y):
				for y in range(14,40):
					var p := Vector3i(x,y,z)
					if farm.get_block(p) != valley.get_block(p+Layout.OFFSET): same = false
		check(same,"village structure preserved at %s" % rect.position)
	check(valley.emissive_cells.size() == 6,"six village lamps retain emitted light metadata")
	for i in 3:
		var x := 96-i*14
		var h := 23+i*4
		check(valley.get_block(Vector3i(x,h,160)) == Blocks.id("farm_soil") and valley.get_block(Vector3i(x,h+1,160)) == Blocks.id(["wheat_crop","carrot_crop","potato_crop"][i]),"terrace %d soil and crops at correct elevation" % i)
	check(valley.get_block(Vector3i(252,55,93)) == Blocks.id("water") and valley.get_block(Vector3i(252,54,93)) == 3,"waterfall lip joins source above stone backing")
	var water := connected(valley,Vector2i(252,110),true)
	check(water.has(Vector2i(292,327)),"continuous shallow water connects waterfall pool to lake")
	check(water.has(Vector2i(roundi(Layout.river_x(360)),360)),"river continues downstream")
	var paths := connected(valley,Vector2i(201,193),false)
	for p in [Vector2i(230,108),Vector2i(241,64),Vector2i(64,181),Vector2i(80,242),Vector2i(280,347),Vector2i(325,214)]:
		check(paths.has(p),"graded roads and steps reach destination %s" % p)
	var herd := Herd.new()
	root.add_child(herd)
	herd.populate(valley)
	check(herd.animals.size() == 20,"valley keeps twenty livestock")
	for animal in herd.animals:
		check(animal.has_safe_position and animal.can_stand(animal.position) and animal.position.y>21 and animal.position.x>200,"animal is safe in elevated valley pen: %d" % animal.animal_id)
	var cell := Vector3i(378,72,378)
	check(valley.set_block(cell,Blocks.id("sea_lantern")),"block edits work above old height and outside old world")
	check(not valley.set_block(Vector3i(378,0,378),0),"expanded bedrock protected")
	var edits := valley.changes.duplicate()
	valley.blocks = generated
	valley.apply_changes(edits)
	check(valley.get_block(cell) == Blocks.id("sea_lantern") and valley.emissive_cells.has(cell),"large-stride edits and light positions restore correctly")
	await valley.prepare_distant_landscape(func(_message: String): pass)
	check(valley.far_landscape.patches.size() == 576,"distant terrain covers all 24 by 24 regions")
	valley.streaming = true
	valley.update_stream(valley.spawn_position())
	check(valley.build_queue.size() == 49,"near rendering budget remains seven by seven")
	var key: Vector2i = valley.build_queue.pop_front()
	valley.build_chunk(key)
	check(not valley.far_landscape.patches[key].visible,"far patch hides only once detailed chunk exists")
	var edited := Vector3i(key.x*16+2,70,key.y*16+2)
	valley.set_block(edited,3)
	check(valley.far_landscape.dirty.has(key),"edit invalidates far terrain patch")
	valley.update_stream(Vector3(374,50,374))
	check(not valley.chunks.has(key) and valley.far_landscape.patches[key].visible and not valley.far_landscape.dirty.has(key),"unload restores refreshed distant patch")
	check(not valley.collision_ready(valley.spawn_position()),"distant visual never pretends to have collision")
	# Only this test-created folder is used; actual user saves are never opened.
	var store := Store.new()
	var directory := "user://test-valley-"+str(Time.get_ticks_usec())
	for id in Store.WORLD_IDS: check(store.prepare_world(id,directory),"prepare isolated "+id+" save")
	var classic_path := store.world_path("classic",directory)
	var farm_path := store.world_path("farm",directory)
	var valley_path := store.world_path("valley",directory)
	store.write_save(payload("classic"),classic_path)
	store.write_save(payload("farm"),farm_path)
	var hashes := [FileAccess.get_sha256(classic_path),FileAccess.get_sha256(farm_path)]
	var data := payload("valley")
	data["changes"] = edits
	data["animals"] = herd.snapshot()
	check(store.write_save(data,valley_path),"valley snapshot written")
	var loaded := store.read_world("valley",directory)
	check(loaded.get("world_height") == 80 and int(loaded.get("changes",{}).get(str(valley.index_of(cell)),-1)) == Blocks.id("sea_lantern") and loaded.get("animals",[]).size() == 20,"valley identity, high edits and animals round trip")
	check(hashes == [FileAccess.get_sha256(classic_path),FileAccess.get_sha256(farm_path)],"valley saves never alter either previous world")
	check(store.write_save(data,valley_path),"valley backup created")
	var corrupt := FileAccess.open(valley_path,FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	check(not store.read_world("valley",directory).is_empty() and not store.last_error.is_empty(),"valley recovers only its own backup")
	var invalid_path := directory.path_join("invalid.json")
	for field in ["world_height","world_size","generator"]:
		var invalid := data.duplicate(true)
		invalid[field] = -1
		store.write_save(invalid,invalid_path)
		check(store._read_valid(invalid_path).is_empty(),"invalid valley "+field+" rejected")
	for sub in [directory.path_join("worlds"),directory]:
		var dir := DirAccess.open(sub)
		for file in dir.get_files(): dir.remove(file)
		DirAccess.remove_absolute(sub)
	herd.queue_free()
	valley.queue_free()
	farm.queue_free()
	print("VALLEY %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)

func payload(id: String) -> Dictionary:
	return {"version":3,"world_id":id,"world_size":384 if id == "valley" else (192 if id == "farm" else 96),"world_height":80 if id == "valley" else 40,"generator":3 if id == "valley" else (2 if id == "farm" else 1),"seed":20260905,"changes":{},"position":[192.5,21.1,208.5],"yaw":0,"pitch":0,"selected":0,"hotbar":[1,2,3,4,5,6,7,8],"animals":[]}

func connected(w: Node3D,start: Vector2i,water: bool) -> Dictionary:
	var found := {start:true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	var materials := [Blocks.id("coarse_dirt"),Blocks.id("gravel"),Blocks.id("oak_planks"),Blocks.id("stone_bricks"),Blocks.id("cobblestone")]
	while index<queue.size():
		var p := queue[index]
		index += 1
		var h: int = 20 if water else w.surface_height(p.x,p.y)
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = p+offset
			if found.has(next) or next.x<0 or next.x>=w.size or next.y<0 or next.y>=w.size: continue
			var nh: int = 20 if water else w.surface_height(next.x,next.y)
			var block: int = w.get_block(Vector3i(next.x,nh,next.y))
			if (water and block == Blocks.id("water")) or (not water and block in materials and absi(nh-h)<=1):
				found[next] = true
				queue.append(next)
	return found
