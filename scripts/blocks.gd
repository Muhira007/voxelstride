extends RefCounted

const Painter = preload("res://scripts/block_textures.gd")
const CATEGORIES := ["Semua", "Alam", "Batu", "Kayu", "Bangunan", "Warna", "Kaca & Cahaya", "Logam"]
const TILE_SIZE := 32
const PADDING := 4
const PITCH := TILE_SIZE + PADDING * 2
const COLUMNS := 16
const DEFAULT_HOTBAR := [1, 2, 3, 4, 5, 6, 7, 8]
# IDs 0..9 are permanent: older saves use these exact numeric values.
static var entries: Array[Dictionary] = []
static var NAMES: Array[String] = []
static var COLORS: Array[Color] = []
static var lookup: Dictionary = {}
static var materials: Array[StandardMaterial3D] = []
static var tile_images: Dictionary = {}
static var icons: Dictionary = {}
static var atlas_size := Vector2i.ZERO

static func setup() -> void:
	if not entries.is_empty(): return
	_add("air", "Udara", "Alam", "ffffff", "plain")
	_add("grass", "Rumput", "Alam", "658349", "grass")
	_add("dirt", "Tanah", "Alam", "84644b", "dirt")
	_add("stone", "Batu", "Batu", "888c8c", "stone")
	_add("oak_log", "Kayu Oak", "Kayu", "786044", "log")
	_add("oak_leaves", "Daun Oak", "Alam", "527647", "leaves")
	_add("sand", "Pasir", "Alam", "d8c591", "sand")
	_add("bricks", "Bata Merah", "Bangunan", "aa6252", "bricks")
	_add("oak_planks", "Papan Oak", "Kayu", "b39160", "planks")
	_add("bedrock", "Batuan Dasar", "Batu", "484951", "cobble")
	for row in [
		["coarse_dirt", "Tanah Kasar", "7a5e49", "gravel"], ["podzol", "Podzol", "74593b", "soil"],
		["mud", "Lumpur", "55504d", "dirt"], ["clay", "Lempung", "9da5af", "smooth"],
		["red_sand", "Pasir Merah", "b27648", "sand"], ["gravel", "Kerikil", "89827b", "gravel"],
		["snow", "Salju", "e3e9e7", "sand"], ["moss", "Lumut", "667c43", "moss"],
		["packed_ice", "Es Padat", "8dafc7", "ice"], ["blue_ice", "Es Biru", "6599bd", "ice"]
	]: _add(row[0], row[1], "Alam", row[2], row[3])
	for row in [
		["cobblestone", "Cobblestone", "888b84", "cobble"], ["mossy_cobblestone", "Cobble Berlumut", "7d8670", "moss_cobble"],
		["smooth_stone", "Batu Halus", "a2a6a5", "smooth"], ["stone_bricks", "Bata Batu", "898d87", "bricks"],
		["mossy_stone_bricks", "Bata Batu Berlumut", "858a76", "moss_bricks"], ["cracked_stone_bricks", "Bata Batu Retak", "858880", "cracked_bricks"],
		["chiseled_stone_bricks", "Batu Pahat", "989c92", "chiseled"], ["granite", "Granit", "a97e6b", "granite"],
		["polished_granite", "Granit Poles", "b48875", "polished"], ["diorite", "Diorit", "c3c4bc", "granite"],
		["polished_diorite", "Diorit Poles", "cacdc6", "polished"], ["andesite", "Andesit", "8d9390", "granite"],
		["polished_andesite", "Andesit Poles", "a0a5a2", "polished"], ["deepslate", "Deepslate", "51545a", "slate"],
		["cobbled_deepslate", "Cobble Deepslate", "55575c", "cobble"], ["polished_deepslate", "Deepslate Poles", "62646a", "polished"],
		["deepslate_bricks", "Bata Deepslate", "53565b", "bricks"], ["deepslate_tiles", "Ubin Deepslate", "494e55", "tiles"],
		["tuff", "Tuff", "878a7b", "stone"], ["tuff_bricks", "Bata Tuff", "828c80", "bricks"],
		["calcite", "Kalsit", "dad6c6", "marble"], ["basalt", "Basalt", "696c72", "slate"],
		["smooth_basalt", "Basalt Halus", "74777c", "smooth"], ["blackstone", "Blackstone", "49444d", "cobble"],
		["polished_blackstone", "Blackstone Poles", "554c57", "polished"], ["obsidian", "Obsidian", "302936", "obsidian"]
	]: _add(row[0], row[1], "Batu", row[2], row[3])
	_add("stripped_oak_log", "Oak Kupas", "Kayu", "b79a6a", "stripped")
	for row in [
		["spruce", "Spruce", "564436", "99794f", "b08b5e", "405c47"],
		["birch", "Birch", "d4d3ba", "d3c292", "d4c8a1", "77934e"],
		["dark_oak", "Dark Oak", "493c30", "66503b", "7b6348", "496440"],
		["cherry", "Cherry", "614146", "d7a7a0", "b78d80", "c795ad"],
		["mangrove", "Mangrove", "68534a", "9e6255", "aa7766", "597149"],
		["jungle", "Jungle", "75604b", "b78c6a", "b28d60", "497849"],
		["acacia", "Acacia", "81776b", "b7784f", "b7835e", "68804a"],
		["bamboo", "Bambu", "93975a", "c3ac65", "ceba76", "7f974b"],
		["crimson", "Crimson", "743e50", "864b61", "96576b", "8b4058"],
		["warped", "Warped", "465f5b", "47857c", "56998b", "3e8880"]
	]:
		_add(row[0]+"_log", "Kayu "+row[1], "Kayu", row[2], "birch" if row[0] == "birch" else "log")
		_add(row[0]+"_planks", "Papan "+row[1], "Kayu", row[3], "planks")
		_add("stripped_"+row[0]+"_log", row[1]+" Kupas", "Kayu", row[4], "stripped")
		if row[0] == "bamboo":
			_add("bamboo_mosaic", "Mosaik Bambu", "Kayu", row[3], "tiles")
		elif row[0] == "crimson":
			_add("nether_wart_block", "Blok Nether Wart", "Alam", row[5], "moss")
		elif row[0] == "warped":
			_add("warped_wart_block", "Blok Warped Wart", "Alam", row[5], "moss")
		else:
			_add(row[0]+"_leaves", "Daun "+row[1], "Alam", row[5], "leaves")
	for row in [
		["mud_bricks", "Bata Lumpur", "92795e", "bricks"], ["nether_bricks", "Bata Nether", "52353e", "bricks"],
		["red_nether_bricks", "Bata Nether Merah", "813d3b", "bricks"], ["sandstone", "Batu Pasir", "cbb780", "sandstone"],
		["cut_sandstone", "Batu Pasir Potong", "d2be8b", "polished"], ["smooth_sandstone", "Batu Pasir Halus", "dcc993", "smooth"],
		["chiseled_sandstone", "Batu Pasir Pahat", "cdb986", "chiseled"], ["red_sandstone", "Batu Pasir Merah", "b57a4a", "sandstone"],
		["smooth_red_sandstone", "Pasir Merah Halus", "be8556", "smooth"], ["quartz", "Kuarsa", "e0dcd1", "marble"],
		["smooth_quartz", "Kuarsa Halus", "e9e4d9", "smooth"], ["quartz_bricks", "Bata Kuarsa", "dfdad0", "bricks"],
		["quartz_pillar", "Pilar Kuarsa", "e0dbcc", "pillar"], ["purpur", "Purpur", "a78fa8", "tiles"],
		["end_stone_bricks", "Bata End Stone", "c9cb99", "bricks"], ["resin_bricks", "Bata Resin", "c37d42", "bricks"]
	]: _add(row[0], row[1], "Bangunan", row[2], row[3])
	const DYES := [
		["white","Putih","dddcd1"], ["orange","Jingga","d18c43"], ["magenta","Magenta","b067a6"], ["light_blue","Biru Muda","79afc3"],
		["yellow","Kuning","d5b855"], ["lime","Hijau Muda","91b04e"], ["pink","Merah Muda","d097a9"], ["gray","Abu Gelap","555d61"],
		["light_gray","Abu Muda","adb1a6"], ["cyan","Sian","478b91"], ["purple","Ungu","806696"], ["blue","Biru","526d9d"],
		["brown","Cokelat","81604b"], ["green","Hijau","667e48"], ["red","Merah","a75c50"], ["black","Hitam","32383b"]
	]
	for family in [["concrete","Beton","concrete"], ["terracotta","Terakota","terracotta"], ["wool","Wol","wool"]]:
		for dye in DYES:
			var color := Color(dye[2])
			if family[0] == "terracotta": color = color.lerp(Color("a97759"), 0.38)
			_add(dye[0]+"_"+family[0], family[1]+" "+dye[1], "Warna", color.to_html(false), family[2])
	_add("glass", "Kaca Bening", "Kaca & Cahaya", "b4d5d9", "glass", true)
	for dye in DYES: _add(dye[0]+"_glass", "Kaca "+dye[1], "Kaca & Cahaya", dye[2], "glass", true)
	for row in [["glowstone","Glowstone","dbb978"], ["sea_lantern","Lentera Laut","abd3c9"], ["shroomlight","Shroomlight","d89562"]]:
		_add(row[0], row[1], "Kaca & Cahaya", row[2], "lamp", false, true)
	for row in [
		["copper","Tembaga","b57e62"], ["exposed_copper","Tembaga Terpapar","a18a70"], ["weathered_copper","Tembaga Lapuk","6f9684"], ["oxidized_copper","Tembaga Teroksidasi","559c88"],
		["iron_block","Blok Besi","c0c6c4"], ["gold_block","Blok Emas","d7b768"], ["diamond_block","Blok Berlian","71b8b5"], ["emerald_block","Blok Zamrud","58947c"]
	]: _add(row[0], row[1], "Logam", row[2], "metal")
	# Append-only registry: every released ID above remains unchanged.
	_add("farm_soil", "Tanah Ladang", "Alam", "765035", "farmland")
	_add("water", "Air Kolam", "Alam", "4e9eb2", "water", true)
	_add("hay_bale", "Bal Jerami", "Bangunan", "c3a354", "hay")
	_add("pumpkin", "Labu", "Alam", "cd8839", "pumpkin")
	_add("apple_leaves", "Daun Berbuah Apel", "Alam", "58804a", "apple_leaves")
	_add("wheat_crop", "Tanaman Gandum", "Alam", "c5b05c", "crop", false, false, "crop")
	_add("carrot_crop", "Tanaman Wortel", "Alam", "62a34c", "crop", false, false, "crop")
	_add("potato_crop", "Tanaman Kentang", "Alam", "7b9c4c", "crop", false, false, "crop")
	_add("oak_fence", "Pagar Oak", "Kayu", "a58454", "fence", false, false, "fence")
	_add("meadow_flower", "Bunga Padang", "Alam", "dcad8a", "crop", false, false, "crop")

