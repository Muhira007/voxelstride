extends CharacterBody3D

const Geometry = preload("res://scripts/box_geometry.gd")
var vehicle_id := 0
var kind := "car"
var dimensions := Vector3(2.1,1.9,4.5)
var route := -1
var distance := 0.0
var wheels: Array[Node3D] = []
var stopped := false

func setup(id: int,type: String,color: Color) -> void:
	vehicle_id = id
	kind = type
	dimensions = Vector3(2.5,3.0,7.8) if kind == "bus" else (Vector3(2.3,2.6,5.4) if kind == "van" else Vector3(2.1,1.9,4.5))
	collision_layer = 8
	collision_mask = 3
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	shape.shape = box
	shape.position.y = dimensions.y/2
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var s := Geometry.start()
	var length := dimensions.z
	var width := dimensions.x
	var tall := dimensions.y
	# Explicit linear vertex colors for the Compatibility renderer.
	Geometry.box(s,Vector3(0,0.65,0),Vector3(width,0.65,length),color.srgb_to_linear())
	Geometry.box(s,Vector3(0,tall/2+0.35,0.25),Vector3(width-0.15,tall-0.9,length*(0.84 if kind != "car" else 0.57)),color.lightened(0.12).srgb_to_linear())
	var glass := Color("244858").srgb_to_linear()
	Geometry.box(s,Vector3(0,tall-0.48,-length*(0.422 if kind != "car" else 0.29)+0.2),Vector3(width-0.35,0.63,0.06),glass)
	Geometry.box(s,Vector3(0,tall-0.48,length*(0.422 if kind != "car" else 0.29)+0.3),Vector3(width-0.35,0.6,0.06),glass)
	for side in [-1,1]:
		for i in (5 if kind == "bus" else 2):
			var z := -length*0.27+i*(length*0.13 if kind == "bus" else 0.9)
			Geometry.box(s,Vector3(side*(width/2-0.065),tall-0.5,z),Vector3(0.05,0.63,0.78),glass)
		Geometry.box(s,Vector3(side*width*0.31,0.77,-length/2-0.025),Vector3(0.46,0.24,0.07),Color("e1dbae").srgb_to_linear())
		Geometry.box(s,Vector3(side*width*0.31,0.77,length/2+0.025),Vector3(0.38,0.2,0.07),Color("bd5241").srgb_to_linear())
	Geometry.box(s,Vector3(0,0.43,-length/2-0.02),Vector3(width-0.08,0.2,0.1),Color("85918f").srgb_to_linear())
	mesh.mesh = s.commit()
	add_child(mesh)
	for side in [-1,1]:
		for z in [-length*0.32,length*0.32]:
			var wheel := MeshInstance3D.new()
			var surface := Geometry.start()
			Geometry.box(surface,Vector3.ZERO,Vector3(0.32,0.65,0.65),Color("202932").srgb_to_linear())
			Geometry.box(surface,Vector3(side*0.18,0,0),Vector3(0.04,0.3,0.3),Color("a4b1b4").srgb_to_linear())
			wheel.mesh = surface.commit()
			wheel.position = Vector3(side*width/2,0.38,z)
			add_child(wheel)
			wheels.append(wheel)

func bounds(at: Vector3) -> AABB:
	var extents := dimensions
	if absf(sin(rotation.y))>0.5: extents = Vector3(dimensions.z,dimensions.y,dimensions.x)
	return AABB(at-Vector3(extents.x/2,0,extents.z/2),extents)

func spin(amount: float) -> void:
	for wheel in wheels: wheel.rotation.x -= amount/0.34
