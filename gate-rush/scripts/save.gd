extends RefCounted
class_name SaveState

## Progress has to survive the app closing or "progress further and further" means nothing.
const PATH := "user://gate_rush_save.json"

static func load_state() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {"level": 1, "upgrade": 0}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {"level": 1, "upgrade": 0}
	var txt := f.get_as_text()
	f.close()
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		return {"level": 1, "upgrade": 0}
	return d

static func save_state(d: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()
