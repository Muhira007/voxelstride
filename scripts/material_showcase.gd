extends RefCounted

const Blocks = preload("res://scripts/blocks.gd")

# A reproducible visual QA scene. Only called by --capture on an isolated, unsaved world.
static func capture(game: Node3D) -> void:
	assert(game.automation)
	game.inventory.hide()
	game.hud.hide()
	game.player.enabled = false
	game.set_process(false)
	game.held_block.hide()
	game.outline.hide()
	var world: Node3D = game.world
	for x in range(39,60):
		for z in range(35,53):
			for y in range(25,34): world.set_block(Vector3i(x,y,z),0)
			world.set_block(Vector3i(x,25,z),Blocks.id("smooth_quartz"))
	# A small facade: brick base, spruce joinery, real transparent windows, luminous interior.
	for x in range(41,48):
		for z in range(37,44):
			world.set_block(Vector3i(x,26,z),Blocks.id("oak_planks"))
			for y in range(27,31):
				if x in [41,47] or z in [37,43]:
					var key := "bricks" if y == 27 else "spruce_planks"
					if x in [41,47]: key = "stripped_spruce_log"
					if z == 43 and x in [43,44,45] and y in [28,29]: key = "glass"
					world.set_block(Vector3i(x,y,z),Blocks.id(key))
	for x in range(40,49):
		for z in range(36,45): world.set_block(Vector3i(x,31,z),Blocks.id("deepslate_tiles"))
	for x in [42,46]: world.set_block(Vector3i(x,29,39),Blocks.id("glowstone"))
	# End-grain, bark, cut stone, metal and color samples under the same world lighting.
	var woods := ["oak_log","birch_log","cherry_log","warped_log"]
	for i in woods.size():
		for y in range(26,30): world.set_block(Vector3i(50+i*2,y,38),Blocks.id(woods[i]))
	var samples := ["stone_bricks","mossy_cobblestone","chiseled_stone_bricks","quartz_pillar","deepslate_bricks","resin_bricks","copper","oxidized_copper",
		"cherry_planks","bamboo_mosaic","cyan_concrete","yellow_terracotta","purple_wool","blue_glass","sea_lantern","shroomlight"]
	for i in samples.size():
		var x := 41+(i%8)*2
		var z := 47+(i/8)*3
		world.set_block(Vector3i(x,26,z),Blocks.id(samples[i]))
		world.set_block(Vector3i(x,27,z),Blocks.id(samples[i]))
	while not world.dirty_chunks.is_empty():
		world.build_chunk(world.dirty_chunks.pop_front())
		await game.get_tree().process_frame
	game.player.camera.fov = 50
	game.player.camera.global_position = Vector3(61,35,61)
	game.player.camera.look_at(Vector3(49,27.5,43))
	world.update_local_lights(Vector3(49,29,45))
	var title := Label.new()
	title.text = "MATERIAL STUDIES\n187 BAHAN  /  TEKSTUR 32 PX  /  DUNIA MINECRAFT 0.3"
	title.position = Vector2(38,25)
	title.add_theme_font_size_override("font_size",20)
	title.add_theme_color_override("font_color",Color("f4f0dd"))
	title.add_theme_color_override("font_shadow_color",Color("233536"))
	title.add_theme_constant_override("shadow_offset_x",1)
	title.add_theme_constant_override("shadow_offset_y",1)
	game.hud.get_parent().add_child(title)
	for i in 10: await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("res://artifacts/materials.png")
