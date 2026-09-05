extends SceneTree

const World = preload("res://scripts/voxel_world.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Store = preload("res://scripts/save_store.gd")
const Layout = preload("res://scripts/farm_layout.gd")
const Herd = preload("res://scripts/farm_herd.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("WORLD FAIL: "+label)

func payload(id: String) -> Dictionary:
	return {"version":3,"world_id":id,"world_size":192 if id == "farm" else 96,"generator":2 if id == "farm" else 1,"seed":20260905,"changes":{},"position":[96.5,14.1,112.5] if id == "farm" else [48.5,16.1,48.5],"yaw":0,"pitch":0,"selected":0,"hotbar":[1,2,3,4,5,6,7,8],"animals":[]}

func run() -> void:
	Blocks.setup()
	var classic := World.new()
	root.add_child(classic)
	classic.set_process(false)
	classic.generate(20260905)
	var legacy_terrain := classic.blocks.duplicate()
	var farm := World.new()
	farm.configure("farm")
	root.add_child(farm)
	farm.set_process(false)
	farm.generate(20260905)
	check(farm.size == 192 and farm.blocks.size() == classic.blocks.size()*4,"farm area/storage is exactly 4x classic")
	check(farm.generator_version == 2 and classic.generator_version == 1,"generators have separate version IDs")
	var generated := farm.blocks.duplicate()
	farm.generate(20260905)
	check(generated == farm.blocks,"village layout is deterministic")
	classic.generate(20260905)
	check(classic.blocks == legacy_terrain,"farm generation does not modify classic terrain")
	check(Blocks.id("emerald_block") == 178 and Blocks.id("farm_soil") == 179,"new materials append after all released IDs")
	check(farm.changes.is_empty(),"generated village does not bloat saved edits")
	var spawn := Vector3i(farm.spawn_position())
	check(not Blocks.is_solid(farm.get_block(spawn)) and farm.get_block(Vector3i(spawn.x,13,spawn.z)) != 0,"spawn has headroom and supporting road")
	for p: Vector2i in Layout.HOMES:
		check(farm.get_block(Vector3i(p.x+4,14,p.y+8)) == 0 and farm.get_block(Vector3i(p.x+4,15,p.y+8)) == 0,"house doorway is open at %s" % p)
	for key in ["wheat_crop","carrot_crop","potato_crop","pumpkin","apple_leaves","farm_soil","water","hay_bale","oak_fence"]:
		check(farm.blocks.has(Blocks.id(key)),"village includes "+key)
	check(not farm.set_block(Vector3i(191,0,191),0),"farm bedrock protected")
	check(not farm.set_block(Vector3i(192,15,192),3),"farm upper bounds enforced")
	var distant := Vector3i(183,30,181)
	check(farm.set_block(distant,Blocks.id("hay_bale")),"editing beyond old 96-block limit works")
	var edits := farm.changes.duplicate()
	farm.generate(20260905)
	farm.apply_changes(edits)
	check(farm.get_block(distant) == Blocks.id("hay_bale"),"farm save indices use the larger stride")
	check(farm.emissive_cells.size() == 6,"generated village lamps survive edit restore")
	# Special-shape chunks must retain plants without adding invisible cube collisions.
	var empty := World.new()
	root.add_child(empty)
	empty.set_process(false)
	empty.set_block(Vector3i(2,15,2),Blocks.id("wheat_crop"))
	empty.build_chunk(Vector2i.ZERO)
	var node: StaticBody3D = empty.chunks[Vector2i.ZERO]
	check(node.get_child_count() == 3 and node.get_child(2) is MultiMeshInstance3D,"crops rendered in per-chunk GPU batches")
	check(node.get_child(1).shape == null,"crops do not block movement")
	empty.set_block(Vector3i(2,15,2),0)
	empty.set_block(Vector3i(3,15,2),Blocks.id("water"))
	empty.build_chunk(Vector2i.ZERO)
	check(node.get_child_count() == 2 and node.get_child(1).shape == null,"deleted crop batch removed; water has no solid collision")
	empty.set_block(Vector3i(3,15,2),0)
	empty.set_block(Vector3i(2,15,2),Blocks.id("oak_fence"))
	empty.build_chunk(Vector2i.ZERO)
	check(node.get_child(1).shape != null,"fence supplies collision")
	# Streaming queues are bounded, nearest-first and use edited data when rebuilding.
	farm.streaming = true
	farm.update_stream(Vector3(96,14,96))
	check(farm.build_queue.size() == 49 and farm.build_queue[0] == Vector2i(6,6),"streaming queues nearest 7x7 region")
	farm.build_chunk(farm.build_queue.pop_front())
	check(farm.collision_ready(Vector3(96,14,96)) and not farm.collision_ready(Vector3(0,14,0)),"collision availability prevents falling into unloaded chunks")
	farm.update_stream(Vector3(180,14,180))
	check(not farm.chunks.has(Vector2i(6,6)) and farm.build_queue.size() == 16,"old region unloads; edge region is clamped")
	farm.build_chunk(Vector2i(11,11))
	check(farm.get_block(distant) == Blocks.id("hay_bale"),"streaming does not discard edits")
	var herd := Herd.new()
	root.add_child(herd)
	herd.populate(farm)
	check(herd.animals.size() == 20,"herd has twenty animals")
	var counts := {"cow":0,"sheep":0,"pig":0,"chicken":0}
	for animal in herd.animals:
		counts[animal.species] += 1
		check(animal.has_safe_position and animal.can_stand(animal.position),"animal starts on safe ground: %d" % animal.animal_id)
		check(animal.restore(animal.snapshot()),"animal position and orientation restore: %d" % animal.animal_id)
	check(counts == {"cow":5,"sheep":5,"pig":4,"chicken":6},"four species counts match plan")
	var animal: CharacterBody3D = herd.animals[0]
	check(not animal.restore({"id":0,"species":"cow","position":[500,14,500],"yaw":0}),"out-of-pen animal save rejected")
	check(not animal.restore({"id":0,"species":"cow","position":["bad",14,55],"yaw":0}),"malformed animal save rejected")
	herd.pause()
	check(not animal.is_physics_processing(),"pausing freezes animal AI")
	# Save tests use a unique isolated root, never the real world.json.
	var store := Store.new()
	var directory := "user://test-worlds-"+str(Time.get_ticks_usec())
	check(store.prepare_world("classic",directory) and store.prepare_world("farm",directory),"independent save folders created")
	var legacy_directory := directory.path_join("legacy-save")
	var migrated_directory := directory.path_join("migrated-save")
	DirAccess.make_dir_recursive_absolute(legacy_directory.path_join("worlds"))
	var legacy_main := FileAccess.open(legacy_directory.path_join("world.json"),FileAccess.WRITE)
	legacy_main.store_string("legacy")
	legacy_main.close()
	var legacy_farm := FileAccess.open(legacy_directory.path_join("worlds/desa-pertanian.json"),FileAccess.WRITE)
	legacy_farm.store_string("farm")
	legacy_farm.close()
	DirAccess.make_dir_recursive_absolute(migrated_directory)
	var current_main := FileAccess.open(migrated_directory.path_join("world.json"),FileAccess.WRITE)
	current_main.store_string("current")
	current_main.close()
	check(store._copy_missing_files(legacy_directory,migrated_directory) and FileAccess.get_file_as_string(migrated_directory.path_join("world.json")) == "current" and FileAccess.get_file_as_string(migrated_directory.path_join("worlds/desa-pertanian.json")) == "farm","legacy save migration copies nested missing files without overwriting current saves")
	var classic_path := store.world_path("classic",directory)
	var farm_path := store.world_path("farm",directory)
	check(classic_path != farm_path and store.world_path("../escape",directory).is_empty(),"world paths are fixed allowlisted targets")
	var old := payload("classic")
	old["version"] = 2
	old.erase("world_id")
	old.erase("world_size")
	old["changes"] = {"280000":7}
	check(store.write_save(old,classic_path),"legacy fixture written")
	var old_hash := FileAccess.get_sha256(classic_path)
	check(store.prepare_world("classic",directory),"legacy backup preparation succeeds")
	check(FileAccess.get_sha256(classic_path) == old_hash and FileAccess.get_sha256(classic_path+".pre-v0.3.bak") == old_hash,"one-time backup is byte-for-byte; source untouched")
	check(not store.read_world("classic",directory).is_empty(),"v2 world loads in classic slot")
	var data := payload("farm")
	data["changes"] = edits
	data["animals"] = herd.snapshot()
	check(store.write_save(data,farm_path),"farm save written")
	var loaded := store.read_world("farm",directory)
	check(loaded.get("animals",[]).size() == 20 and loaded.get("world_size") == 192,"farm identity and herd round trip")
	check(FileAccess.get_sha256(classic_path) == old_hash,"saving farm never changes classic file")
	check(store.write_save(payload("classic"),classic_path) and store.prepare_world("classic",directory),"classic upgrades to v3")
	check(FileAccess.get_sha256(classic_path+".pre-v0.3.bak") == old_hash,"later saves never replace original migration backup")
	check(store.write_save(data,farm_path),"farm backup created")
	var corrupt := FileAccess.open(farm_path,FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(not store.read_world("farm",directory).is_empty() and not store.last_error.is_empty(),"corrupt farm primary recovers its own backup")
	data["world_size"] = 96
	var invalid_path := directory.path_join("invalid.json")
	store.write_save(data,invalid_path)
	check(store._read_valid(invalid_path).is_empty(),"mismatched world dimension cannot load")
	data = payload("farm")
	store.write_save(data,classic_path)
	check(store.read_world("classic",directory).is_empty(),"farm identity cannot load in classic slot")
	# Clean only known files within this test-owned folder.
	for sub in [legacy_directory.path_join("worlds"),legacy_directory,migrated_directory.path_join("worlds"),migrated_directory,directory.path_join("worlds"),directory]:
		var dir := DirAccess.open(sub)
		for file in dir.get_files(): dir.remove(file)
		DirAccess.remove_absolute(sub)
	herd.queue_free()
	empty.queue_free()
	farm.queue_free()
	classic.queue_free()
	print("WORLDS %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
