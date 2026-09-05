extends RefCounted

# Original 32px material studies: coherent forms first, fine grain second.
static func grain(x: int, y: int, seed_value: int) -> float:
	var value := (x * 374761393 + y * 668265263 + seed_value * 1274126177) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return float(value % 10000) / 10000.0

static func paint(entry: Dictionary, face: int, seed_value: int) -> Image:
	var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	var base: Color = entry["color"]
	var pattern: String = entry["pattern"]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value * 73 + 409
	noise.frequency = 0.12
	noise.fractal_octaves = 3
	for y in 32:
		for x in 32:
			var n := noise.get_noise_2d(x,y)
			var fine := (grain(x,y,seed_value)-0.5) * 0.025
			var shade := n * 0.12 + fine
			var color := base
			match pattern:
				"grass", "soil":
					if face == 2 or (face == 1 and y > 5 + int(grain(x/3,0,1)*4)):
						color = Color("82644c")
						shade = n * 0.16 + fine
					elif face == 1:
						shade += 0.015 if y < 2 else -0.02
					else:
						shade = n * 0.13 + fine
						if (x*5+y*3)%23 < 2: shade += 0.035
				"dirt", "terracotta", "sand", "concrete", "smooth":
					shade = n * (0.13 if pattern == "dirt" else 0.045) + fine * (0.5 if pattern == "smooth" else 1)
					if pattern == "dirt" and grain(x/2,y/2,seed_value) > 0.94: shade += 0.09
					if pattern == "sand" and y % 9 == 0: shade += n * 0.025
				"stone", "slate", "sandstone", "obsidian", "marble", "ice":
					var band := sin(float(y) * 0.52 + n * 3.5 + float(x) * 0.10)
					shade += band * 0.025
					if pattern == "slate":
						if posmod(y + int(n*3),8) == 0: shade -= 0.09
					if pattern == "sandstone" and y % 8 == 0: shade -= 0.055
					if pattern == "marble" or pattern == "ice":
						shade *= 0.5
						if absf(sin(x*0.2+y*0.29+n*1.8)) < 0.12: shade -= 0.07
					if pattern == "obsidian": shade += pow(absf(n),0.5) * 0.1
				"granite", "gravel":
					shade = n * 0.10 + (grain(x/2,y/2,seed_value)-0.5) * 0.19 + fine
					if pattern == "granite" and grain(x/2,y/2,seed_value) > 0.85: color = color.lightened(0.12)
				"cobble", "moss_cobble", "lamp":
					var row := y/8
					var xx := posmod(x + (row%2)*7, 16)
					var yy := y%8
					shade += (grain((x+(row%2)*7)/16,row,seed_value)-0.5)*0.12
					if yy == 0 or xx == 0 or (xx == 1 and yy > 5): shade -= 0.20
					elif yy == 1 or xx == 1: shade += 0.055
					elif yy == 7 or xx == 15: shade -= 0.05
					if pattern == "moss_cobble" and n > 0.06: color = color.lerp(Color("566d38"),0.7)
					if pattern == "lamp":
						color = color.lightened(0.10)
						if entry["key"] == "sea_lantern":
							shade = fine
							color = Color("dfecdf") if x > 3 and x < 28 and y > 3 and y < 28 else base
				"bricks", "moss_bricks", "cracked_bricks", "tiles":
					var height := 8 if pattern != "tiles" else 4
					var row := y/height
					var xx := posmod(x + (row%2)*8,16)
					var yy := y%height
					shade += (grain((x+(row%2)*8)/16,row,seed_value)-0.5)*0.07
					if yy == 0 or xx == 0:
						color = base.darkened(0.29)
						shade = fine
					elif yy == 1 or xx == 1: shade += 0.045
					elif yy == height-1: shade -= 0.035
					if pattern == "moss_bricks" and n > 0.04: color = color.lerp(Color("556c3e"),0.7)
					if pattern == "cracked_bricks" and posmod(x+int(n*7)+y/4,15) == 0: shade -= 0.13
				"polished", "metal", "chiseled", "pillar":
					shade = n * 0.055 + fine * 0.5
					if x == 0 or y == 0: shade += 0.06
					if x == 31 or y == 31: shade -= 0.10
					if pattern == "metal":
						shade += (1.0-float(y)/31)*0.04
						if (x == 3 or x == 28) and (y == 3 or y == 28): shade -= 0.22
						if entry["key"].contains("copper"): shade += n * 0.10
					if pattern == "chiseled":
						var ring := maxi(absi(x-15),absi(y-15))
						if ring == 11 or ring == 7 or ring == 3: shade -= 0.15
						elif ring == 10 or ring == 6: shade += 0.08
					if pattern == "pillar" and face == 1: shade += sin(float(x)*PI/4) * 0.06
				"log", "birch", "stripped", "planks":
					if pattern != "planks" and face != 1:
						color = base.lightened(0.24) if pattern != "stripped" else base
						var dist := Vector2(x-15.5,y-15.5).length() + n * 1.8
						shade = sin(dist*1.8) * 0.045 + fine
						if maxi(absi(x-15),absi(y-15)) > 13: color = base.darkened(0.13)
					elif pattern == "planks":
						var row := y/8
						shade = sin(y*2.6+n*2.5+x*0.07)*0.025+n*0.045+fine
						if y%8 == 0 or posmod(x+row*11,32) == 0: shade -= 0.13
						elif y%8 == 1: shade += 0.045
						if posmod(x+row*11,32) == 2 and (y%8 == 2 or y%8 == 6): shade -= 0.12
					else:
						shade = sin(x*1.6+n*2.3) * (0.075 if pattern != "stripped" else 0.025) + fine
						shade += sin(x*0.6+n*0.8)*0.035
						if pattern == "birch" and y%11 < 2 and grain(x/5,y/11,seed_value) > 0.5: shade -= 0.35
				"leaves", "moss":
					shade = n * 0.14 + fine
					var lx := posmod(x+(y/4%2)*3,7)
					var ly := y%4
					if lx == 0 or ly == 0: shade -= 0.06
					elif lx < 3 and ly == 1: shade += 0.04
				"wool":
					shade = n * 0.04 + fine
					shade += 0.018 if (x+y)%4 < 2 else -0.018
					if y%4 == 0: shade -= 0.02
				"glass":
					shade = 0
					color = base.lightened(0.2)
					color.a = 0.18
					if x == 0 or y == 0 or x == 31 or y == 31: color.a = 0.9
					elif x == 1 or y == 1: color.a = 0.55
					elif (x+y >= 15 and x+y <= 16) or (x+y >= 21 and x+y <= 22): color.a = 0.32
			image.set_pixel(x,y,Color(clampf(color.r+shade,0,1),clampf(color.g+shade,0,1),clampf(color.b+shade,0,1),color.a))
	return image
