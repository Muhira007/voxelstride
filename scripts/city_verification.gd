extends RefCounted

const Blocks = preload("res://scripts/blocks.gd")
const Traffic = preload("res://scripts/city_traffic.gd")

static func smoke(game: Node3D) -> void:
	var test_root := "user://city-smoke-"+str(Time.get_ticks_usec())
	game.automation_save_root = test_root
	game.store.prepare_world("farm",test_root)
	game._world_picker()
	game.world_picker.reset_filters()
	await game._simulate_pad_button(JOY_BUTTON_RIGHT_SHOULDER)
	game._smoke_check(game.world_picker.page == 1 and game.world_picker.cards.size() == 1,"RB navigates to second template page")
	await game._simulate_pad_button(JOY_BUTTON_LEFT_SHOULDER)
	game._smoke_check(game.world_picker.page == 0 and game.world_picker.selected_id == "city","LB returns to city card")
	await game._simulate_pad_button(JOY_BUTTON_DPAD_RIGHT)
	game._smoke_check(game.world_picker.selected_id == "valley","D-pad selects world card")
	await game._simulate_pad_axis(JOY_AXIS_TRIGGER_RIGHT,0.6)
	await game._simulate_pad_axis(JOY_AXIS_TRIGGER_RIGHT,0.9)
	game._smoke_check(game.world_picker.category == 1,"held right trigger changes template category once")
	await game._simulate_pad_axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	game.world_picker.set_category(3)
	game._smoke_check(game.world_picker.matches.size() == 1 and game.world_picker.selected_id == "city","category isolates urban template")
	game.world_picker.search.grab_focus()
	var letter := InputEventKey.new()
	letter.keycode = KEY_E
	letter.physical_keycode = KEY_E
	letter.unicode = 101
	letter.pressed = true
	Input.parse_input_event(letter)
	await game.get_tree().process_frame
	game._smoke_check(game.menu_state == "worlds" and game.world_picker.search.text == "e","typing E searches worlds without opening inventory")
	game.world_picker.search.text = "no-such-template"
	game.world_picker.refresh()
	game._smoke_check(game.world_picker.launch.disabled,"empty search disables opening stale world")
	game.world_picker.reset_filters()
	game.world_picker.reveal("city")
	await game._simulate_pad_button(JOY_BUTTON_A)
	while game.loading_world: await game.get_tree().process_frame
	game._smoke_check(game.active_world_id == "city" and game.menu_state == "playing","Xbox A opens city from full-screen catalog")
	for i in 90: await game.get_tree().physics_frame
	game._smoke_check(game.player.is_on_floor(),"city spawn has collision")
	game._smoke_check(game.traffic.vehicles.size() == 22 and not is_instance_valid(game.herd),"city has vehicles instead of farm livestock")
	game._smoke_check(game.world.far_landscape.patches.size() == 576 and game.world.chunks.size() == 49,"city uses distant skyline and bounded detail")
	# Check collision on the top-floor staircase and roof of the tallest building.
	game.player.position = Vector3(136.5,68.05,141.5)
	game.player.velocity = Vector3.ZERO
	await stream_at(game,game.player.position)
	for i in 60: await game.get_tree().physics_frame
	game._smoke_check(game.player.is_on_floor() and game.player.position.y>65,"tower roof staircase has real high-altitude collision")
	game.player.respawn()
	await stream_at(game,game.player.position)
	# A known route point near the park, isolated from other traffic and the player.
	var car: CharacterBody3D = game.traffic.vehicles[6]
	car.distance = 250
	game.traffic.place(car)
	var before := car.position
	for i in 90: await game.get_tree().physics_frame
	game._smoke_check(car.position.distance_to(before)>3,"city vehicle moves in real physics frames")
	game._show_menu("inventory")
	before = car.position
	for i in 20: await game.get_tree().physics_frame
	game._smoke_check(car.position == before,"inventory freezes vehicles")
	game._start_playing()
	# Put the player in front of a moving car. It must yield without pushing or overlap.
	game.player.enabled = false
	car.distance = 220
	game.traffic.place(car)
	var direction := (Traffic.point(1,220.5)-car.position).normalized()
	game.player.position = car.position+direction*(car.dimensions.z/2+1.2)
	before = car.position
	for i in 30: await game.get_tree().physics_frame
	game._smoke_check(car.position == before and car.stopped,"traffic yields to stationary player")
	game.target = {"cell":Vector3i(car.position)+Vector3i.DOWN,"previous":Vector3i(car.position)+Vector3i.UP,"block":3}
	game._smoke_check(not game._edit_block(true),"cannot place a voxel inside vehicle body")
	game.player.respawn()
	game.player.enabled = true
	for i in 30: await game.get_tree().physics_frame
	game._smoke_check(car.position.distance_to(before)>1,"traffic resumes once player clears lane")
	# Player physics must collide with the parked bus, not merely block placement.
	var parked: CharacterBody3D = game.traffic.vehicles[10]
	game.player.enabled = false
	game.player.position = parked.position+Vector3(0,0,-7)
	await stream_at(game,game.player.position)
	for i in 2: await game.get_tree().physics_frame
	game.traffic.refresh_visibility()
	game._smoke_check(game.player.test_move(game.player.global_transform,Vector3(0,0,8)),"parked bus has real player collision")
	game.player.respawn()
	await stream_at(game,game.player.position)
	game._start_playing()
	game._world_picker()
	before = car.position
	for i in 20: await game.get_tree().physics_frame
	game._smoke_check(car.position == before and game.world_picker.visible,"world catalog pauses traffic")
	await game._simulate_pad_button(JOY_BUTTON_B)
	game._smoke_check(game.menu_state == "playing" and not game.world_picker.visible,"Xbox B returns from catalog without reloading")
	var edit := Vector3i(377,72,375)
	game.world.set_block(edit,Blocks.id("facade_blue"))
	game.hotbar[0] = Blocks.id("asphalt")
	game._select_block(0)
	game._show_menu("pause")
	game._smoke_check(game._save_world(),"city saves blocks hotbar player and vehicle progress")
	var saved: Dictionary = game.store.read_world("city",test_root)
	game._smoke_check(saved.get("vehicles",[]).size() == 10,"all moving route positions persisted")
	game._smoke_check(await game._choose_world("classic"),"city can switch back to classic")
	game._smoke_check(not is_instance_valid(game.traffic),"city vehicles are removed from other worlds")
	var classic_path: String = game.store.world_path("classic",test_root)
	game._save_world()
	var classic_hash := FileAccess.get_sha256(classic_path)
	game._smoke_check(await game._choose_world("city"),"city resumes from separate save")
	game._show_menu("pause")
	game._smoke_check(game.world.get_block(edit) == Blocks.id("facade_blue") and game.hotbar[0] == Blocks.id("asphalt"),"new city material edits and hotbar survive switching")
	game._smoke_check(absf(game.traffic.vehicles[6].distance-float(saved["vehicles"][6]["distance"]))<3,"vehicle route progress restored instead of reset")
	game._save_world()
	game._smoke_check(FileAccess.get_sha256(classic_path) == classic_hash,"city save does not change classic file")
	# A failed save must leave the catalog usable and display the error on this page.
	game._world_picker()
	game.automation_save_root = test_root.path_join("missing")
	game._smoke_check(not await game._choose_world("farm") and game.active_world_id == "city" and game.world_picker.visible,"failed save prevents leaving city")
	game._smoke_check(game.world_picker.status.text.contains("Dunia belum diganti"),"save failure appears on visible catalog page")
	game.automation_save_root = ""
	for sub in [test_root.path_join("worlds"),test_root]:
		var dir := DirAccess.open(sub)
		for file in dir.get_files(): dir.remove(file)
		DirAccess.remove_absolute(sub)
	print("CITY SMOKE: catalog paging/search/controller, moving traffic, collisions, pause, save isolation and restore checked")

