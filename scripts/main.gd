extends Node3D

const World = preload("res://scripts/voxel_world.gd")
const Player = preload("res://scripts/player.gd")
const HUD = preload("res://scripts/hud.gd")
const GameInput = preload("res://scripts/game_input.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Herd = preload("res://scripts/farm_herd.gd")
const Waterfall = preload("res://scripts/waterfall.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const WorldPicker = preload("res://scripts/world_picker.gd")
const Traffic = preload("res://scripts/city_traffic.gd")

var world: Node3D
var player: CharacterBody3D
var hud: Control
var store := SaveStore.new()
var overlay: Control
var menu_box: VBoxContainer
var menu_title: Label
var menu_subtitle: Label
var progress_label: Label
var held_block: MeshInstance3D
var outline: MeshInstance3D
var menu_state := "loading"
var loaded := false
var started := false
var selected := 0
var hotbar: Array[int] = [1,2,3,4,5,6,7,8]
var inventory: Control
var target: Dictionary = {}
var action_cooldown := 0.0
var autosave_time := 0.0
var animation_time := 0.0
var controller_mode := false
var startup_message := ""
var automation := false
var sound: AudioStreamPlayer
var tone_break: AudioStreamWAV
var tone_place: AudioStreamWAV
var smoke_failures := 0
var light_timer := 0.0
var active_world_id := ""
var herd: Node3D
var loading_world := false
var automation_save_root := ""
var environment: Environment
var waterfall: Node3D
var traffic: Node3D
var world_picker: Control

func world_name(id: String) -> String:
	return Catalog.entry(id).get("name","Dunia")

func _ready() -> void:
	Blocks.setup()
	GameInput.setup()
	get_tree().auto_accept_quit = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	automation = OS.get_cmdline_user_args().has("--smoke-test") or OS.get_cmdline_user_args().has("--capture") or OS.get_cmdline_user_args().has("--capture-farm") or OS.get_cmdline_user_args().has("--capture-valley") or OS.get_cmdline_user_args().has("--capture-city")
	_build_environment()
	_build_interface()
	_build_audio()
	Input.joy_connection_changed.connect(_controller_changed)
	controller_mode = not Input.get_connected_joypads().is_empty()
	loaded = true
	_show_menu("worlds")
	if automation:
		if OS.get_cmdline_user_args().has("--capture-city"):
			await preload("res://scripts/city_verification.gd").capture(self)
			return
		if OS.get_cmdline_user_args().has("--capture-valley"):
			await preload("res://scripts/valley_verification.gd").capture(self)
			return
		if OS.get_cmdline_user_args().has("--capture-farm"):
			await preload("res://scripts/farm_verification.gd").capture(self)
			return
		await _choose_world("classic")
		if OS.get_cmdline_user_args().has("--smoke-test"):
			await _smoke_test()
		else:
			await _capture_screenshots()

func _choose_world(id: String) -> bool:
	if loading_world or id not in SaveStore.WORLD_IDS: return false
	if active_world_id == id and is_instance_valid(world):
		_start_playing()
		return true
	if not _save_world():
		_world_error(store.last_error+" Dunia belum diganti.")
		return false
	var base := "user://" if automation_save_root.is_empty() else automation_save_root
	var saved := {}
	if not automation or not automation_save_root.is_empty():
		if not store.prepare_world(id,base):
			_world_error(store.last_error)
			return false
		saved = store.read_world(id,base)
		startup_message = store.last_error
		if saved.is_empty() and not store.last_error.is_empty():
			_world_error(store.last_error+" Pulihkan save sebelum membuka dunia ini.")
			return false
	else: startup_message = ""
	loading_world = true
	var load_started := Time.get_ticks_msec()
	print("WORLD LOAD: "+world_name(id))
	_show_menu("loading")
	loaded = false
	progress_label.text = "Membuat lingkungan…"
	await get_tree().process_frame
	await get_tree().process_frame
	for node in [herd,traffic,player,world,outline,waterfall]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	herd = null
	waterfall = null
	traffic = null
	player = null
	world = null
	outline = null
	held_block = null
	active_world_id = id
	for cloud in get_tree().get_nodes_in_group("world_clouds"):
		var original: Vector3 = cloud.get_meta("original_position")
		cloud.position = Vector3(original.x*3.0,original.y+72,original.z*3.0) if id in ["valley","city"] else (Vector3(original.x*1.6,original.y+55,original.z*1.6) if id == "farm" else original)
	started = false
	selected = 0
	hotbar = Blocks.restore_hotbar(null)
	target.clear()
	autosave_time = 0
	light_timer = 0
	world = World.new()
	world.configure(id)
	world.streaming = id != "classic"
	world.set_process(false)
	add_child(world)
	if id == "valley": await world.generate_valley_async(int(saved.get("seed",20260905)),_loading_progress)
	elif id == "city": await world.generate_city_async(int(saved.get("seed",20260905)),_loading_progress)
	else: world.generate(int(saved.get("seed",20260905)))
	if not saved.is_empty(): world.apply_changes(saved["changes"])
	if id in ["valley","city"]: await world.prepare_distant_landscape(_loading_progress)
	player = Player.new()
	player.world = world
	add_child(player)
	player.respawn()
	player.rotation.y = 0.9 if id == "city" else (-0.4 if id == "valley" else (0 if id == "farm" else -2.4))
	player.pitch = -0.10
	player.camera.far = 520 if id in ["valley","city"] else (125 if id == "farm" else 180)
	if not saved.is_empty(): _restore_player(saved)
	var queue: Array[Vector2i] = []
	if world.streaming:
		world.update_stream(player.position)
		queue.assign(world.build_queue)
		world.build_queue.clear()
	else:
		for x in world.size / World.CHUNK:
			for z in world.size / World.CHUNK: queue.append(Vector2i(x,z))
	var total := queue.size()
	for i in total:
		world.build_chunk(queue[i])
		progress_label.text = "%s · Menyiapkan area %d / %d" % [world_name(id),i+1,total]
		await get_tree().process_frame
	if id in ["farm","valley"]:
		herd = Herd.new()
		add_child(herd)
		herd.populate(world,saved.get("animals",[]))
		herd.view_position = player.position
	if id == "valley":
		waterfall = Waterfall.new()
		add_child(waterfall)
	if id == "city":
		traffic = Traffic.new()
		add_child(traffic)
		traffic.populate(world,player,saved.get("vehicles",[]))
	_build_selection()
	_select_block(selected)
	hud.world_title = world_name(id).to_upper()
	environment.fog_density = 0.0018 if id in ["valley","city"] else (0.009 if id == "farm" else 0.0015)
	environment.ambient_light_energy = 0.60 if id != "classic" else 0.42
	loaded = true
	await get_tree().physics_frame
	# Keep the loading guard until physics and the play state can become ready together.
	loading_world = false
	_start_playing()
	print("WORLD READY: %s, %d chunks, %.1f seconds" % [world_name(id),world.chunks.size(),(Time.get_ticks_msec()-load_started)/1000.0])
	return true

func _loading_progress(message: String) -> void:
	progress_label.text = message

func _world_error(message: String) -> void:
	menu_subtitle.text = message
	if is_instance_valid(world_picker) and world_picker.visible: world_picker.show_error(message)

func _world_picker() -> void:
	if _save_world(): _show_menu("worlds")
	else: menu_subtitle.text = store.last_error

func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	environment = env
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("659fbd")
	sky_material.sky_horizon_color = Color("d6dfca")
	sky_material.ground_horizon_color = Color("d6dfca")
	sky_material.ground_bottom_color = Color("779779")
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0eddf")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("becfda")
	env.fog_density = 0.0015
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_color = Color("fff9ed")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	var cloud_material := StandardMaterial3D.new()
	cloud_material.albedo_color = Color("f7f1dc")
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rng := RandomNumberGenerator.new()
	rng.seed = 9830
	for i in 20:
		var cloud := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(7,16), rng.randf_range(1,2), rng.randf_range(4,8))
		cloud.mesh = box
		cloud.material_override = cloud_material
		cloud.position = Vector3(rng.randf_range(-35,130), rng.randf_range(34,42), rng.randf_range(-35,130))
		cloud.set_meta("original_position",cloud.position)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cloud)
		cloud.add_to_group("world_clouds")

