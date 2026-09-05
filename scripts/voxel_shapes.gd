extends RefCounted

const Blocks = preload("res://scripts/blocks.gd")
const Geometry = preload("res://scripts/box_geometry.gd")
static var meshes: Dictionary = {}

static func mesh_for(block: int) -> ArrayMesh:
	if meshes.has(block): return meshes[block]
	var s := Geometry.start()
	var key: String = Blocks.entries[block]["key"]
	if key == "oak_fence":
		Geometry.box(s,Vector3(0.5,0.5,0.5),Vector3(0.22,1.0,0.22),Color("9e7b4e"))
		for y in [0.32,0.76]:
			Geometry.box(s,Vector3(0.5,y,0.5),Vector3(1,0.14,0.12),Color("b69863"))
			Geometry.box(s,Vector3(0.5,y,0.5),Vector3(0.12,0.14,1),Color("b69863"))
	else:
		for i in 4:
			var x := 0.25+(i%2)*0.48
			var z := 0.22+(i/2)*0.48
			var h := 0.66+(i%3)*0.06 if key == "wheat_crop" else 0.32+(i%2)*0.08
			Geometry.box(s,Vector3(x,h/2,z),Vector3(0.055,h,0.055),Color("aaac53") if key == "wheat_crop" else Color("528443"))
			Geometry.box(s,Vector3(x,h*0.55,z),Vector3(0.32,0.055,0.10),Color("829a46"))
			if key == "wheat_crop":
				Geometry.box(s,Vector3(x,h,z),Vector3(0.13,0.22,0.10),Color("d7ba62"))
			elif key == "meadow_flower":
				Geometry.box(s,Vector3(x,h,z),Vector3(0.21,0.08,0.21),Color("e7ab97"))
				Geometry.box(s,Vector3(x,h+0.05,z),Vector3(0.07,0.035,0.07),Color("e6cc69"))
			else:
				Geometry.box(s,Vector3(x,0.07,z),Vector3(0.17,0.14,0.17),Color("d08a39") if key == "carrot_crop" else Color("bda570"))
	meshes[block] = s.commit()
	return meshes[block]
