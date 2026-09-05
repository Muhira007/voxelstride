extends CharacterBody3D

const WALK_SPEED := 5.5
const HEIGHT := 1.8
const WIDTH := 0.6
var camera: Camera3D
var shape: CollisionShape3D
var enabled := false
var sensitivity := 2.4
var mouse_sensitivity := 0.0025
var pitch := 0.0
var is_crouching := false
var coyote_time := 0.0
var jump_buffer := 0.0
var world: Node3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	floor_snap_length = 0.25
	floor_stop_on_slope = true
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, HEIGHT, WIDTH)
	shape.shape = box
	shape.position.y = HEIGHT / 2
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 75
	camera.near = 0.05
	camera.far = 180
	add_child(camera)
	camera.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if enabled and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.53, 1.53)
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if not enabled: return
	# Never step/fall into a chunk whose collision is still loading.
	if not world.collision_ready(position) or not world.collision_ready(position+velocity*delta*2):
		velocity = Vector3.ZERO
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	rotate_y(-look.x * absf(look.x) * sensitivity * delta)
	pitch = clampf(pitch - look.y * absf(look.y) * sensitivity * delta, -1.53, 1.53)
	camera.rotation.x = pitch
	var requested_crouch := Input.is_action_pressed("crouch")
	if is_crouching and not requested_crouch:
		requested_crouch = _blocked_above()
	is_crouching = requested_crouch
	var body_height := 1.15 if is_crouching else HEIGHT
	(shape.shape as BoxShape3D).size.y = body_height
	shape.position.y = body_height * 0.5
	camera.position.y = lerpf(camera.position.y, 1.0 if is_crouching else 1.62, minf(delta * 14, 1))
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := transform.basis * Vector3(move.x, 0, move.y)
	var speed := 2.2 if is_crouching else (8.5 if Input.is_action_pressed("sprint") else WALK_SPEED)
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 32)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 32)
	coyote_time = 0.12 if is_on_floor() else maxf(0, coyote_time - delta)
	jump_buffer = 0.12 if Input.is_action_just_pressed("jump") else maxf(0, jump_buffer - delta)
	if not is_on_floor(): velocity.y -= 24.0 * delta
	if jump_buffer > 0 and coyote_time > 0:
		velocity.y = 8.2
		jump_buffer = 0.0
		coyote_time = 0.0
	move_and_slide()
	position.x = clampf(position.x, 0.32, world.size - 0.32)
	position.z = clampf(position.z, 0.32, world.size - 0.32)
	if position.y < -10: respawn()

func _blocked_above() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var standing := BoxShape3D.new()
	standing.size = Vector3(WIDTH - 0.04, HEIGHT - 1.15, WIDTH - 0.04)
	query.shape = standing
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 1.15 + (HEIGHT - 1.15) * 0.5, 0))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func overlaps_block(cell: Vector3i) -> bool:
	var body_height := 1.15 if is_crouching else HEIGHT
	var player_box := AABB(global_position - Vector3(WIDTH / 2, 0, WIDTH / 2), Vector3(WIDTH, body_height, WIDTH))
	return player_box.intersects(AABB(Vector3(cell), Vector3.ONE))

func respawn() -> void:
	global_position = world.spawn_position()
	velocity = Vector3.ZERO