static func _add(key: String, label: String, category: String, color: String, pattern: String, transparent: bool = false, emissive: bool = false, shape: String = "cube") -> void:
	lookup[key] = entries.size()
	entries.append({"key":key, "name":label, "category":category, "color":Color(color), "pattern":pattern, "transparent":transparent, "emissive":emissive, "shape":shape})
	NAMES.append(label)
	COLORS.append(Color(color))

static func id(key: String) -> int:
	setup()
	return int(lookup.get(key, -1))

static func is_placeable(block: int) -> bool:
	setup()
	return block > 0 and block < entries.size() and block != 9

static func valid_edit(block: int) -> bool:
	return block == 0 or is_placeable(block)

static func is_transparent(block: int) -> bool:
	return block > 0 and block < entries.size() and entries[block]["transparent"]

static func occludes(block: int) -> bool:
	return block != 0 and shape_of(block) == "cube" and not is_transparent(block)

static func shape_of(block: int) -> String:
	return entries[block]["shape"]

static func is_solid(block: int) -> bool:
	return block != 0 and shape_of(block) != "crop" and entries[block]["key"] != "water"

static func face_visible(block: int, neighbor: int) -> bool:
	return neighbor == 0 or shape_of(neighbor) != "cube" or (is_transparent(neighbor) and not is_transparent(block))