func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = HUD.new()
	canvas.add_child(hud)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)
	var tint := ColorRect.new()
	tint.color = Color(0.025,0.075,0.09,0.67)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(tint)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 64)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 42)
	overlay.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 72)
	margin.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_theme_constant_override("separation", 14)
	columns.add_child(left)
	var badge := _label("VOXELSTRIDE     /     PROTOTIPE 05", 13, Color("ebc76b"))
	left.add_child(badge)
	menu_title = _label("VOXEL\nSTRIDE", 58)
	menu_title.add_theme_constant_override("line_spacing", -8)
	left.add_child(menu_title)
	menu_subtitle = _label("Temukan tempatmu. Bangun sesukamu.", 18, Color("b9ccc0"))
	menu_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(menu_subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	left.add_child(spacer)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 9)
	left.add_child(menu_box)
	progress_label = _label("Menyiapkan dunia…", 18, Color("ebc76b"))
	menu_box.add_child(progress_label)
	var right := PanelContainer.new()
	right.custom_minimum_size.x = 345
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035,0.09,0.10,0.82)
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 26
	panel.content_margin_right = 26
	panel.content_margin_top = 26
	panel.content_margin_bottom = 26
	right.add_theme_stylebox_override("panel", panel)
	columns.add_child(right)
	var help := VBoxContainer.new()
	help.add_theme_constant_override("separation", 14)
	right.add_child(help)
	help.add_child(_label("SIAP MENJELAJAH", 20, Color("ebc76b")))
	help.add_child(_label("XBOX 360", 12, Color("a9bfb3")))
	help.add_child(_label("Analog kiri     Bergerak\nAnalog kanan  Melihat\nA  Lompat        B  Tahan jongkok\nY  Hancurkan  X  Pasang\nLB / RB / D-pad  Pilih blok\nBack  Inventori  Start  Menu\nKlik analog kiri  Lari", 16))
	help.add_child(HSeparator.new())
	help.add_child(_label("KEYBOARD + MOUSE", 12, Color("a9bfb3")))
	help.add_child(_label("WASD  Gerak    Mouse  Melihat\nSpace  Lompat   Ctrl  Jongkok\nShift  Lari         E  Inventori\nKlik kiri / kanan  Ubah blok\n1–8 / Scroll  Pilih   Esc  Menu\nF5  Simpan       F11  Layar penuh", 15))
	help.add_child(HSeparator.new())
	help.add_child(_label("Offline · Save terpisah untuk tiap dunia\nPilih lingkungan di katalog template", 12, Color("a9bfb3")))
	var footer := _label("Dibuat dengan Godot  •  Proyek independen, tidak berafiliasi dengan Mojang atau Microsoft.", 12, Color("a9bfb3"))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(64,-28)
	overlay.add_child(footer)
	inventory = Inventory.new()
	canvas.add_child(inventory)
	inventory.block_chosen.connect(_choose_inventory)
	inventory.closed.connect(_start_playing)
	world_picker = WorldPicker.new()
	canvas.add_child(world_picker)
	world_picker.world_chosen.connect(_choose_world)
	world_picker.closed.connect(_start_playing)
	world_picker.exit_requested.connect(_quit)

