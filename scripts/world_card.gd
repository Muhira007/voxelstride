extends Button

var item: Dictionary = {}
var chosen := false

func setup(data: Dictionary) -> void:
	item = data
	custom_minimum_size = Vector2(260,300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("172d36") if state == "normal" else Color("243e46")
		style.set_corner_radius_all(9)
		if state == "focus":
			style.set_border_width_all(2)
			style.border_color = Color("f4dd9a")
		add_theme_stylebox_override(state,style)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 18
	content.offset_right = -18
	content.offset_top = 164
	content.offset_bottom = -14
	content.add_theme_constant_override("separation",7)
	add_child(content)
	for row in [[item["name"],21,Color("f2f0e5")],["%s  /  %d × %d · tinggi %d" % [item["category"],item["size"],item["size"],item["height"]],12,Color(item["color"])],[item["summary"],15,Color("b9c9c8")]]:
		var label := Label.new()
		label.text = row[0]
		label.add_theme_font_size_override("font_size",row[1])
		label.add_theme_color_override("font_color",row[2])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(label)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	if item.is_empty(): return
	var accent := Color(item["color"])
	var origin := Vector2(16,16)
	var width := size.x-32
	draw_rect(Rect2(origin,Vector2(width,132)),Color("355262"))
	draw_rect(Rect2(origin+Vector2(0,101),Vector2(width,31)),Color("597464"))
	if item["art"] == "city":
		for i in 9:
			var h: float = [38,63,82,49,92,68,43,57,35][i]
			var x := 7+i*width/9.0
			draw_rect(Rect2(origin+Vector2(x,108-h),Vector2(width/11,h)),Color("7797a0") if i%2 == 0 else Color("af9278"))
			for yy in range(0,int(h)-12,10):
				for xx in [4,12]: draw_rect(Rect2(origin+Vector2(x+xx,115-h+yy),Vector2(4,4)),Color("ddcb91"))
		draw_rect(Rect2(origin+Vector2(0,109),Vector2(width,16)),Color("253940"))
		for i in 12: draw_rect(Rect2(origin+Vector2(i*30,116),Vector2(12,2)),accent)
		for x in [width*0.15,width*0.72]: draw_rect(Rect2(origin+Vector2(x,109),Vector2(23,7)),Color("c16b52"))
	elif item["art"] == "valley" or item["art"] == "classic":
		for i in 12:
			var h := 25+int(absf(sin(i*0.7))*46)
			draw_rect(Rect2(origin+Vector2(i*width/12,110-h),Vector2(width/12+1,h)),Color("7f9980"))
		if item["art"] == "valley":
			draw_rect(Rect2(origin+Vector2(width*0.69,40),Vector2(17,73)),Color("8fcece"))
			draw_rect(Rect2(origin+Vector2(width*0.63,113),Vector2(70,7)),Color("6bafc2"))
	else:
		for i in 6:
			draw_rect(Rect2(origin+Vector2(8+i*width/7,86),Vector2(width/9,35)),Color("a5b168") if i%2 == 0 else Color("d0b665"))
		for x in [width*0.22,width*0.61]:
			draw_rect(Rect2(origin+Vector2(x,69),Vector2(42,33)),Color("c9af84"))
			draw_colored_polygon(PackedVector2Array([origin+Vector2(x-5,69),origin+Vector2(x+21,46),origin+Vector2(x+47,69)]),Color("9c6c54"))
	draw_rect(Rect2(origin+Vector2(9,8),Vector2(112,23)),Color("162e37"))
	draw_string(ThemeDB.fallback_font,origin+Vector2(16,24),item["tag"],HORIZONTAL_ALIGNMENT_LEFT,-1,11,accent)
	if chosen:
		draw_rect(Rect2(0,size.y-4,size.x,4),accent)
