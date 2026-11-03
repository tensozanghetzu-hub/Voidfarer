extends SceneTree

const UpdateManager = preload("res://scripts/update_manager.gd")

var manager: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	manager = UpdateManager.new()
	root.add_child(manager)
	await process_frame
	# Force any current public release to count as an update.
	manager.current_version = "0.0.1"
	manager.check_for_updates()
	var elapsed := 0.0
	while manager.is_busy() and elapsed < 60.0:
		await create_timer(0.1).timeout
		elapsed += 0.1
	check(manager.has_update(), "GitHub latest-release lookup returns a compatible APK")
	if not manager.has_update():
		print("Updater status: ", manager.status)
		quit(1)
		return
	print("Release: ", manager.latest_release["tag"], " · ", manager.latest_release["size"], " bytes")

	manager.download_update()
	elapsed = 0.0
	while manager.is_busy() and elapsed < 180.0:
		await create_timer(0.1).timeout
		elapsed += 0.1
	check(manager.has_download(), "GitHub APK download completes and is retained")
	if manager.has_download():
		var expected := str(manager.latest_release["digest"])
		if not expected.is_empty():
			check(FileAccess.get_sha256(manager.downloaded_path) == expected, "downloaded APK matches GitHub SHA-256")
		check(manager.install_downloaded() == "unsupported", "desktop install attempt safely reports Android-only status")
	else:
		print("Updater status: ", manager.status)

	if FileAccess.file_exists(UpdateManager.FINAL_PATH):
		DirAccess.remove_absolute(UpdateManager.FINAL_PATH)
	DirAccess.remove_absolute(UpdateManager.PART_PATH)
	if failures.is_empty():
		print("ALL NETWORK UPDATER TESTS PASSED")
		quit(0)
	else:
		print("NETWORK TEST FAILURES: ", failures)
		quit(1)