func _label(text: String, font_size: int, color: Color = Color("f4f0dd")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(340, 48)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("ebc76b") if primary else Color("294348")
		if state == "hover" or state == "focus":
			style.bg_color = style.bg_color.lightened(0.13)
			style.set_border_width_all(2)
			style.border_color = Color("f7f0d1")
		if state == "pressed": style.bg_color = style.bg_color.darkened(0.15)
		style.set_corner_radius_all(5)
		style.content_margin_left = 18
		style.content_margin_right = 18
		button.add_theme_stylebox_override(state, style)
	for color_state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_state, Color("172f31") if primary else Color("f4f0dd"))
	button.pressed.connect(callback)
	menu_box.add_child(button)
	return button

func _show_menu(state: String) -> void:
	menu_state = state
	if is_instance_valid(player): player.enabled = false
	if is_instance_valid(world): world.set_process(false)
	if is_instance_valid(herd): herd.pause()
	if is_instance_valid(waterfall): waterfall.set_active(false)
	if is_instance_valid(traffic): traffic.pause()
	hud.active = false
	if is_instance_valid(outline): outline.visible = false
	if is_instance_valid(held_block): held_block.visible = false
	overlay.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world_picker.hide()
	if state == "worlds":
		overlay.hide()
		inventory.hide()
		var saves := []
		if not automation or not automation_save_root.is_empty():
			var base := "user://" if automation_save_root.is_empty() else automation_save_root
			for id in Catalog.WORLD_IDS:
				var path := store.world_path(id,base)
				if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"): saves.append(id)
		world_picker.open(active_world_id,saves)
		return
	if state == "inventory":
		overlay.hide()
		inventory.open(selected,hotbar)
		return
	inventory.hide()
	for child in menu_box.get_children():
		menu_box.remove_child(child)
		child.queue_free()
	var first: Button
	match state:
		"loading":
			menu_title.text = "MENYIAPKAN\nDUNIAMU…"
			menu_title.add_theme_font_size_override("font_size",42)
			menu_subtitle.text = "Pemuatan bertahap. Save lama tetap terpisah."
			progress_label = _label("",18,Color("ebc76b"))
			menu_box.add_child(progress_label)
		"pause":
			menu_title.text = "TARIK NAPAS."
			menu_title.add_theme_font_size_override("font_size", 46)
			menu_subtitle.text = "Duniamu menunggu di sini."
			first = _button("Lanjut bermain", _start_playing, true)
			_button("Simpan dunia", _save_from_menu)
			_button("Kembali ke titik awal", _respawn)
			_button("Kecepatan kamera: %.1f×" % (player.sensitivity / 2.4), _cycle_sensitivity)
			_button("Simpan & pilih dunia", _world_picker)
			_button("Simpan & keluar", _quit)
		_:
			menu_title.text = "VOXEL\nSTRIDE"
			menu_title.add_theme_font_size_override("font_size", 58)
			menu_subtitle.text = "Temukan tempatmu. Bangun sesukamu."
			first = _button("Masuk ke dunia    →", _start_playing, true)
			_button("Keluar", _quit)
			menu_box.add_child(_label("Save tersimpan di komputer ini.", 13, Color("a9bfb3")))
	if first != null: first.grab_focus()

