extends RefCounted

const SAVE_PATH := "user://voidfarer_save.json"
const SAVE_VERSION := 1

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func write_save(profile: Dictionary) -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"profile": profile.duplicate(true)
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

static func read_save() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var payload = JSON.parse_string(text)
	if not payload is Dictionary:
		return {}
	if int(payload.get("version", 0)) != SAVE_VERSION:
		return {}
	var profile = payload.get("profile", {})
	if not profile is Dictionary:
		return {}
	return profile

static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
