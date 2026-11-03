extends Node

const Data = preload("res://scripts/game_data.gd")

const API_URL := "https://api.github.com/repos/tensozanghetzu-hub/Voidfarer/releases/latest"
const RELEASES_URL := "https://github.com/tensozanghetzu-hub/Voidfarer/releases"
const DOWNLOAD_URL_PREFIX := "https://github.com/tensozanghetzu-hub/Voidfarer/releases/download/"
const ASSET_NAME := "Voidfarer.apk"
const UPDATE_DIR := "user://updates"
const PART_PATH := "user://updates/Voidfarer-update.apk.part"
const FINAL_PATH := "user://updates/Voidfarer-update.apk"
var request_headers := PackedStringArray([
	"Accept: application/vnd.github+json",
	"User-Agent: Voidfarer-Android-Updater",
	"X-GitHub-Api-Version: 2022-11-28"
])

signal changed
signal progress_changed(received: int, total: int)

var current_version := Data.GAME_VERSION
var operation := ""
var status := "Check GitHub only when you choose. Gameplay remains offline."
var latest_release: Dictionary = {}
var downloaded_path := ""
var downloaded_tag := ""
var last_progress := -1

var check_request: HTTPRequest
var download_request: HTTPRequest

func _ready() -> void:
	check_request = _make_request(45.0)
	check_request.body_size_limit = 2 * 1024 * 1024
	check_request.request_completed.connect(_on_check_completed)
	download_request = _make_request(0.0)
	download_request.request_completed.connect(_on_download_completed)

func _make_request(timeout_seconds: float) -> HTTPRequest:
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = timeout_seconds
	request.max_redirects = 8
	request.use_threads = true
	request.download_chunk_size = 65536
	return request

func is_busy() -> bool:
	return not operation.is_empty()

func has_update() -> bool:
	return not latest_release.is_empty()

func has_download() -> bool:
	return not downloaded_path.is_empty() and FileAccess.file_exists(downloaded_path)

func check_for_updates() -> void:
	if is_busy():
		return
	latest_release.clear()
	downloaded_path = ""
	downloaded_tag = ""
	_remove_if_exists(PART_PATH)
	_remove_if_exists(FINAL_PATH)
	last_progress = -1
	operation = "check"
	status = "Checking the latest GitHub release…"
	changed.emit()
	var error := check_request.request(API_URL, request_headers)
	if error != OK:
		_fail("Could not start the update check. Open Releases or try again later.", "check")

func download_update() -> void:
	if is_busy() or latest_release.is_empty():
		return
	if has_download() and downloaded_tag == str(latest_release["tag"]):
		status = "Update already downloaded and verified. Ready to install."
		changed.emit()
		return
	DirAccess.make_dir_recursive_absolute(UPDATE_DIR)
	_remove_if_exists(PART_PATH)
	_remove_if_exists(FINAL_PATH)
	downloaded_path = ""
	downloaded_tag = ""
	last_progress = -1
	operation = "download"
	status = "Downloading Voidfarer v%s…" % str(latest_release["version"])
	download_request.download_file = PART_PATH
	changed.emit()
	progress_changed.emit(0, int(latest_release["size"]))
	var error := download_request.request(str(latest_release["url"]), request_headers)
	if error != OK:
		_fail("Could not start the download. Check your connection and try again.", "download")

func cancel() -> void:
	if operation == "check":
		check_request.cancel_request()
	elif operation == "download":
		download_request.cancel_request()
		_remove_if_exists(PART_PATH)
	else:
		return
	operation = ""
	status = "Update request canceled. No changes were installed."
	progress_changed.emit(0, 0)
	changed.emit()

func install_downloaded() -> String:
	if not has_download():
		status = "Download and verify an update before installing."
		changed.emit()
		return "error"
	if OS.get_name() != "Android":
		status = "The APK is verified. Android installation is available on an Android device."
		changed.emit()
		return "unsupported"
	if not Engine.has_singleton("VoidfarerUpdater"):
		status = "The Android installer bridge is unavailable. Use the Releases page instead."
		changed.emit()
		return "error"
	var bridge = Engine.get_singleton("VoidfarerUpdater")
	var result: String = str(bridge.installApk(ProjectSettings.globalize_path(downloaded_path)))
	match result:
		"started":
			status = "Android's installer is open. Confirm the update; your save is retained."
		"permission_required":
			status = "Enable ‘Allow from this source’ for Voidfarer, return here, then tap INSTALL again."
		_:
			status = "Could not open Android's installer. %s" % result.trim_prefix("error: ")
	changed.emit()
	return result

func open_releases() -> void:
	OS.shell_open(RELEASES_URL)