func _start_playing() -> void:
	if not is_instance_valid(world) or not is_instance_valid(player) or loading_world: return
	var first_start := not started
	started = true
	menu_state = "playing"
	overlay.hide()
	world_picker.hide()
	inventory.hide()
	player.enabled = true
	world.set_process(true)
	world.update_stream(player.position)
	if is_instance_valid(herd): herd.enabled = true
	if is_instance_valid(waterfall): waterfall.set_active(true)
	if is_instance_valid(traffic): traffic.enabled = true
	hud.active = true
	held_block.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not automation else Input.MOUSE_MODE_VISIBLE
	action_cooldown = 0.25
	if first_start:
		hud.notify("Selamat datang! Dunia ini milik imajinasimu." if startup_message.is_empty() else startup_message)

func _choose_inventory(block: int) -> void:
	if not Blocks.is_placeable(block): return
	hotbar[selected] = block
	_select_block(selected)
	_start_playing()

func _select_block(index: int) -> void:
	selected = posmod(index, 8)
	hud.selected = selected
	hud.hotbar = hotbar
	if held_block != null:
		held_block.mesh = world.make_block_mesh(hotbar[selected])

func _cycle_sensitivity() -> void:
	player.sensitivity += 0.6
	if player.sensitivity > 4.21: player.sensitivity = 1.2
	player.mouse_sensitivity = 0.0025 * player.sensitivity / 2.4
	_show_menu("pause")

