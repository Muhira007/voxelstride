extends Node3D

const Vehicle = preload("res://scripts/city_vehicle.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Layout = preload("res://scripts/city_layout.gd")
const ROUTES := [
	[Vector2(51,51),Vector2(333,51),Vector2(333,333),Vector2(51,333)],
	[Vector2(123,123),Vector2(261,123),Vector2(261,261),Vector2(123,261)]
]
const SPEED := 5.0
var vehicles: Array[CharacterBody3D] = []
var world: Node3D
var player: CharacterBody3D
var enabled := false
var elapsed := 0.0
var signs: Array[Label3D] = []

func populate(w: Node3D,p: CharacterBody3D,saved: Array = []) -> void:
	world = w
	player = p
	for i in 10:
		var lane := 0 if i<6 else 1
		var count := 6 if lane == 0 else 4
		var slot := i if lane == 0 else i-6
		var car := create_vehicle(i,"bus" if i in [2,7] else ("van" if i in [4,9] else "car"))
		car.route = lane
		car.distance = perimeter(lane)*(slot+0.18)/count
		place(car)
	# Parked cars, terminal buses, and depot vans. Their positions are generator-owned.
	var parking := [
		["bus",Vector3(284,13.02,79),0.0],["bus",Vector3(300,13.02,79),0.0],["bus",Vector3(316,13.02,79),0.0],
		["van",Vector3(286,13.02,306),PI/2],["van",Vector3(286,13.02,313),PI/2],
		["car",Vector3(85,13.02,99),PI/2],["car",Vector3(99,13.02,99),PI/2],
		["car",Vector3(156,13.02,175),PI/2],["car",Vector3(172,13.02,175),PI/2],
		["car",Vector3(291,13.02,244),PI/2],["car",Vector3(307,13.02,244),PI/2],
		["van",Vector3(156,13.02,317),PI/2]
	]
	for item in parking:
		var car := create_vehicle(vehicles.size(),item[0])
		car.position = item[1]
		car.rotation.y = item[2]
	for data in saved.slice(0,32): restore(data)
	var player_box := AABB(player.position-Vector3(0.3,0,0.3),Vector3(0.6,1.8,0.6))
	for car in vehicles:
		if car.bounds(car.position).intersects(player_box): player.respawn(); break
	for item in Layout.LANDMARKS:
		var label := Label3D.new()
		label.text = item[0]
		label.position = item[1]+Vector3(0,3,0)
		label.font_size = 42
		label.pixel_size = 0.009
		label.modulate = Color("f0dda5")
		label.outline_size = 7
		label.visibility_range_end = 90
		add_child(label)
		signs.append(label)
	refresh_visibility()

func create_vehicle(id: int,kind: String) -> CharacterBody3D:
	var car := Vehicle.new()
	car.setup(id,kind,Color(["b85844","e0bd61","4f8996","d4d7cb","6e86a4","789367"][id%6]))
	add_child(car)
	vehicles.append(car)
	return car

static func perimeter(route: int) -> float:
	return 1128.0 if route == 0 else 552.0

static func point(route: int,distance: float) -> Vector3:
	var length := perimeter(route)/4
	var segment := int(fposmod(distance,perimeter(route))/length)
	var a: Vector2 = ROUTES[route][segment]
	var b: Vector2 = ROUTES[route][(segment+1)%4]
	var pos := a.lerp(b,fposmod(distance,length)/length)
	return Vector3(pos.x,13.02,pos.y)

func place(car: CharacterBody3D) -> void:
	car.position = point(car.route,car.distance)
	var forward := point(car.route,car.distance+0.1)-car.position
	car.rotation.y = atan2(-forward.x,-forward.z)

func _physics_process(delta: float) -> void:
	if not enabled: return
	elapsed += delta
	for car in vehicles:
		if car.route<0: continue
		var amount := SPEED*delta
		var ahead := point(car.route,car.distance+amount)
		var direction := (point(car.route,car.distance+0.5)-car.position).normalized()
		var safe := route_clear(car,ahead,direction)
		car.stopped = not safe
		if not safe: continue
		var old_position := car.position
		# Collision is checked before advancing; cars yield to players rather than pushing them.
		if world.collision_ready(car.position) and car.test_move(car.global_transform,ahead-car.position): continue
		car.distance = fposmod(car.distance+amount,perimeter(car.route))
		place(car)
		car.spin(car.position.distance_to(old_position))
	refresh_visibility()

func route_clear(car: CharacterBody3D,at: Vector3,direction: Vector3) -> bool:
	var box: AABB = car.bounds(at).grow(0.18)
	var prediction: AABB = car.bounds(at+direction*2.0).grow(0.35)
	var player_box := AABB(player.position-Vector3(0.3,0,0.3),Vector3(0.6,1.8,0.6))
	if box.intersects(player_box) or prediction.intersects(player_box): return false
	for other in vehicles:
		if car != other and prediction.intersects(other.bounds(other.position)): return false
	# Validate actual voxel data even when a mesh is not loaded/rebuilt yet.
	for x in range(floori(box.position.x),ceili(box.end.x)):
		for z in range(floori(box.position.z),ceili(box.end.z)):
			if not Blocks.is_solid(world.get_block(Vector3i(x,12,z))): return false
			for y in range(13,ceili(box.end.y)):
				if Blocks.is_solid(world.get_block(Vector3i(x,y,z))): return false
	return true

func refresh_visibility() -> void:
	for car in vehicles:
		var near: bool = world.collision_ready(car.position) and car.position.distance_squared_to(player.position)<140*140
		car.visible = near
		car.collision_layer = 8 if near else 0
		car.collision_mask = 3 if near else 0

func pause() -> void:
	enabled = false

func overlaps(cell: Vector3i) -> bool:
	for car in vehicles:
		if car.bounds(car.position).intersects(AABB(Vector3(cell),Vector3.ONE)): return true
	return false

func snapshot() -> Array:
	var result := []
	for car in vehicles:
		if car.route>=0: result.append({"id":car.vehicle_id,"route":car.route,"distance":car.distance})
	return result

func restore(data: Variant) -> bool:
	if not data is Dictionary: return false
	for field in ["id","route","distance"]:
		var value: Variant = data.get(field)
		if not (value is int or value is float) or not is_finite(float(value)): return false
	var id := int(data["id"])
	if float(id) != float(data["id"]) or id<0 or id>=10 or id>=vehicles.size(): return false
	var car: CharacterBody3D = vehicles[id]
	if data["route"] != car.route or data["distance"]<0 or data["distance"]>=perimeter(car.route): return false
	car.distance = data["distance"]
	place(car)
	return true
