extends Control

signal world_chosen(id: String)
signal closed
signal exit_requested
const Catalog = preload("res://scripts/world_catalog.gd")
const Card = preload("res://scripts/world_card.gd")
const PAGE_SIZE := 3
var source: Array = Catalog.ENTRIES
var matches: Array[Dictionary] = []
var cards: Array[Button] = []
var categories: Array[Button] = []
var grid: HBoxContainer
var search: LineEdit
var details: Label
var status: Label
var page_label: Label
var previous: Button
var next: Button
var launch: Button
var resume: Button
var exit_button: Button
var category := 0
var page := 0
var selected_id := "city"
var current_world := ""
var saved_ids: Array = []
var navigation_held := [0,0]
var trigger_held := [false,false]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("0d2029")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,40)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,26)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := label("VOXELSTRIDE  /  PILIH DUNIA",30,Color("f2eedf"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	resume = button("Kembali bermain",func(): closed.emit())
	header.add_child(resume)
	exit_button = button("Keluar",func(): exit_requested.emit())
	header.add_child(exit_button)
	column.add_child(label("Koleksi template lingkungan. Setiap pilihan melanjutkan save-nya sendiri.",16))
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation",8)
	column.add_child(filters)
	for i in Catalog.CATEGORIES.size():
		var tab := button(Catalog.CATEGORIES[i],set_category.bind(i))
		filters.add_child(tab)
		categories.append(tab)
	search = LineEdit.new()
	search.placeholder_text = "Cari dunia atau suasana…"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 38
	search.add_theme_font_size_override("font_size",16)
	filters.add_child(search)
	search.text_changed.connect(func(_value: String): page = 0; refresh())
	filters.add_child(button("Reset",reset_filters))
	grid = HBoxContainer.new()
	grid.add_theme_constant_override("separation",16)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation",16)
	column.add_child(navigation)
	previous = button("← Sebelumnya",turn_page.bind(-1))
	navigation.add_child(previous)
	page_label = label("",15)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(page_label)
	next = button("Berikutnya →",turn_page.bind(1))
	navigation.add_child(next)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("19323b")
	style.set_corner_radius_all(8)
	for side in ["left","right","top","bottom"]: style.set("content_margin_"+side,16)
	panel.add_theme_stylebox_override("panel",style)
	column.add_child(panel)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation",22)
	panel.add_child(bottom)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(info)
	details = label("",15)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.y = 43
	info.add_child(details)
	status = label("",13,Color("d6be82"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(status)
	launch = button("Buka dunia →",activate)
	launch.custom_minimum_size = Vector2(215,62)
	bottom.add_child(launch)
	column.add_child(label("A / Enter buka  ·  LB / RB atau PgUp / PgDn halaman  ·  LT / RT kategori  ·  B / Esc kembali  ·  Tab ke pencarian",13))
	hide()

func open(active: String,saves: Array = []) -> void:
	current_world = active
	saved_ids = saves
	resume.visible = not active.is_empty()
	navigation_held = [0,0]
	trigger_held = [false,false]
	show()
	refresh()
	focus_selected()

func reset_filters() -> void:
	category = 0
	search.text = ""
	page = 0
	refresh()
	focus_selected()

func set_category(index: int) -> void:
	category = clampi(index,0,Catalog.CATEGORIES.size()-1)
	page = 0
	refresh()

func refresh() -> void:
	matches = Catalog.filtered(Catalog.CATEGORIES[category],search.text,source)
	page = clampi(page,0,maxi(0,page_count()-1))
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	cards.clear()
	var visible_ids := []
	for item in matches.slice(page*PAGE_SIZE,(page+1)*PAGE_SIZE):
		var card := Card.new()
		card.setup(item)
		card.pressed.connect(select.bind(item["id"]))
		card.focus_entered.connect(select.bind(item["id"]))
		grid.add_child(card)
		cards.append(card)
		visible_ids.append(item["id"])
	if not visible_ids.has(selected_id): selected_id = "" if visible_ids.is_empty() else visible_ids[0]
	if matches.is_empty():
		var empty := label("Tidak ada dunia yang cocok.\nUbah pencarian atau tekan Reset.",24)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(empty)
	# Keep card widths stable even on the last page.
	if not cards.is_empty():
		for i in range(cards.size(),PAGE_SIZE):
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spacer.custom_minimum_size.x = 260
			grid.add_child(spacer)
	previous.disabled = page == 0
	next.disabled = page+1>=page_count()
	page_label.text = "Halaman %d / %d  ·  %d dunia" % [page+1,page_count(),matches.size()]
	for i in categories.size(): categories[i].modulate = Color("ebc76b") if i == category else Color.WHITE
	select(selected_id)

func select(id: String) -> void:
	selected_id = id
	var item := {}
	for match_item in matches:
		if match_item["id"] == id: item = match_item; break
	launch.disabled = item.is_empty()
	details.text = "Belum ada pilihan." if item.is_empty() else item["detail"]
	status.text = "Save yang ada tidak diubah oleh pencarian atau pergantian halaman."
	if not item.is_empty():
		status.text = "SEDANG DIMAINKAN · Kembali tanpa memuat ulang" if id == current_world else ("SAVE TERSEDIA · Melanjutkan kemajuan; tidak mereset dunia" if saved_ids.has(id) else "SLOT TERPISAH · Dunia dibuat saat pertama kali dibuka")
	launch.text = "Lanjutkan →" if id == current_world or saved_ids.has(id) else "Buka dunia →"
	for card in cards:
		card.chosen = card.item["id"] == id
		card.queue_redraw()

func page_count() -> int:
	return maxi(1,ceili(matches.size()/float(PAGE_SIZE)))

func turn_page(direction: int) -> void:
	var new_page := clampi(page+direction,0,page_count()-1)
	if page == new_page: return
	page = new_page
	refresh()
	focus_selected()

func focus_selected() -> void:
	for card in cards:
		if card.item["id"] == selected_id: card.grab_focus(); return

func reveal(id: String) -> void:
	category = 0
	search.text = ""
	matches = Catalog.filtered("Semua","",source)
	for i in matches.size():
		if matches[i]["id"] == id:
			page = i/PAGE_SIZE
			selected_id = id
			refresh()
			focus_selected()
			return

func activate() -> void:
	if not launch.disabled and not selected_id.is_empty(): world_chosen.emit(selected_id)

func show_error(message: String) -> void:
	status.text = message

func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if not current_world.is_empty(): closed.emit()
		return true
	if event.is_action_pressed("inventory_previous_page"): turn_page(-1); return true
	if event.is_action_pressed("inventory_next_page"): turn_page(1); return true
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
		var trigger: int = 0 if event.axis == JOY_AXIS_TRIGGER_LEFT else 1
		var pressed: bool = event.axis_value>0.35
		if pressed and not trigger_held[trigger]:
			set_category(posmod(category+(-1 if trigger == 0 else 1),Catalog.CATEGORIES.size()))
			focus_selected()
		trigger_held[trigger] = pressed
		return true
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		var axis: int = 0 if event.axis == JOY_AXIS_LEFT_X else 1
		var direction: int = int(signf(event.axis_value)) if absf(event.axis_value)>0.55 else 0
		if direction != 0 and direction != navigation_held[axis]: move_card(direction)
		if direction != 0 or absf(event.axis_value)<0.35: navigation_held[axis] = direction
		return true
	if event is InputEventJoypadButton or not search.has_focus():
		var owner := get_viewport().gui_get_focus_owner()
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			var direction := -1 if event.is_action_pressed("ui_left") else 1
			if categories.has(owner):
				set_category(posmod(category+direction,Catalog.CATEGORIES.size()))
				categories[category].grab_focus()
			else: move_card(direction)
			return true
		if event.is_action_pressed("ui_down"):
			if cards.has(owner): launch.grab_focus()
			else: focus_selected()
			return true
		if event.is_action_pressed("ui_up"):
			if cards.has(owner): categories[category].grab_focus()
			elif categories.has(owner): exit_button.grab_focus()
			else: focus_selected()
			return true
		if event.is_action_pressed("ui_accept"):
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and not cards.has(focused):
				if not focused.disabled: focused.pressed.emit()
			else: activate()
			return true
	return false

func move_card(direction: int) -> void:
	var index := -1
	for i in matches.size():
		if matches[i]["id"] == selected_id: index = i; break
	if index<0: return
	index = clampi(index+direction,0,matches.size()-1)
	selected_id = matches[index]["id"]
	page = index/PAGE_SIZE
	refresh()
	focus_selected()

func button(text: String,callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 38
	result.add_theme_font_size_override("font_size",15)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("29434c") if state == "normal" else Color("3d5860")
		if state == "disabled": style.bg_color = Color("172a32")
		style.set_corner_radius_all(5)
		style.content_margin_left = 14
		style.content_margin_right = 14
		if state in ["focus","hover"]:
			style.set_border_width_all(2)
			style.border_color = Color("ebc76b")
		result.add_theme_stylebox_override(state,style)
	result.pressed.connect(callback)
	return result

func label(text: String,font_size: int,color: Color = Color("b8cccf")) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	return result