func _respawn() -> void:
	player.respawn()
	_start_playing()
	hud.notify("Kembali ke titik awal.")

func _input(event: InputEvent) -> void:
	if not loaded: return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3): controller_mode = true
	elif event is InputEventKey or event is InputEventMouseButton: controller_mode = false
	if event.is_action_pressed("fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	if menu_state == "worlds":
		if world_picker.handle_input(event): get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if menu_state == "playing": _show_menu("pause")
		elif menu_state != "title" and menu_state != "loading": _start_playing()
		get_viewport().set_input_as_handled()
		return
	if menu_state != "playing":
		if menu_state == "inventory":
			if inventory.handle_input(event): get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and not focused.disabled:
				focused.pressed.emit()
				get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B and menu_state != "title":
			_start_playing()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		_show_menu("inventory")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("next_block"): _select_block(selected + 1)
	elif event.is_action_pressed("previous_block"): _select_block(selected - 1)
	elif event.is_action_pressed("save_world"): _save_world()
	elif event is InputEventKey and event.pressed and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_8:
		_select_block(event.physical_keycode - KEY_1)

func _process(delta: float) -> void:
	if not loaded or menu_state != "playing": return
	animation_time += delta
	action_cooldown = maxf(0, action_cooldown - delta)
	autosave_time += delta
	light_timer -= delta
	if light_timer <= 0:
		world.update_local_lights(player.position)
		world.update_stream(player.position)
		light_timer = 0.5
	if is_instance_valid(herd): herd.view_position = player.position
	hud.controller = controller_mode
	hud.position_text = "%d / %d / %d" % [player.position.x, player.position.y, player.position.z]
	target = world.raycast(player.camera.global_position, -player.camera.global_basis.z)
	outline.visible = not target.is_empty()
	if not target.is_empty():
		outline.position = Vector3(target["cell"]) + Vector3.ONE * 0.5
		hud.target_name = Blocks.NAMES[target["block"]]
	else: hud.target_name = ""
	if action_cooldown <= 0:
		if Input.is_action_pressed("break_block"): _edit_block(false)
		elif Input.is_action_pressed("place_block"): _edit_block(true)
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.2 and player.is_on_floor()
	held_block.position.y = -0.40 + (sin(animation_time * 10) * 0.018 if moving else sin(animation_time * 2) * 0.005)
	held_block.rotation.y = 0.35 + sin(animation_time * 1.5) * 0.025
	if autosave_time >= 30:
		autosave_time = 0
		_save_world()

func _edit_block(place: bool) -> bool:
	action_cooldown = 0.18
	if target.is_empty(): return false
	var cell: Vector3i = target["previous"] if place else target["cell"]
	if place:
		if not world.inside(cell):
			hud.notify("Batas dunia tercapai.")
			return false
		if player.overlaps_block(cell): return false
		if is_instance_valid(herd) and herd.overlaps(cell): return false
		if is_instance_valid(traffic) and traffic.overlaps(cell): return false
		if world.get_block(cell) != 0: return false
	elif world.get_block(cell) == 9:
		hud.notify("Batuan dasar tidak dapat dihancurkan.")
		return false
	if world.set_block(cell, hotbar[selected] if place else 0):
		held_block.rotation.x = -0.3 if place else 0.3
		sound.stream = tone_place if place else tone_break
		sound.play()
		if controller_mode:
			var devices := Input.get_connected_joypads()
			if not devices.is_empty(): Input.start_joy_vibration(devices[0], 0.12, 0.2, 0.07)
		return true
	return false

func _build_selection() -> void:
	outline = MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("fff3b7")
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for axis in 3:
		for a in [-1,1]:
			for b in [-1,1]:
				var start := Vector3.ZERO
				start[axis] = -0.505
				start[(axis + 1) % 3] = a * 0.505
				start[(axis + 2) % 3] = b * 0.505
				var end := start
				end[axis] = 0.505
				mesh.surface_add_vertex(start)
				mesh.surface_add_vertex(end)
	mesh.surface_end()
	outline.mesh = mesh
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outline)
	held_block = MeshInstance3D.new()
	held_block.mesh = world.make_block_mesh(hotbar[selected])
	held_block.scale = Vector3.ONE * 0.28
	held_block.position = Vector3(0.58,-0.40,-0.85)
	held_block.rotation_degrees = Vector3(-12,22,-8)
	held_block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.camera.add_child(held_block)

