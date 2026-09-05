extends Control

signal block_chosen(block: int)
signal closed

const Blocks = preload("res://scripts/blocks.gd")
const PAGE_SIZE := 18
const COLS := 6
var category := 0
var page := 0
var cursor := 0
var slot := 0
var matches: Array[int] = []
var grid: GridContainer
var search: LineEdit
var caption: Label
var detail: Label
var pager: Label
var buttons: Array[Button] = []
var tabs: Array[Button] = []
var previous_button: Button
var next_button: Button
var trigger_held := [false, false]
var navigation_held := [0, 0]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tint := ColorRect.new()
	tint.color = Color(0.025,0.06,0.075,0.94)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tint)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_"+side, 48)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_"+side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := label("PERPUSTAKAAN BLOK", 32, Color("f3e7c8"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close_button := button("Kembali  ·  B / Esc", closed.emit)
	top.add_child(close_button)
	caption = label("",16)
	column.add_child(caption)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 7)
	column.add_child(filters)
	for i in Blocks.CATEGORIES.size():
		var tab := button(Blocks.CATEGORIES[i], set_category.bind(i))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size",14)
		filters.add_child(tab)
		tabs.append(tab)
	search = LineEdit.new()
	search.placeholder_text = "Cari blok… nama Indonesia atau Inggris (mis. kuarsa, spruce, concrete)"
	search.custom_minimum_size.y = 38
	search.add_theme_font_size_override("font_size",16)
	search.text_changed.connect(func(_text: String): page = 0; refresh())
	column.add_child(search)
	grid = GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	for i in PAGE_SIZE:
		var tile := button("", choose.bind(i))
		tile.custom_minimum_size = Vector2(140,96)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.focus_entered.connect(func(): cursor = i; _details())
		tile.mouse_entered.connect(func(): cursor = i; _details())
		var texture := TextureRect.new()
		texture.name = "Icon"
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		texture.offset_left = -32
		texture.offset_right = 32
		texture.offset_top = 2
		texture.offset_bottom = 66
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(texture)
		var name_label := label("",14,Color("e9e9dd"))
		name_label.name = "Name"
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_label.offset_top = 64
		name_label.offset_bottom = -4
		name_label.offset_left = 3
		name_label.offset_right = -3
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(name_label)
		grid.add_child(tile)
		buttons.append(tile)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation",12)
	column.add_child(bottom)
	detail = label("",16,Color("ebc76b"))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(detail)
	previous_button = button("‹  LB / PgUp", turn_page.bind(-1))
	bottom.add_child(previous_button)
	pager = label("",15)
	bottom.add_child(pager)
	next_button = button("RB / PgDn  ›", turn_page.bind(1))
	bottom.add_child(next_button)
	column.add_child(label("A / Klik  Pilih    ·    D-pad  Arah    ·    LB / RB  Halaman    ·    LT / RT  Kategori    ·    Back / B  Kembali",13,Color("a9bdb7")))
	hide()

func open(active_slot: int, hotbar: Array[int]) -> void:
	trigger_held = [false, false]
	navigation_held = [0, 0]
	slot = active_slot
	caption.text = "%d bahan tersedia  /  Pilihan akan mengisi slot cepat %d" % [Blocks.catalog().size(),slot+1]
	show()
	search.text = ""
	category = 0
	matches = Blocks.catalog()
	var current := matches.find(hotbar[slot])
	page = maxi(0,current) / PAGE_SIZE
	cursor = maxi(0,current) % PAGE_SIZE
	refresh()
	_focus_cursor()

func set_category(index: int) -> void:
	category = posmod(index,Blocks.CATEGORIES.size())
	page = 0
	cursor = 0
	refresh()
	_focus_cursor()

func turn_page(step: int) -> void:
	var pages := maxi(1,ceili(float(matches.size())/PAGE_SIZE))
	page = clampi(page+step,0,pages-1)
	cursor = 0
	refresh()
	_focus_cursor()

func refresh() -> void:
	matches = Blocks.catalog(Blocks.CATEGORIES[category],search.text)
	var pages := maxi(1,ceili(float(matches.size())/PAGE_SIZE))
	page = clampi(page,0,pages-1)
	for i in PAGE_SIZE:
		var index := page*PAGE_SIZE+i
		var tile := buttons[i]
		tile.disabled = index >= matches.size()
		tile.focus_mode = Control.FOCUS_NONE if tile.disabled else Control.FOCUS_ALL
		(tile.get_node("Icon") as TextureRect).texture = null if tile.disabled else Blocks.icon(matches[index])
		(tile.get_node("Name") as Label).text = "" if tile.disabled else Blocks.NAMES[matches[index]]
		tile.set_meta("block_id", -1 if tile.disabled else matches[index])
	for i in tabs.size(): tabs[i].modulate = Color("efcf82") if i == category else Color.WHITE
	previous_button.disabled = page == 0
	next_button.disabled = page == pages-1
	pager.text = "%d / %d" % [page+1,pages]
	cursor = clampi(cursor,0,maxi(0,mini(PAGE_SIZE,matches.size()-page*PAGE_SIZE)-1))
	_details()

func _details() -> void:
	if matches.is_empty():
		detail.text = "Tidak ada blok yang cocok."
		return
	var index := page*PAGE_SIZE+cursor
	if index < matches.size(): detail.text = Blocks.NAMES[matches[index]] + "   →   Slot " + str(slot+1)

func _focus_cursor() -> void:
	if not matches.is_empty(): buttons[cursor].grab_focus()

func choose(index: int) -> void:
	var absolute := page*PAGE_SIZE+index
	if absolute >= 0 and absolute < matches.size(): block_chosen.emit(matches[absolute])

func move_cursor(dx: int, dy: int) -> void:
	if matches.is_empty(): return
	var absolute := page*PAGE_SIZE+cursor
	absolute = clampi(absolute + dx + dy*COLS,0,matches.size()-1)
	page = absolute/PAGE_SIZE
	cursor = absolute%PAGE_SIZE
	refresh()
	_focus_cursor()

func handle_input(event: InputEvent) -> bool:
	if not visible: return false
	if (event.is_action_pressed("inventory") and not (event is InputEventKey and search.has_focus())) or event.is_action_pressed("ui_cancel"):
		closed.emit()
		return true
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
		var trigger: int = 0 if event.axis == JOY_AXIS_TRIGGER_LEFT else 1
		var pressed: bool = event.axis_value > 0.35
		if pressed and not trigger_held[trigger]: set_category(category + (-1 if trigger == 0 else 1))
		trigger_held[trigger] = pressed
		return true
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		var axis: int = 0 if event.axis == JOY_AXIS_LEFT_X else 1
		var direction: int = int(signf(event.axis_value)) if absf(event.axis_value) > 0.55 else 0
		if direction != 0 and direction != navigation_held[axis]:
			move_cursor(direction if axis == 0 else 0, direction if axis == 1 else 0)
		if direction != 0 or absf(event.axis_value) < 0.35: navigation_held[axis] = direction
		return true
	if event.is_action_pressed("inventory_previous_page"):
		turn_page(-1)
		return true
	if event.is_action_pressed("inventory_next_page"):
		turn_page(1)
		return true
	# A controller can leave the search field without typing into it.
	var navigating := event is InputEventJoypadButton or event is InputEventJoypadMotion or not search.has_focus()
	if navigating:
		for action in ["ui_left","ui_right","ui_up","ui_down"]:
			if event.is_action_pressed(action):
				move_cursor(-1 if action == "ui_left" else (1 if action == "ui_right" else 0),-1 if action == "ui_up" else (1 if action == "ui_down" else 0))
				return true
		if event.is_action_pressed("ui_accept") and (event is InputEventJoypadButton or buttons.has(get_viewport().gui_get_focus_owner())):
			choose(cursor)
			return true
	return false

func button(text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 36
	result.add_theme_font_size_override("font_size",15)
	for state in ["normal","hover","focus","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("223738") if state == "normal" else Color("334d4b")
		if state == "disabled": style.bg_color = Color("192c2e")
		style.set_corner_radius_all(5)
		style.content_margin_left = 10
		style.content_margin_right = 10
		if state == "focus" or state == "hover":
			style.border_color = Color("ebc76b")
			style.set_border_width_all(2)
		result.add_theme_stylebox_override(state,style)
	result.pressed.connect(callback)
	return result

func label(text: String, font_size: int, color: Color = Color("bdcbc3")) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	return result