static func catalog(category: String = "Semua", search: String = "") -> Array[int]:
	setup()
	var result: Array[int] = []
	for block in range(1, entries.size()):
		if not is_placeable(block): continue
		var entry := entries[block]
		if category != "Semua" and entry["category"] != category: continue
		if not search.is_empty() and not (entry["name"] + " " + entry["key"]).to_lower().contains(search.to_lower().strip_edges()): continue
		result.append(block)
	return result

static func restore_hotbar(value: Variant) -> Array[int]:
	var result: Array[int] = []
	for i in 8:
		var block: Variant = value[i] if value is Array and value.size() == 8 else DEFAULT_HOTBAR[i]
		result.append(int(block) if (block is int or block is float) and is_finite(float(block)) and float(block) == int(block) and is_placeable(int(block)) else DEFAULT_HOTBAR[i])
	return result

static func tile_for(block: int, normal: Vector3i) -> int:
	return block * 3 + (0 if normal.y > 0 else (2 if normal.y < 0 else 1))

static func uv_for(tile: int, uv: Vector2) -> Vector2:
	return (Vector2(tile % COLUMNS, tile / COLUMNS) * PITCH + Vector2.ONE * (PADDING + 0.5) + uv * (TILE_SIZE - 1)) / Vector2(atlas_size)

