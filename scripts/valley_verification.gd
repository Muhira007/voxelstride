extends RefCounted

const Blocks = preload("res://scripts/blocks.gd")

static func smoke(game: Node3D) -> void:
	var test_root := "user://valley-smoke-"+str(Time.get_ticks_usec())
	game.automation_save_root = test_root
	game.store.prepare_world("farm",test_root)
	game._world_picker()
	game.world_picker.reveal("valley")
	await game._simulate_pad_button(JOY_BUTTON_A)
	while game.loading_world: await game.get_tree().process_frame
	game._smoke_check(game.active_world_id == "valley" and game.menu_state == "playing","Xbox A selects third world")
	for i in 90: await game.get_tree().physics_frame
	game._smoke_check(game.player.is_on_floor(),"valley spawn has collision")
	game._smoke_check(game.world.size == 384 and game.world.height == 80,"valley has four times farm area and double height")
	game._smoke_check(game.world.far_landscape.patches.size() == 576 and game.world.chunks.size() == 49,"whole landscape preview with bounded nearby collision")
	game._smoke_check(game.herd.animals.size() == 20 and game.herd.animals[0].position.y>20,"livestock positioned in elevated valley")
	game._smoke_check(game.waterfall.sound.playing and game.waterfall.sound.stream.data.size() == 88200,"procedural local water audio starts")
	game._show_menu("pause")
	var time: float = game.waterfall.elapsed
	for i in 20: await game.get_tree().process_frame
	game._smoke_check(game.waterfall.elapsed == time and game.waterfall.sound.stream_paused,"pause freezes waterfall and sound")
	game._start_playing()
	for i in 20: await game.get_tree().process_frame
	game._smoke_check(game.waterfall.elapsed>time and not game.waterfall.sound.stream_paused,"waterfall animation and sound resume")
	var farm_path: String = game.store.world_path("farm",test_root)
	var farm_hash := FileAccess.get_sha256(farm_path)
	var edit := Vector3i(378,72,378)
	game.world.set_block(edit,Blocks.id("sea_lantern"))
	# Stand on a test-only platform beyond both previous worlds and their old ceiling.
	for x in range(373,376):
		for z in range(373,376): game.world.set_block(Vector3i(x,65,z),3)
	game.player.position = Vector3(374.5,68.1,374.5)
	game.player.velocity = Vector3.ZERO
	game.world.update_stream(game.player.position,true)
	while not game.world.build_queue.is_empty():
		game.world.build_chunk(game.world.build_queue.pop_front())
		await game.get_tree().process_frame
	for i in 90: await game.get_tree().physics_frame
	game._smoke_check(game.player.is_on_floor() and game.player.position.y>65,"high-altitude distant chunk has real collision")
	game._smoke_check(game.world.chunks.size()<=81,"exploration never loads entire detail world")
	game.hotbar[0] = Blocks.id("hay_bale")
	game._select_block(0)
	game._smoke_check(game._save_world(),"valley saves high-altitude player edits and hotbar")
	game._smoke_check(FileAccess.get_sha256(farm_path) == farm_hash,"valley play does not alter farm save")
	game._smoke_check(await game._choose_world("classic"),"switch away from valley")
	game._smoke_check(not is_instance_valid(game.waterfall) and not is_instance_valid(game.world.far_landscape),"leaving valley removes effect and distant terrain")
	game._smoke_check(await game._choose_world("valley"),"resume saved valley")
	game._smoke_check(game.player.position.x>370 and game.player.position.y>65 and game.world.get_block(edit) == Blocks.id("sea_lantern") and game.hotbar[0] == Blocks.id("hay_bale"),"valley restores position above old ceiling, high edits and hotbar")
	game._smoke_check(await game._choose_world("farm") and game.world.height == 40,"farm still resumes with original height")
	game._show_menu("pause")
	game.automation_save_root = ""
	for sub in [test_root.path_join("worlds"),test_root]:
		var dir := DirAccess.open(sub)
		for file in dir.get_files(): dir.remove(file)
		DirAccess.remove_absolute(sub)
	print("VALLEY SMOKE: third-world selection, streaming, waterfall pause, isolated saves and high-altitude restore checked")

static func capture(game: Node3D) -> void:
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://artifacts/valley-worlds.png")
	await game._choose_world("valley")
	for i in 120: await game.get_tree().process_frame
	game.hud.toast_time = 0
	await shot(game,"valley-gameplay")
	await measure(game,"village")
	game.player.enabled = false
	game.hud.hide()
	game.held_block.hide()
	game.outline.hide()
	game.set_process(false)
	await camera_at(game,Vector3(227,27,119),Vector3(252,37,94))
	await measure(game,"waterfall")
	await shot(game,"valley-waterfall")
	await camera_at(game,Vector3(309,78,298),Vector3(208,23,181))
	await shot(game,"valley-overview")
	await camera_at(game,Vector3(110,41,203),Vector3(88,27,165))
	await shot(game,"valley-terraces")
	await camera_at(game,Vector3(318,68,357),Vector3(292,21,327))
	await shot(game,"valley-lake")
	await camera_at(game,Vector3(335,67,242),Vector3(326,55,213))
	await shot(game,"valley-tower")
	print("VALLEY CAPTURE PASS: selection, gameplay, waterfall, overview, terraces, lake, tower")
	game.get_tree().quit()

static func camera_at(game: Node3D,at: Vector3,target: Vector3) -> void:
	game.player.camera.global_position = at
	game.player.camera.look_at(target)
	game.player.camera.fov = 65
	game.world.update_stream(at,true)
	game.herd.view_position = at
	while not game.world.build_queue.is_empty():
		game.world.build_chunk(game.world.build_queue.pop_front())
		await game.get_tree().process_frame
	for i in 30: await game.get_tree().process_frame

static func shot(game: Node3D,name: String) -> void:
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://artifacts/"+name+".png")

static func measure(game: Node3D,label: String) -> void:
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 180:
		await game.get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now-last)/1000.0)
		last = now
	times.sort()
	print("VALLEY RENDER %s: %d FPS, median %.1f ms, p95 %.1f ms on %s" % [label,Engine.get_frames_per_second(),times[90],times[171],RenderingServer.get_video_adapter_name()])
