extends RefCounted

const VERSION := 3
const PATH := "user://world.json"
const Catalog = preload("res://scripts/world_catalog.gd")
const WORLD_IDS := Catalog.WORLD_IDS
var last_error := ""

func world_path(world_id: String, base: String = "user://") -> String:
	var item := Catalog.entry(world_id)
	return "" if item.is_empty() else base.path_join(item["path"])

func read_world(world_id: String, base: String = "user://") -> Dictionary:
	var path := world_path(world_id,base)
	if path.is_empty():
		last_error = "Dunia tidak dikenal."
		return {}
	var data := read_save(path)
	if not data.is_empty() and data.get("world_id","classic") != world_id:
		last_error = "Identitas save tidak cocok. File tidak diubah."
		return {}
	return data

func prepare_world(world_id: String, base: String = "user://") -> bool:
	last_error = ""
	var path := world_path(world_id,base)
	if path.is_empty(): return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		last_error = "Folder save dunia tidak dapat disiapkan."
		return false
	# Keep the old path; take a one-time snapshot instead of moving or rewriting the player's save.
	if world_id == "classic" and not FileAccess.file_exists(path+".pre-v0.3.bak"):
		var source := path if not _read_valid(path).is_empty() else path+".bak"
		if not _read_valid(source).is_empty() and DirAccess.copy_absolute(source,path+".pre-v0.3.bak") != OK:
			last_error = "Cadangan dunia lama gagal dibuat; pemuatan dibatalkan."
			return false
	return true

func read_save(path: String = PATH) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"): return {}
	var result := _read_valid(path)
	if result.is_empty():
		result = _read_valid(path + ".bak")
		last_error = "Save utama rusak; cadangan dipulihkan." if not result.is_empty() else "Save tidak dapat dibaca. File lama tetap disimpan."
	return result

func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 20000000: return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {}
	var data: Variant = parser.data
	if not data is Dictionary: return {}
	var version: Variant = data.get("version")
	if version != 1 and version != 2 and version != VERSION: return {}
	if version == 3:
		if not data.get("world_id") is String: return {}
		var item := Catalog.entry(data["world_id"])
		if item.is_empty() or data.get("world_size") != item["size"] or data.get("generator") != item["generator"]: return {}
		if item["generator"]>=3 and data.get("world_height") != item["height"]: return {}
		if not data.get("animals",[]) is Array: return {}
		if not data.get("vehicles",[]) is Array: return {}
	elif data.get("generator") != 1: return {}
	if version >= 2:
		var hotbar: Variant = data.get("hotbar")
		if not hotbar is Array or hotbar.size() != 8: return {}
	if not (data.get("seed") is float or data.get("seed") is int): return {}
	if not is_finite(float(data["seed"])): return {}
	if not data.get("changes") is Dictionary: return {}
	var pos: Variant = data.get("position")
	if not pos is Array or pos.size() != 3: return {}
	for n in pos:
		if not (n is float or n is int) or not is_finite(float(n)): return {}
	for field in ["yaw", "pitch", "selected"]:
		var value: Variant = data.get(field)
		if not (value is float or value is int) or not is_finite(float(value)): return {}
	return data

func write_save(data: Dictionary, path: String = PATH) -> bool:
	last_error = ""
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Tidak bisa menulis save: %s" % error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "Penyimpanan gagal: %s" % error_string(write_error)
		return false
	# Only a valid previous save replaces the backup; a corrupt primary never destroys it.
	if not _read_valid(path).is_empty():
		var copy_error := DirAccess.copy_absolute(path, path + ".bak")
		if copy_error != OK:
			last_error = "Cadangan save gagal dibuat: %s" % error_string(copy_error)
			return false
	elif FileAccess.file_exists(path):
		var archive_error := DirAccess.copy_absolute(path, path + ".corrupt-" + str(Time.get_unix_time_from_system()).replace(".", "-"))
		if archive_error != OK:
			last_error = "Save lama tidak dapat diamankan: %s" % error_string(archive_error)
			return false
	var rename_error := DirAccess.rename_absolute(path + ".tmp", path)
	if rename_error != OK:
		last_error = "Save gagal diperbarui: %s" % error_string(rename_error)
		return false
	return true
