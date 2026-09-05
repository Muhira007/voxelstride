extends Node3D

const Animal = preload("res://scripts/farm_animal.gd")
const Layout = preload("res://scripts/farm_layout.gd")
const Geometry = preload("res://scripts/box_geometry.gd")
var animals: Array[CharacterBody3D] = []
var world: Node3D
var enabled := false
var view_position := Vector3.ZERO
var timer := 0.0
var recovery_timer := 0.0

func populate(w: Node3D, saved: Array = []) -> void:
	world = w
	for pen in Layout.PENS:
		for i in pen["count"]:
			var animal := Animal.new()
			animal.configure(w,pen["species"],animals.size(),pen["rect"])
			add_child(animal)
			for attempt in 30:
				var clear := true
				for neighbor in animals:
					if animal.position.distance_to(neighbor.position)<animal.radius+neighbor.radius+0.3:
						clear = false
						break
				if clear: break
				animal.find_safe_position()
			animals.append(animal)
	for data in saved.slice(0,100):
		if not data is Dictionary: continue
		var id: Variant = data.get("id")
		if (id is int or id is float) and is_finite(float(id)) and float(id) == int(id) and id >= 0 and id < animals.size(): animals[int(id)].restore(data)
	for pen in Layout.PENS:
		var r: Rect2i = pen["rect"]
		signpost(Vector3(r.position.x+9,14,r.end.y),"KANDANG "+pen["name"].to_upper())
	signpost(Vector3(91,14,111),"DESA PERTANIAN")
	signpost(Vector3(78,14,95),"LADANG & KEBUN")
	signpost(Vector3(91,14,135),"PADANG MEMBANGUN")
	signpost(Vector3(129,14,46),"LUMBUNG DESA")

func _process(delta: float) -> void:
	recovery_timer -= delta
	timer -= delta
	if timer>0: return
	timer = 0.25
	for animal in animals:
		var distance := animal.position.distance_squared_to(view_position)
		animal.visible = animal.has_safe_position and distance < 76*76
		animal.set_physics_process(enabled and animal.has_safe_position and distance < 48*48 and world.collision_ready(animal.position))
		# An edited pen can temporarily have no safe ground; retry only near the player.
		if enabled and not animal.has_safe_position and distance < 48*48 and recovery_timer <= 0: animal.find_safe_position()
	if recovery_timer <= 0: recovery_timer = 4.0

func pause() -> void:
	enabled = false
	for animal in animals: animal.set_physics_process(false)

func snapshot() -> Array:
	var result := []
	for animal in animals: result.append(animal.snapshot())
	return result

func overlaps(cell: Vector3i) -> bool:
	for animal in animals:
		if animal.has_safe_position and AABB(animal.position-Vector3(animal.radius,0,animal.radius),Vector3(animal.radius*2,animal.body_height,animal.radius*2)).intersects(AABB(Vector3(cell),Vector3.ONE)): return true
	return false

func signpost(at: Vector3, text: String) -> void:
	var mesh := MeshInstance3D.new()
	var s := Geometry.start()
	Geometry.box(s,Vector3(0,0.8,0),Vector3(0.13,1.6,0.13),Color("846341"))
	Geometry.box(s,Vector3(0,1.65,0),Vector3(3.4,0.65,0.15),Color("624e3a"))
	mesh.mesh = s.commit()
	mesh.position = at
	add_child(mesh)
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.005
	label.modulate = Color("eee2bd")
	label.outline_size = 0
	label.position = at+Vector3(0,1.65,0.083)
	label.visibility_range_end = 55
	add_child(label)