func _build_audio() -> void:
	sound = AudioStreamPlayer.new()
	sound.volume_db = -17
	add_child(sound)
	tone_break = _tone(140, 0.09, true)
	tone_place = _tone(260, 0.065, false)

func _tone(frequency: float, duration: float, noise: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var count := int(22050 * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 471
	for i in count:
		var t := float(i) / 22050
		var envelope := pow(1.0 - float(i) / count, 2)
		var value := sin(TAU * frequency * t) * 0.65
		if noise: value = value * 0.35 + rng.randf_range(-0.6,0.6)
		data.encode_s16(i * 2, int(value * envelope * 26000))
	wav.data = data
	return wav

func _restore_player(saved: Dictionary) -> void:
	hotbar = Blocks.restore_hotbar(saved.get("hotbar"))
	var p: Array = saved["position"]
	player.position = Vector3(clampf(p[0],0.35,world.size-0.35), clampf(p[1],1,world.height+5), clampf(p[2],0.35,world.size-0.35))
	player.rotation.y = wrapf(saved["yaw"], -PI, PI)
	player.pitch = clampf(saved["pitch"],-1.53,1.53)
	player.camera.rotation.x = player.pitch
	_select_block(clampi(int(saved["selected"]),0,7))
	for x in range(floori(player.position.x - 0.3), floori(player.position.x + 0.3) + 1):
		for y in range(floori(player.position.y + 0.05), floori(player.position.y + 1.8) + 1):
			for z in range(floori(player.position.z - 0.3), floori(player.position.z + 0.3) + 1):
				if Blocks.is_solid(world.get_block(Vector3i(x,y,z))):
					player.respawn()
					return

func _save_world() -> bool:
	if not loaded or not started or (automation and automation_save_root.is_empty()): return true
	var data := {"version": SaveStore.VERSION, "generator": world.generator_version, "world_id":active_world_id,"world_size":world.size,"world_height":world.height,"seed": world.world_seed, "changes": world.changes, "position": [player.position.x, player.position.y, player.position.z], "yaw": player.rotation.y, "pitch": player.pitch, "selected": selected, "hotbar":hotbar,"animals":herd.snapshot() if is_instance_valid(herd) else []}
	if is_instance_valid(traffic): data["vehicles"] = traffic.snapshot()
	var base := "user://" if automation_save_root.is_empty() else automation_save_root
	var success := store.write_save(data,store.world_path(active_world_id,base))
	hud.notify("Dunia tersimpan." if success else store.last_error)
	return success

func _save_from_menu() -> void:
	if _save_world(): menu_subtitle.text = "Dunia tersimpan di komputer ini."
	else: menu_subtitle.text = store.last_error

func _quit() -> void:
	if not _save_world():
		_show_menu("pause")
		menu_subtitle.text = store.last_error + " Coba simpan lagi."
		return
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and loaded and menu_state == "playing" and not automation:
		_show_menu("pause")
		_save_world()

func _controller_changed(_device: int, connected: bool) -> void:
	controller_mode = not Input.get_connected_joypads().is_empty()
	if not loaded: return
	if not connected and menu_state == "playing": _show_menu("pause")
	hud.notify("Controller tersambung." if connected else "Controller terlepas. Keyboard tetap tersedia.")

func _smoke_test() -> void:
	for i in 90: await get_tree().physics_frame
	if not player.is_on_floor():
		push_error("SMOKE FAIL: player tidak mendarat di terrain")
		get_tree().quit(1)
		return
	var original := player.position
	Input.action_press("move_forward")
	for i in 25: await get_tree().physics_frame
	Input.action_release("move_forward")
	if Vector2(player.position.x-original.x, player.position.z-original.z).length() < 0.3:
		push_error("SMOKE FAIL: player tidak bergerak")
		get_tree().quit(1)
		return
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	if player.velocity.y <= 0:
		push_error("SMOKE FAIL: lompat gagal")
		get_tree().quit(1)
		return
	for i in 90: await get_tree().physics_frame
	Input.action_press("crouch")
	for i in 10: await get_tree().physics_frame
	_smoke_check(player.is_crouching and player.shape.shape.size.y < 1.2, "crouch lowers actual collision shape")
	Input.action_release("crouch")
	for i in 10: await get_tree().physics_frame
	_smoke_check(not player.is_crouching and player.shape.shape.size.y > 1.7, "standing restores collision shape")
	target = world.raycast(player.camera.global_position, Vector3.DOWN)
	if target.is_empty():
		_smoke_check(false, "ground is reachable")
	else:
		var ground: Vector3i = target["cell"]
		var ground_type: int = target["block"]
		_smoke_check(_edit_block(false) and world.get_block(ground) == 0, "destroy targeted block through gameplay")
		target = world.raycast(player.camera.global_position, Vector3.DOWN)
		_select_block(ground_type - 1)
		_smoke_check(_edit_block(true) and world.get_block(ground) == ground_type, "replace ground through gameplay")
		var self_cell := Vector3i(floori(player.position.x), floori(player.position.y + 0.3), floori(player.position.z))
		target = {"cell": ground, "previous": self_cell, "block": ground_type}
		_smoke_check(not _edit_block(true) and world.get_block(self_cell) == 0, "cannot place a block inside player")
	var yaw_before: float = player.rotation.y
	Input.action_press("look_right", 0.8)
	for i in 10: await get_tree().physics_frame
	Input.action_release("look_right")
	_smoke_check(absf(player.rotation.y - yaw_before) > 0.1, "right stick look rotates camera")
	_show_menu("inventory")
	if player.enabled or not inventory.visible:
		push_error("SMOKE FAIL: inventori tidak menghentikan pemain")
		get_tree().quit(1)
		return
	_choose_inventory(Blocks.id("quartz_bricks"))
	if hotbar[selected] != Blocks.id("quartz_bricks") or not player.enabled:
		push_error("SMOKE FAIL: pilihan inventori tidak diterapkan")
		get_tree().quit(1)
		return
	_show_menu("pause")
	var paused_position := player.position
	Input.action_press("move_forward")
	for i in 10: await get_tree().physics_frame
	Input.action_release("move_forward")
	_smoke_check(player.position.is_equal_approx(paused_position), "pause freezes movement")
	_start_playing()
	# Exercise actual controller events through the menu, not just direct callbacks.
	await _simulate_pad_button(JOY_BUTTON_BACK)
	_smoke_check(menu_state == "inventory", "Xbox Back opens inventory")
	var previous_page: int = inventory.page
	await _simulate_pad_button(JOY_BUTTON_RIGHT_SHOULDER)
	_smoke_check(inventory.page == previous_page+1, "Xbox RB changes inventory page")
	await _simulate_pad_axis(JOY_AXIS_TRIGGER_RIGHT,0.6)
	await _simulate_pad_axis(JOY_AXIS_TRIGGER_RIGHT,0.9)
	_smoke_check(inventory.category == 1, "held trigger changes category only once")
	await _simulate_pad_axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	await _simulate_pad_button(JOY_BUTTON_DPAD_RIGHT)
	_smoke_check(inventory.cursor == 1, "D-pad navigates inventory grid")
	var chosen: int = inventory.matches[inventory.page*Inventory.PAGE_SIZE+inventory.cursor]
	await _simulate_pad_button(JOY_BUTTON_A)
	_smoke_check(menu_state == "playing" and hotbar[selected] == chosen, "Xbox A assigns focused material to active slot")
	await _simulate_pad_button(JOY_BUTTON_BACK)
	inventory.search.grab_focus()
	var letter := InputEventKey.new()
	letter.physical_keycode = KEY_E
	letter.keycode = KEY_E
	letter.unicode = 101
	letter.pressed = true
	Input.parse_input_event(letter)
	await get_tree().process_frame
	_smoke_check(menu_state == "inventory" and inventory.search.text == "e", "typing E in search does not close inventory")
	inventory.search.text = "quartz_bricks"
	inventory.refresh()
	_smoke_check(inventory.matches == [Blocks.id("quartz_bricks")], "search isolates an exact material key")
	await _simulate_pad_button(JOY_BUTTON_A)
	_smoke_check(hotbar[selected] == Blocks.id("quartz_bricks"), "controller selects search result while search has focus")
	target = {"previous":Vector3i(48,30,48),"cell":Vector3i(48,29,48),"block":3}
	_smoke_check(_edit_block(true) and world.get_block(Vector3i(48,30,48)) == Blocks.id("quartz_bricks"), "new catalog block places through gameplay")
	await _simulate_pad_button(JOY_BUTTON_START)
	_smoke_check(menu_state == "pause", "Xbox Start opens pause")
	await _simulate_pad_button(JOY_BUTTON_B)
	_smoke_check(menu_state == "playing", "Xbox B returns from pause")
	await preload("res://scripts/farm_verification.gd").smoke(self)
	await preload("res://scripts/valley_verification.gd").smoke(self)
	await preload("res://scripts/city_verification.gd").smoke(self)
	print("SMOKE %s: collision, movement, jump, crouch, edits, self-placement protection, stick look, controller menus; %d chunks; %d failures" % ["PASS" if smoke_failures == 0 else "FAIL", world.chunks.size(), smoke_failures])
	get_tree().quit(1 if smoke_failures else 0)

func _smoke_check(condition: bool, message: String) -> void:
	if not condition:
		smoke_failures += 1
		push_error("SMOKE FAIL: " + message)

func _simulate_pad_button(button_index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _simulate_pad_axis(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	await get_tree().process_frame

func _capture_screenshots() -> void:
	for i in 180: await get_tree().process_frame
	player.rotation.y = -2.4
	player.pitch = -0.10
	player.camera.rotation.x = player.pitch
	hud.toast_time = 0
	print("RENDER: %d FPS on %s" % [Engine.get_frames_per_second(), RenderingServer.get_video_adapter_name()])
	await RenderingServer.frame_post_draw
	var output := "res://artifacts/gameplay.png"
	get_viewport().get_texture().get_image().save_png(output)
	_show_menu("title")
	for i in 5: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/menu.png")
	_show_menu("inventory")
	for i in 5: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/inventory.png")
	await preload("res://scripts/material_showcase.gd").capture(self)
	print("CAPTURE PASS: gameplay, title, inventory, materials")
	get_tree().quit()
