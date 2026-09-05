extends CharacterBody3D

const Blocks = preload("res://scripts/blocks.gd")
const Geometry = preload("res://scripts/box_geometry.gd")
static var body_meshes: Dictionary = {}
static var leg_meshes: Dictionary = {}
var world: Node3D
var species := "cow"
var animal_id := 0
var pen := Rect2()
var rng := RandomNumberGenerator.new()
var target := Vector3.ZERO
var decision_time := 0.0
var age := 0.0
var body: MeshInstance3D
var legs: Array[MeshInstance3D] = []
var body_height := 1.5
var radius := 0.5
var resting := true
var has_safe_position := true
var ground_level := 14.02

func configure(w: Node3D, kind: String, identifier: int, bounds: Rect2i, floor_level: float = 14.02) -> void:
	world = w
	species = kind
	animal_id = identifier
	pen = Rect2(bounds).grow(-1.2)
	ground_level = floor_level
	rng.seed = w.world_seed+identifier*719
	body_height = {"cow":1.5,"sheep":1.25,"pig":0.95,"chicken":0.8}[species]
	radius = 0.24 if species == "chicken" else 0.55

func _ready() -> void:
	collision_layer = 4
	collision_mask = 7
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(radius*1.5,body_height,radius*1.8)
	shape.shape = box
	shape.position.y = body_height/2
	add_child(shape)
	_build_model()
	find_safe_position()
	decision_time = rng.randf_range(0.1,2)
	set_physics_process(false)

func can_stand(at: Vector3) -> bool:
	if not pen.has_point(Vector2(at.x,at.z)): return false
	for offset in [Vector3.ZERO,Vector3(radius,0,0),Vector3(-radius,0,0),Vector3(0,0,radius),Vector3(0,0,-radius)]:
		var p: Vector3 = at+offset
		var feet := Vector3i(floori(p.x),floori(p.y+0.02),floori(p.z))
		if not Blocks.is_solid(world.get_block(feet+Vector3i.DOWN)): return false
		for y in range(feet.y,floori(p.y+body_height-0.05)+1):
			if Blocks.is_solid(world.get_block(Vector3i(feet.x,y,feet.z))): return false
	return true

func find_safe_position() -> void:
	has_safe_position = false
	for i in 180:
		var candidate := Vector3(rng.randf_range(pen.position.x+0.5,pen.end.x-0.5),ground_level,rng.randf_range(pen.position.y+0.5,pen.end.y-0.5))
		if can_stand(candidate):
			position = candidate
			target = candidate
			velocity = Vector3.ZERO
			has_safe_position = true
			return

func _physics_process(delta: float) -> void:
	if not has_safe_position or not world.collision_ready(position): return
	age += delta
	decision_time -= delta
	if decision_time <= 0:
		if not can_stand(position): find_safe_position()
		resting = rng.randf() < 0.35
		target = Vector3(rng.randf_range(pen.position.x+0.5,pen.end.x-0.5),position.y,rng.randf_range(pen.position.y+0.5,pen.end.y-0.5))
		decision_time = rng.randf_range(1.5,4.5)
	var direction := (target-position)*Vector3(1,0,1)
	var moving := not resting and direction.length() > 0.3
	var speed := 0.85 if species != "chicken" else 1.15
	if moving:
		direction = direction.normalized()
		if not can_stand(position+direction*0.7):
			moving = false
			decision_time = minf(decision_time,0.3)
	if moving:
		rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*4))
	velocity.x = direction.x*speed if moving else 0.0
	velocity.z = direction.z*speed if moving else 0.0
	velocity.y = -1 if is_on_floor() else maxf(-12,velocity.y-20*delta)
	move_and_slide()
	if moving and is_on_wall(): decision_time = minf(decision_time,0.25)
	position.x = clampf(position.x,pen.position.x,pen.end.x-0.01)
	position.z = clampf(position.z,pen.position.y,pen.end.y-0.01)
	if position.y < ground_level-4: find_safe_position()
	body.position.y = sin(age*8)*0.025 if moving else sin(age*1.8)*0.01
	for i in legs.size(): legs[i].rotation.x = sin(age*8+(i%2)*PI)*0.35 if moving else 0.0

func snapshot() -> Dictionary:
	return {"id":animal_id,"species":species,"position":[position.x,position.y,position.z],"yaw":rotation.y}