static func tile_image(block: int, face: int = 1) -> Image:
	setup()
	var key := block * 3 + face
	if not tile_images.has(key): tile_images[key] = Painter.paint(entries[block], face, block)
	return tile_images[key]

static func make_material(glass: bool = false) -> StandardMaterial3D:
	if materials.is_empty(): _build_atlas()
	return materials[1 if glass else 0]

static func _build_atlas() -> void:
	setup()
	var total := entries.size() * 3
	atlas_size = Vector2i(COLUMNS * PITCH, ceili(float(total) / COLUMNS) * PITCH)
	var atlas := Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
	var emission := Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGB8)
	var roughness := Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGB8)
	for tile in total:
		var block := tile / 3
		var img := tile_image(block, tile % 3)
		var origin := Vector2i(tile % COLUMNS, tile / COLUMNS) * PITCH
		var rough := 0.32 if entries[block]["pattern"] == "metal" else 0.95
		for y in PITCH:
			for x in PITCH:
				var c := img.get_pixel(clampi(x-PADDING,0,31), clampi(y-PADDING,0,31))
				atlas.set_pixelv(origin+Vector2i(x,y), c)
				if entries[block]["emissive"]: emission.set_pixelv(origin+Vector2i(x,y), c)
				roughness.set_pixelv(origin+Vector2i(x,y), Color(rough,rough,rough))
	atlas.generate_mipmaps()
	emission.generate_mipmaps()
	roughness.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(atlas)
	# Runtime-generated images need explicit sRGB decoding in the Compatibility renderer.
	mat.albedo_texture_force_srgb = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	mat.vertex_color_use_as_albedo = true
	mat.roughness_texture = ImageTexture.create_from_image(roughness)
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.metallic_specular = 0.2
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mat.emission_texture = ImageTexture.create_from_image(emission)
	mat.emission_energy_multiplier = 0.65
	materials.append(mat)
	var transparent := mat.duplicate() as StandardMaterial3D
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	transparent.cull_mode = BaseMaterial3D.CULL_DISABLED
	transparent.roughness = 0.12
	transparent.roughness_texture = null
	transparent.emission_enabled = false
	materials.append(transparent)

static func icon(block: int) -> Texture2D:
	if icons.has(block): return icons[block]
	var img := Image.create(64,64,false,Image.FORMAT_RGBA8)
	var top := tile_image(block,0)
	var side := tile_image(block,1)
	for y in 64:
		for x in 64:
			var p := Vector2(x+0.5,y+0.5)
			var c := Color.TRANSPARENT
			var a := (p.x-32)/52 + (p.y-5)/26
			var b := -(p.x-32)/52 + (p.y-5)/26
			if a >= 0 and a < 1 and b >= 0 and b < 1:
				c = top.get_pixel(int(a*32),int(b*32)).lightened(0.08)
			else:
				var u := (p.x-6)/26
				var v := (p.y-18-u*13)/28
				if u >= 0 and u < 1 and v >= 0 and v < 1: c = side.get_pixel(int(u*32),int(v*32)).darkened(0.22)
				u = (p.x-32)/26
				v = (p.y-31+u*13)/28
				if u >= 0 and u < 1 and v >= 0 and v < 1: c = side.get_pixel(int(u*32),int(v*32)).darkened(0.05)
			if c.a > 0: c.a = maxf(c.a,0.5)
			img.set_pixel(x,y,c)
	icons[block] = ImageTexture.create_from_image(img)
	return icons[block]
