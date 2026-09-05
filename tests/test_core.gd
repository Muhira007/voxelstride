extends SceneTree

const World = preload("res://scripts/voxel_world.gd")
const Store = preload("res://scripts/save_store.gd")
const GameInput = preload("res://scripts/game_input.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	root.add_child(world)
	world.set_process(false)
	world.generate(20260905)
	var original := world.blocks.duplicate()
	world.generate(20260905)
	check(original == world.blocks, "terrain generation must be deterministic")
	check(world.get_block(Vector3i(48,0,48)) == 9, "bedrock is generated")
	check(not world.set_block(Vector3i(48,0,48), 0), "bedrock cannot be removed")
	check(not world.set_block(Vector3i(-1,5,5), 1), "out-of-bounds edit rejected")
	check(not world.set_block(Vector3i(4,World.HEIGHT,5), 1), "height limit respected")
	check(not world.set_block(Vector3i(4,25,5), 99), "unknown block rejected")
	var p := Vector3i(15,30,15)
	check(world.set_block(p,7), "block can be placed in air")
	check(world.dirty_chunks.size() == 3, "chunk corner edit refreshes both adjacent chunks")
	check(world.dirty_chunks.has(Vector2i(1,0)) and world.dirty_chunks.has(Vector2i(0,1)), "correct adjacent chunks refreshed")
	var hit := world.raycast(Vector3(15.5,33.5,15.5), Vector3.DOWN)
	check(not hit.is_empty() and hit["cell"] == p and hit["previous"] == p + Vector3i.UP, "ray hits top face and placement cell")
	for direction in World.DIRECTIONS:
		var axis_hit := world.raycast(Vector3(p) + Vector3.ONE * 0.5 + Vector3(direction) * 3, -Vector3(direction))
		check(not axis_hit.is_empty() and axis_hit["cell"] == p and axis_hit["previous"] == p + direction, "axis ray traversal %s" % str(direction))
	check(world.raycast(Vector3(15.5,38,15.5), Vector3.DOWN).is_empty(), "interaction limited to six blocks")
	check(world.set_block(p,0), "block can be destroyed")
	check(world.raycast(Vector3(15.5,33.5,15.5), Vector3.DOWN).is_empty(), "ray sees edit before mesh rebuild")
	world.set_block(p,7)
	world.build_chunk(Vector2i(0,0))
	check(world.chunks[Vector2i(0,0)].get_child(0).mesh != null, "visible chunk mesh built")
	check(world.chunks[Vector2i(0,0)].get_child(1).shape != null, "voxel collision built")
	var edits := world.changes.duplicate()
	world.generate(20260905)
	world.apply_changes(edits)
	check(world.get_block(p) == 7, "saved changes restore over deterministic terrain")
	world.apply_changes({"-1": 7, "99999999": 8, "nonsense": 1, "1": 0, "30000": "bad", "30001": 2.4})
	check(world.changes.is_empty(), "malformed edits cannot change memory or bedrock")
	var store := Store.new()
	var directory := "user://test-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory + "/world.json"
	var data := {"version":1, "generator":1, "seed":20260905, "changes":edits, "position":[48.5,17.0,48.5], "yaw":0.7, "pitch":-0.1, "selected":6}
	check(store.write_save(data,path), "first save succeeds: " + store.last_error)
	var loaded := store.read_save(path)
	world.generate(20260905)
	if not loaded.is_empty(): world.apply_changes(loaded["changes"])
	check(not loaded.is_empty() and world.get_block(p) == 7, "save round trip restores the placed block")
	data["selected"] = 3
	check(store.write_save(data,path), "overwrite save succeeds: " + store.last_error)
	check(FileAccess.file_exists(path + ".bak"), "previous save backed up")
	check(store.read_save(path)["selected"] == 3, "current save selected")
	var corrupt := FileAccess.open(path,FileAccess.WRITE)
	corrupt.store_string("{broken save")
	corrupt.close()
	loaded = store.read_save(path)
	check(not loaded.is_empty() and loaded["selected"] == 6, "corrupt main save recovers previous backup")
	check(not store.last_error.is_empty(), "recovery notice surfaced")
	check(store.write_save(data,path), "saving after recovery succeeds")
	check(store.read_save(path)["selected"] == 3, "recovered world can be saved again")
	check(store._read_valid(path + ".bak")["selected"] == 6, "corrupt primary does not destroy good backup")
	data["position"] = ["invalid", 2, 3]
	corrupt = FileAccess.open(path,FileAccess.WRITE)
	corrupt.store_string(JSON.stringify(data))
	corrupt.close()
	check(store._read_valid(path).is_empty(), "malformed player coordinates rejected")
	check(not store.write_save(data, directory + "/missing/world.json"), "write failure reported instead of success")
	# Remove only this test's isolated files, never the actual user's save.
	var dir := DirAccess.open(directory)
	for filename in dir.get_files(): dir.remove(filename)
	DirAccess.remove_absolute(directory)
	GameInput.setup()
	var button := InputEventJoypadButton.new()
	button.pressed = true
	button.button_index = JOY_BUTTON_A
	check(button.is_action_pressed("jump"), "Xbox A maps to jump")
	button.button_index = JOY_BUTTON_B
	check(button.is_action_pressed("crouch"), "Xbox B maps to crouch")
	button.button_index = JOY_BUTTON_Y
	check(button.is_action_pressed("break_block") and not button.is_action_pressed("inventory"), "Xbox Y maps to break, not inventory")
	button.button_index = JOY_BUTTON_X
	check(button.is_action_pressed("place_block"), "Xbox X maps to place")
	button.button_index = JOY_BUTTON_BACK
	check(button.is_action_pressed("inventory") and not button.is_action_pressed("save_world"), "Xbox Back maps to inventory")
	button.button_index = JOY_BUTTON_START
	check(button.is_action_pressed("pause"), "Xbox Start maps to menu")
	button.button_index = JOY_BUTTON_DPAD_UP
	check(button.is_action_pressed("previous_block") and not button.is_action_pressed("move_forward"), "D-pad selects without walking")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.1
	check(not stick.is_action_pressed("move_right"), "analog deadzone prevents drift")
	stick.axis_value = 0.9
	check(stick.is_action_pressed("move_right"), "left stick moves player")
	print("CORE %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	world.queue_free()
	quit(1 if failures else 0)