func _process(_delta: float) -> void:
	if operation != "download":
		return
	var received := download_request.get_downloaded_bytes()
	var total := download_request.get_body_size()
	if total <= 0 and not latest_release.is_empty():
		total = int(latest_release["size"])
	var marker := int(float(received) / 262144.0)
	if marker != last_progress:
		last_progress = marker
		progress_changed.emit(received, total)

func _on_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if operation != "check":
		return
	operation = ""
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("GitHub could not be reached. Check your connection or open Releases.", "")
		return
	if response_code != 200:
		_fail("GitHub returned HTTP %d. Try again later or open Releases." % response_code, "")
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		_fail("GitHub returned an unreadable release response. Try again later.", "")
		return
	var parsed := parse_release(json.data)
	if parsed.is_empty():
		_fail("The latest release has no compatible Voidfarer.apk download.", "")
		return
	if not is_newer_version(str(parsed["version"]), current_version):
		status = "You’re up to date · Voidfarer v%s" % current_version
		changed.emit()
		return
	latest_release = parsed
	status = "Update available · Voidfarer v%s" % str(parsed["version"])
	changed.emit()

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if operation != "download":
		return
	operation = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_remove_if_exists(PART_PATH)
		_fail("The update download was interrupted. No partial file was kept.", "")
		return
	if not FileAccess.file_exists(PART_PATH):
		_fail("The downloaded APK could not be saved on this device.", "")
		return
	var file := FileAccess.open(PART_PATH, FileAccess.READ)
	if file == null:
		_fail("The downloaded APK could not be read for verification.", "")
		return
	var actual_size := file.get_length()
	file.close()
	var expected_size := int(latest_release["size"])
	if expected_size > 0 and actual_size != expected_size:
		_remove_if_exists(PART_PATH)
		_fail("The APK size did not match GitHub's release data. The file was deleted.", "")
		return
	var expected_digest := str(latest_release["digest"])
	if not expected_digest.is_empty():
		var actual_digest := FileAccess.get_sha256(PART_PATH)
		if actual_digest.to_lower() != expected_digest.to_lower():
			_remove_if_exists(PART_PATH)
			_fail("The APK integrity check failed. The file was deleted.", "")
			return
	_remove_if_exists(FINAL_PATH)
	if DirAccess.rename_absolute(PART_PATH, FINAL_PATH) != OK:
		_remove_if_exists(PART_PATH)
		_fail("The verified APK could not be moved into the update folder.", "")
		return
	downloaded_path = FINAL_PATH
	downloaded_tag = str(latest_release["tag"])
	status = "Download verified · v%s is ready to install." % str(latest_release["version"])
	progress_changed.emit(actual_size, actual_size)
	changed.emit()

func _fail(message: String, expected_operation: String) -> void:
	if not expected_operation.is_empty() and operation != expected_operation:
		return
	operation = ""
	status = message
	progress_changed.emit(0, 0)
	changed.emit()

static func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

static func parse_release(payload: Dictionary) -> Dictionary:
	if bool(payload.get("draft", false)) or bool(payload.get("prerelease", false)):
		return {}
	var tag := str(payload.get("tag_name", "")).strip_edges()
	if tag.is_empty():
		return {}
	var assets = payload.get("assets", [])
	if not assets is Array:
		return {}
	for item in assets:
		if not item is Dictionary:
			continue
		if str(item.get("name", "")) != ASSET_NAME:
			continue
		var url := str(item.get("browser_download_url", ""))
		var size := int(item.get("size", 0))
		if not url.begins_with(DOWNLOAD_URL_PREFIX) or size <= 0:
			return {}
		var digest := ""
		if item.get("digest", null) is String:
			digest = str(item["digest"]).trim_prefix("sha256:")
		var notes = payload.get("body", "")
		if notes == null:
			notes = ""
		return {
			"tag": tag,
			"version": tag.trim_prefix("v"),
			"title": str(payload.get("name", "Voidfarer update")),
			"notes": str(notes).left(16000),
			"url": url,
			"size": size,
			"digest": digest,
			"page": str(payload.get("html_url", RELEASES_URL))
		}
	return {}

static func is_newer_version(candidate: String, current: String) -> bool:
	var left := _version_parts(candidate)
	var right := _version_parts(current)
	for index in range(3):
		if left[index] > right[index]:
			return true
		if left[index] < right[index]:
			return false
	return false

static func _version_parts(value: String) -> Array[int]:
	var clean := value.strip_edges().trim_prefix("v").split("-", false)[0].split("+", false)[0]
	var pieces := clean.split(".", false)
	var result: Array[int] = [0, 0, 0]
	for index in range(mini(3, pieces.size())):
		var piece := pieces[index]
		result[index] = int(piece) if piece.is_valid_int() else 0
	return result
