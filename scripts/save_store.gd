extends RefCounted

const VERSION := 1
const PATH := "user://world.json"
var last_error := ""

func read_save(path: String = PATH) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path): return {}
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
	if data.get("version") != VERSION or data.get("generator") != 1: return {}
	if not (data.get("seed") is float or data.get("seed") is int): return {}
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
