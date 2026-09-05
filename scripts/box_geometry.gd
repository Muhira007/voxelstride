extends RefCounted

static var shared_material: StandardMaterial3D
const FACES := [
	[Vector3(1,0,0),Vector3(1,1,0),Vector3(1,1,1),Vector3(1,0,1)],
	[Vector3(0,0,1),Vector3(0,1,1),Vector3(0,1,0),Vector3(0,0,0)],
	[Vector3(0,1,1),Vector3(1,1,1),Vector3(1,1,0),Vector3(0,1,0)],
	[Vector3(0,0,0),Vector3(1,0,0),Vector3(1,0,1),Vector3(0,0,1)],
	[Vector3(1,0,1),Vector3(1,1,1),Vector3(0,1,1),Vector3(0,0,1)],
	[Vector3(0,0,0),Vector3(0,1,0),Vector3(1,1,0),Vector3(1,0,0)]
]
const NORMALS := [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]

static func start() -> SurfaceTool:
	if shared_material == null:
		shared_material = StandardMaterial3D.new()
		shared_material.vertex_color_use_as_albedo = true
		shared_material.vertex_color_is_srgb = true
		shared_material.roughness = 1.0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(shared_material)
	return surface

static func box(surface: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	for f in 6:
		for i in [0,2,1,0,3,2]:
			surface.set_normal(NORMALS[f])
			surface.set_color(color)
			surface.add_vertex(center+(FACES[f][i]-Vector3.ONE*0.5)*size)
