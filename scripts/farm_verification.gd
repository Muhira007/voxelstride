extends RefCounted

const Blocks = preload("res://scripts/blocks.gd")

# Automated scenarios never read or write the player's real saves.
static func smoke(game: Node3D) -> void:
	var test_root := "user://farm-smoke-"+str(Time.get_ticks_usec())
	game.automation_save_root = test_root
	game.store.prepare_world("classic",test_root)
	game._smoke_check(game._save_world(),"classic saves before switching")
	var classic_path: String = game.store.world_path("classic",test_root)
	game._world_picker()
	game._smoke_check(game.menu_state == "worlds","pause menu opens world selection")
	game.world_picker.reveal("farm")
	await game._simulate_pad_button(JOY_BUTTON_A)
	while game.loading_world: await game.get_tree().process_frame
	game._smoke_check(game.active_world_id == "farm" and game.menu_state == "playing","Xbox A opens selected farm world")
	game._smoke_check(game.world.size == 192 and game.herd.animals.size() == 20,"farm has 4x area and twenty animals")
	for i in 90: await game.get_tree().physics_frame
	game._smoke_check(game.player.is_on_floor(),"farm player lands safely")
	var classic_hash := FileAccess.get_sha256(classic_path)
	var farm_cell := Vector3i(183,30,181)
	game.world.set_block(farm_cell,Blocks.id("hay_bale"))
	game.hotbar[0] = Blocks.id("wheat_crop")
	game._select_block(0)
	game.player.position = Vector3(132,14.1,72)
	game.world.update_stream(game.player.position,true)
	while not game.world.build_queue.is_empty():
		game.world.build_chunk(game.world.build_queue.pop_front())
		await game.get_tree().process_frame
	for i in 30: await game.get_tree().physics_frame
	var before := []
	for animal in game.herd.animals: before.append(animal.position)
	for i in 240: await game.get_tree().physics_frame
	var moved := 0
	for i in game.herd.animals.size():
		var animal: CharacterBody3D = game.herd.animals[i]
		if animal.position.distance_to(before[i])>0.1: moved += 1
		game._smoke_check(animal.pen.has_point(Vector2(animal.position.x,animal.position.z)) and animal.position.y > 13,"animal stays inside safe pen: %d" % i)
	game._smoke_check(moved >= 5,"multiple animals actually walk")
	game._show_menu("pause")
	var paused_animal: Vector3 = game.herd.animals[0].position
	for i in 20: await game.get_tree().physics_frame
	game._smoke_check(game.herd.animals[0].position == paused_animal,"pause freezes livestock")
	var animal_cell := Vector3i(game.herd.animals[0].position)
	game.target = {"cell":animal_cell+Vector3i.DOWN,"previous":animal_cell,"block":1}
	game._smoke_check(not game._edit_block(true),"cannot place a block inside an animal")
	game._smoke_check(game._save_world(),"farm save writes player hotbar edits and livestock")
	var farm_path: String = game.store.world_path("farm",test_root)
	game._smoke_check(FileAccess.get_sha256(classic_path) == classic_hash,"farm save leaves classic file untouched")
	var farm_saved: Dictionary = game.store.read_world("farm",test_root)
	game._smoke_check(farm_saved.get("animals",[]).size() == 20,"all animal snapshots persisted")
	game._smoke_check(await game._choose_world("classic"),"switch back to classic")
	game._smoke_check(game.world.size == 96 and not is_instance_valid(game.herd),"classic has original dimensions and no livestock")
	game._smoke_check(await game._choose_world("farm"),"farm can be resumed")
	game._smoke_check(game.world.get_block(farm_cell) == Blocks.id("hay_bale") and game.hotbar[0] == Blocks.id("wheat_crop"),"farm edits and hotbar survive world switches")
	game._smoke_check(game.player.position.x > 96,"saved player beyond classic boundary restores correctly")
	game._show_menu("pause")
	# A save failure must prevent abandoning the current world.
	game.automation_save_root = test_root.path_join("missing")
	game._smoke_check(not await game._choose_world("classic") and game.active_world_id == "farm","failed save blocks world switch")
	game.automation_save_root = test_root
	game._show_menu("pause")
	# Render-distance deactivation does not advance remote animals.
	game.herd.enabled = true
	game.herd.view_position = Vector3(0,14,0)
	game.herd.timer = 0
	game.herd._process(0.3)
	game._smoke_check(not game.herd.animals[0].is_physics_processing(),"far-away livestock AI deactivated")
	game.herd.pause()
	game.automation_save_root = ""
	for sub in [test_root.path_join("worlds"),test_root]:
		var dir := DirAccess.open(sub)
		for file in dir.get_files(): dir.remove(file)
		DirAccess.remove_absolute(sub)
	print("FARM SMOKE: save isolation, world switching, livestock movement, pause and restore checked")

static func capture(game: Node3D) -> void:
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://artifacts/worlds.png")
	await game._choose_world("farm")
	for i in 120: await game.get_tree().process_frame
	game.hud.toast_time = 0
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://artifacts/farm-gameplay.png")
	print("FARM RENDER: %d FPS on %s" % [Engine.get_frames_per_second(),RenderingServer.get_video_adapter_name()])
	game.player.enabled = false
	game.hud.hide()
	game.held_block.hide()
	game.outline.hide()
	game.set_process(false)
	game.player.camera.global_position = Vector3(157,83,176)
	game.player.camera.look_at(Vector3(101,14,94))
	game.player.camera.fov = 60
	game.player.camera.far = 210
	game.environment.fog_density = 0.0015
	# Full-world overview is a QA-only bird's-eye shot, not the normal streaming workload.
	game.world.streaming = false
	game.world.build_queue.clear()
	for x in game.world.size/16:
		for z in game.world.size/16:
			if not game.world.chunks.has(Vector2i(x,z)):
				game.world.build_chunk(Vector2i(x,z))
				await game.get_tree().process_frame
	for i in 10: await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://artifacts/farm-overview.png")
	game.player.camera.global_position = Vector3(131,21,96)
	game.player.camera.look_at(Vector3(131,14.5,74))
	game.player.camera.fov = 60
	game.herd.view_position = Vector3(132,14,74)
	game.world.update_stream(Vector3(132,14,74),true)
	while not game.world.build_queue.is_empty():
		game.world.build_chunk(game.world.build_queue.pop_front())
		await game.get_tree().process_frame
	for i in 180: await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://artifacts/farm-animals.png")
	game.player.camera.global_position = Vector3(86,24,93)
	game.player.camera.look_at(Vector3(70,14.5,64))
	for i in 10: await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://artifacts/farm-fields.png")
	print("FARM CAPTURE PASS: worlds, gameplay, overview, animals, fields")
	game.get_tree().quit()