static func capture(game: Node3D) -> void:
	await shot(game,"world-catalog")
	game.world_picker.turn_page(1)
	await shot(game,"world-catalog-page2")
	await game._choose_world("city")
	for i in 120: await game.get_tree().process_frame
	game.hud.toast_time = 0
	await shot(game,"city-gameplay")
	await measure(game,"park")
	game.player.enabled = false
	game.hud.hide()
	game.held_block.hide()
	game.outline.hide()
	game.set_process(false)
	await camera_at(game,Vector3(280,78,281),Vector3(191,29,185))
	await shot(game,"city-overview")
	await camera_at(game,Vector3(250,20,234),Vector3(261,15,219))
	await measure(game,"boulevard")
	await shot(game,"city-traffic")
	await camera_at(game,Vector3(323,32,112),Vector3(299,15,79))
	await shot(game,"city-terminal")
	await camera_at(game,Vector3(145,17,159),Vector3(138,17,143))
	await shot(game,"city-lobby")
	print("CITY CAPTURE PASS")
	game.get_tree().quit()

static func shot(game: Node3D,name: String) -> void:
	for i in 3: await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://artifacts/"+name+".png")

static func camera_at(game: Node3D,at: Vector3,target: Vector3) -> void:
	game.player.position = at-Vector3(0,1.62,0)
	game.player.camera.global_position = at
	game.player.camera.look_at(target)
	game.player.camera.fov = 68
	game.world.update_stream(at,true)
	while not game.world.build_queue.is_empty():
		game.world.build_chunk(game.world.build_queue.pop_front())
		await game.get_tree().process_frame
	for i in 45: await game.get_tree().process_frame

static func stream_at(game: Node3D,at: Vector3) -> void:
	game.world.update_stream(at,true)
	while not game.world.build_queue.is_empty():
		game.world.build_chunk(game.world.build_queue.pop_front())
		await game.get_tree().process_frame

static func measure(game: Node3D,label: String) -> void:
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 180:
		await game.get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now-last)/1000.0)
		last = now
	times.sort()
	print("CITY RENDER %s: %d FPS, median %.1f ms, p95 %.1f ms on %s" % [label,Engine.get_frames_per_second(),times[90],times[171],RenderingServer.get_video_adapter_name()])
