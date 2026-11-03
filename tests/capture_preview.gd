extends SceneTree

const UpdateManager = preload("res://scripts/update_manager.gd")
const SaveManager = preload("res://scripts/save_manager.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_new_game()
	game._update_hud()
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("res://test-results/flight-empty.png")
	var world = game.world
	var asteroid: Dictionary = world.asteroids[0]
	world.player["pos"] = asteroid["pos"] + Vector2(170, -60)
	world.camera_pos = world.player["pos"] + Vector2(-100, -80)
	world.target_kind = "asteroid"
	world.target_id = asteroid["id"]
	world.mining = true
	world.auto_orbit = true
	await create_timer(0.7).timeout
	root.get_texture().get_image().save_png("res://test-results/flight.png")
	world.mining = false
	world.auto_orbit = false
	world._damage_enemy(world.enemies[0], 100000.0)
	var salvage: Dictionary = world.loot[0]
	salvage["pos"] = world.player["pos"] + Vector2(430, -120)
	world.toggle_tractor()
	await create_timer(0.25).timeout
	game._update_hud()
	root.get_texture().get_image().save_png("res://test-results/tractor.png")
	world.tractor_active = false
	game.open_station()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("res://test-results/station.png")
	game.show_station_page("market")
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("res://test-results/market.png")
	game.show_station_page("contracts")
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("res://test-results/contracts.png")
	game.profile["credits"] = 10000
	game.purchase_upgrade("laser")
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("res://test-results/fitting.png")
	game.undock()
	game.open_map()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("res://test-results/map.png")
	game.show_menu()
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("res://test-results/menu.png")
	game.updater.latest_release = {
		"tag": "v0.3.0",
		"version": "0.3.0",
		"title": "Voidfarer: Frontier Signals",
		"notes": "A preview of the manual update flow.\n\n• Check GitHub only when requested\n• Verify the downloaded APK\n• Confirm installation through Android\n\nGameplay and local saves remain available offline.",
		"url": UpdateManager.DOWNLOAD_URL_PREFIX + "v0.3.0/Voidfarer.apk",
		"size": 24371660,
		"digest": "abc123",
		"page": UpdateManager.RELEASES_URL
	}
	game.updater.status = "Update available · Voidfarer v0.3.0"
	game.open_updater()
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("res://test-results/updater.png")
	DirAccess.make_dir_recursive_absolute(UpdateManager.UPDATE_DIR)
	var placeholder := FileAccess.open(UpdateManager.FINAL_PATH, FileAccess.WRITE)
	placeholder.store_buffer(PackedByteArray([1]))
	placeholder.close()
	game.updater.downloaded_path = UpdateManager.FINAL_PATH
	game.updater.downloaded_tag = "v0.3.0"
	game.updater.status = "Download verified · v0.3.0 is ready to install."
	game.updater.progress_changed.emit(24371660, 24371660)
	game.updater.changed.emit()
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("res://test-results/updater-ready.png")
	game.close_updater()
	DirAccess.remove_absolute(UpdateManager.FINAL_PATH)
	SaveManager.delete_save()
	print("Preview images captured")
	quit()
