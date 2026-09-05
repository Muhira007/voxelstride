extends RefCounted

const NAMES := ["Udara", "Rumput", "Tanah", "Batu", "Kayu", "Daun", "Pasir", "Bata", "Papan", "Batuan dasar"]
const COLORS := [Color.TRANSPARENT, Color("76a744"), Color("986547"), Color("89919a"), Color("886040"), Color("467b46"), Color("d7c28b"), Color("b8664c"), Color("b98d58"), Color("3e444b")]
const TILE_SIZE := 16
const TILES := 12

static func tile_for(block: int, normal: Vector3i) -> int:
	match block:
		1: return 0 if normal.y > 0 else (2 if normal.y < 0 else 1)
		2: return 2
		3: return 3
		4: return 5 if normal.y != 0 else 4
		5: return 6
		6: return 7
		7: return 8
		8: return 9
		9: return 10
	return 3

static func make_material() -> StandardMaterial3D:
	var img := Image.create(TILE_SIZE * TILES, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 73017
	var bases := [Color("76a744"), Color("986547"), Color("986547"), Color("89919a"), Color("886040"), Color("c49b65"), Color("467b46"), Color("d7c28b"), Color("b8664c"), Color("b98d58"), Color("3e444b"), Color.WHITE]
	for t in TILES:
		for y in TILE_SIZE:
			for x in TILE_SIZE:
				var c: Color = bases[t]
				var shade := rng.randf_range(-0.075, 0.07)
				if t == 1 and y < 3 + (x * 7 % 3): c = bases[0]
				if t == 4 and (x % 5 == 0 or (x + y / 6) % 9 == 0): shade -= 0.18
				if t == 5:
					var ring: int = int(maxi(absi(x - 7), absi(y - 7)))
					if ring % 3 == 0: shade -= 0.17
				if t == 6 and (x * 7 + y * 3) % 11 < 3: shade -= 0.14
				if t == 8 and (y % 8 == 0 or (x + (8 if y >= 8 else 0)) % 16 == 0): c = Color("c3b5a1")
				if t == 9 and (y % 5 == 0 or (x + y / 5 * 7) % 16 == 0): shade -= 0.17
				img.set_pixel(t * TILE_SIZE + x, y, Color(clampf(c.r + shade, 0, 1), clampf(c.g + shade, 0, 1), clampf(c.b + shade, 0, 1)))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(img)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	return material
