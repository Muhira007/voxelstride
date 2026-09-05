extends Control

const Blocks = preload("res://scripts/blocks.gd")
const INK := Color("132b30")
const CREAM := Color("f4f0dd")
const GOLD := Color("ebc76b")
var selected := 0
var hotbar: Array[int] = [1,2,3,4,5,6,7,8]
var active := false
var world_title := "VOXELSTRIDE"
var controller := false
var target_name := ""
var position_text := ""
var toast := ""
var toast_time := 0.0
var font: Font
var clock_time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font

func _process(delta: float) -> void:
	toast_time = maxf(0, toast_time - delta)
	clock_time += delta
	queue_redraw()

func notify(message: String) -> void:
	toast = message
	toast_time = 3.5

func _text(at: Vector2, message: String, point_size: int, color: Color = CREAM) -> void:
	draw_string(font, at + Vector2(1,1), message, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size, Color(0,0,0,0.35))
	draw_string(font, at, message, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size, color)

func _center(at: Vector2, message: String, point_size: int, color: Color = CREAM) -> void:
	_text(at - Vector2(font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x * 0.5, 0), message, point_size, color)

func _draw() -> void:
	if not active: return
	var w := size.x
	var h := size.y
	draw_style_box(_panel(Color(0.055,0.12,0.14,0.85)), Rect2(24,22,254,65))
	draw_rect(Rect2(24,22,4,65), GOLD)
	_text(Vector2(42,48), world_title, 18)
	_text(Vector2(42,71), "KREATIF  /  OFFLINE", 12, Color("b9c9bf"))
	var stats := "%s   ·   %d FPS" % [position_text, Engine.get_frames_per_second()]
	_text(Vector2(w - font.get_string_size(stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x - 28, 42), stats, 14)
	var mid := size * 0.5
	draw_circle(mid, 3, Color(0,0,0,0.4))
	draw_line(mid - Vector2(7,0), mid - Vector2(3,0), CREAM, 2)
	draw_line(mid + Vector2(3,0), mid + Vector2(7,0), CREAM, 2)
	draw_line(mid - Vector2(0,7), mid - Vector2(0,3), CREAM, 2)
	draw_line(mid + Vector2(0,3), mid + Vector2(0,7), CREAM, 2)
	if not target_name.is_empty(): _center(mid + Vector2(0,38), target_name, 15)
	var hotbar_width := 8 * 66.0 + 14
	var left := (w - hotbar_width) * 0.5
	draw_style_box(_panel(Color(0.055,0.12,0.14,0.91)), Rect2(left,h-116,hotbar_width,80))
	for i in 8:
		var rect := Rect2(left + 8 + i * 66, h - 109, 62, 66)
		if i == selected:
			draw_style_box(_panel(Color("3e5351")), rect)
			draw_rect(Rect2(rect.position.x, rect.end.y - 3, rect.size.x, 3), GOLD)
		else: draw_style_box(_panel(Color(0.14,0.23,0.24,0.7)), rect)
		draw_texture_rect(Blocks.icon(hotbar[i]),Rect2(rect.position+Vector2(7,6),Vector2(48,48)),false)
		_text(rect.position + Vector2(5,14), str(i + 1), 10, GOLD if i == selected else Color("9faeaa"))
	_center(Vector2(w / 2,h-128), Blocks.NAMES[hotbar[selected]] + "  /  TAK TERBATAS", 15)
	_center(Vector2(w / 2,h-15), "LB / RB atau D-pad  ·  Pilih blok" if controller else "1–8 atau scroll  ·  Pilih blok", 12, Color("d6dfd0"))
	var hint := "Y  Hancurkan    X  Pasang    BACK  Inventori    START  Menu" if controller else "Klik kiri  Hancurkan    Klik kanan  Pasang    E  Inventori    Esc  Menu"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28
	draw_style_box(_panel(Color(0.055,0.12,0.14,0.8)), Rect2((w-hint_width)/2,h-181,hint_width,30))
	_center(Vector2(w/2, h-160), hint, 14)
	if toast_time > 0:
		var tw := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 40
		draw_style_box(_panel(Color(0.055,0.12,0.14,0.95)), Rect2((w-tw)/2, 30, tw, 44))
		_center(Vector2(w/2,58), toast, 16, GOLD)

func _draw_block(center: Vector2, color: Color, radius: float) -> void:
	var a := center + Vector2(0,-radius)
	var b := center + Vector2(radius, -radius * 0.45)
	var c := center + Vector2(0,0)
	var d := center + Vector2(-radius, -radius * 0.45)
	var e := center + Vector2(radius, radius * 0.6)
	var f := center + Vector2(0, radius * 1.15)
	var g := center + Vector2(-radius, radius * 0.6)
	draw_colored_polygon(PackedVector2Array([a,b,c,d]), color.lightened(0.18))
	draw_colored_polygon(PackedVector2Array([d,c,f,g]), color.darkened(0.23))
	draw_colored_polygon(PackedVector2Array([c,b,e,f]), color)

func _panel(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
