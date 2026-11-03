extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://test-results")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_new_game()
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
	game.open_station()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("res://test-results/station.png")
	game.show_station_page("market")
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("res://test-results/market.png")
	game.show_station_page("contracts")
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("res://test-results/contracts.png")
	game.show_station_page("fitting")
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("res://test-results/fitting.png")
	game.undock()
	game.open_map()
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("res://test-results/map.png")
	print("Preview images captured")
	quit()