func restore(data: Dictionary) -> bool:
	if data.get("species") != species or data.get("id") != animal_id: return false
	var p: Variant = data.get("position")
	if not p is Array or p.size() != 3: return false
	for value in p:
		if not (value is float or value is int) or not is_finite(float(value)): return false
	var yaw: Variant = data.get("yaw")
	if not (yaw is float or yaw is int) or not is_finite(float(yaw)): return false
	var candidate := Vector3(p[0],p[1],p[2])
	if not can_stand(candidate): return false
	position = candidate
	target = candidate
	rotation.y = wrapf(float(yaw),-PI,PI)
	has_safe_position = true
	return true

func _build_model() -> void:
	if not body_meshes.has(species):
		var s := Geometry.start()
		var coat: Color = {"cow":Color("ded4b9"),"sheep":Color("eee7d4"),"pig":Color("d69b96"),"chicken":Color("e8e2cf")}[species]
		var h := body_height
		var size := Vector3(0.78,h*0.52,1.25) if species != "chicken" else Vector3(0.43,0.42,0.53)
		Geometry.box(s,Vector3(0,h*0.59,0),size,coat)
		Geometry.box(s,Vector3(0,h*0.82,-size.z*0.54),Vector3(size.x*0.67,h*0.32,size.z*0.34),coat.darkened(0.08))
		for side in [-1,1]:
			Geometry.box(s,Vector3(side*size.x*0.22,h*0.88,-size.z*0.723),Vector3(0.09,0.085,0.025),Color("28282d"))
			if species != "chicken": Geometry.box(s,Vector3(side*size.x*0.43,h*0.94,-size.z*0.51),Vector3(0.2,0.11,0.2),coat.darkened(0.17))
		if species == "cow":
			for side in [-1,1]:
				Geometry.box(s,Vector3(side*0.396,h*0.60,0.1),Vector3(0.015,0.43,0.48),Color("544638"))
				Geometry.box(s,Vector3(side*0.396,h*0.69,-0.4),Vector3(0.015,0.24,0.28),Color("514338"))
				Geometry.box(s,Vector3(side*0.23,h*1.03,-0.64),Vector3(0.10,0.19,0.10),Color("b7ad8f"))
			Geometry.box(s,Vector3(0,h*0.73,-0.9),Vector3(0.49,0.22,0.18),Color("bd9b87"))
		elif species == "sheep":
			for x in [-0.23,0.23]:
				for z in [-0.42,0.05,0.43]: Geometry.box(s,Vector3(x,h*0.79,z),Vector3(0.39,0.24,0.36),coat.lightened(0.04))
		elif species == "pig":
			Geometry.box(s,Vector3(0,h*0.73,-0.92),Vector3(0.34,0.19,0.14),Color("bc7a7c"))
			for x in [-0.09,0.09]: Geometry.box(s,Vector3(x,h*0.74,-1.0),Vector3(0.06,0.06,0.02),Color("754d54"))
			Geometry.box(s,Vector3(0,h*0.65,0.73),Vector3(0.10,0.1,0.2),coat)
		else:
			Geometry.box(s,Vector3(0,h*0.77,-0.47),Vector3(0.18,0.095,0.18),Color("d8a344"))
			Geometry.box(s,Vector3(0,h*1.04,-0.30),Vector3(0.08,0.13,0.21),Color("b34f49"))
			Geometry.box(s,Vector3(0,h*0.6,-0.36),Vector3(0.08,0.17,0.1),Color("b34f49"))
			for x in [-0.235,0.235]: Geometry.box(s,Vector3(x,0.48,0.05),Vector3(0.08,0.24,0.38),coat.darkened(0.1))
		body_meshes[species] = s.commit()
		var leg := Geometry.start()
		var leg_height := h*0.35
		Geometry.box(leg,Vector3(0,-leg_height/2,0),Vector3(0.075 if species == "chicken" else 0.16,leg_height,0.11 if species == "chicken" else 0.18),Color("c79c46") if species == "chicken" else coat.darkened(0.28))
		if species != "chicken": Geometry.box(leg,Vector3(0,-leg_height+0.04,0),Vector3(0.17,0.09,0.19),Color("66564b"))
		leg_meshes[species] = leg.commit()
	body = MeshInstance3D.new()
	body.mesh = body_meshes[species]
	add_child(body)
	for i in (2 if species == "chicken" else 4):
		var leg := MeshInstance3D.new()
		leg.mesh = leg_meshes[species]
		leg.position = Vector3((-1 if i%2 == 0 else 1)*(0.12 if species == "chicken" else 0.26),body_height*0.35,0 if species == "chicken" else (-0.43 if i<2 else 0.43))
		add_child(leg)
		legs.append(leg)
