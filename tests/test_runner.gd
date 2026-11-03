extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const UpdateManager = preload("res://scripts/update_manager.gd")

var game: Node
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
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_new_game()
	await process_frame
	var world = game.world
	check(world.asteroids.size() > 0, "system generates asteroids")
	check(world.enemies.size() > 0, "system generates pirates")
	check(world.cargo_free() == 60, "new Wisp has expected cargo capacity")
	game._update_hud()
	check(not game.target_panel.visible, "empty target panel is hidden")

	# Mining simulation.
	var asteroid: Dictionary = world.asteroids[0]
	world.player["pos"] = asteroid["pos"] + Vector2(100, 0)
	world.target_kind = "asteroid"
	world.target_id = asteroid["id"]
	game._update_hud()
	check(game.target_panel.visible and game.target_panel.size.y <= 140, "selected target panel remains compact")
	world.mining = true
	world.auto_orbit = false
	for i in range(240):
		world.simulate(1.0 / 60.0)
	check(Data.cargo_used(game.profile) > 0, "mining transfers ore into cargo")
	check(int(game.profile["total_mined"]) > 0, "mining updates lifetime statistics")
	world.mining = false

	# Combat and loot simulation.
	var enemy: Dictionary = world.enemies[0]
	world.player["pos"] = enemy["pos"] + Vector2(220, 0)
	world.player["vel"] = Vector2.ZERO
	world.target_kind = "enemy"
	world.target_id = enemy["id"]
	world.firing = true
	for i in range(600):
		if world.enemies.is_empty():
			break
		world.simulate(1.0 / 60.0)
	check(int(game.profile["total_kills"]) > 0, "pulse laser destroys a pirate")
	check(world.loot.size() > 0, "destroyed pirate ejects salvage")
	world.firing = false
	world.auto_orbit = false

	# Docked services and economy.
	game.profile["credits"] = 10000
	game.open_station()
	await process_frame
	var credits_before: int = game.profile["credits"]
	game.buy_resource("ferrite")
	check(int(game.profile["credits"]) < credits_before, "market purchase deducts credits")
	check(game.station_notice.visible and not game.station_notice.text.is_empty(), "station transactions show visible feedback")
	game.sell_resource("ferrite")
	check(int(game.profile["credits"]) >= credits_before - 20, "market sale returns credits")

	game.contract_action("bounty")
	check(game.profile["contracts"]["bounty"]["accepted"], "bounty contract can be accepted")
	game.profile["contracts"]["bounty"]["progress"] = 3
	var before_reward: int = game.profile["credits"]
	game.contract_action("bounty")
	check(game.profile["contracts"]["bounty"]["completed"], "completed bounty can be claimed")
	check(int(game.profile["credits"]) == before_reward + 850, "bounty pays exact reward")

	var old_damage: float = world.stats["damage"]
	game.purchase_upgrade("laser")
	check(int(game.profile["upgrades"]["laser"]) == 1, "fitting purchases laser rank")
	check(float(world.stats["damage"]) > old_damage, "laser rank improves weapon damage")
	game.show_station_page("market")
	game.show_station_page("contracts")
	game.show_station_page("fitting")
	game.show_station_page("overview")
	game.undock()

	# Save and restore.
	check(game.save_game(), "local save writes successfully")
	var restored := SaveManager.read_save()
	check(not restored.is_empty(), "local save can be parsed")
	check(int(restored["upgrades"]["laser"]) == 1, "save preserves purchased upgrades")

	# Gate travel.
	world.plot_course("cinder")
	world.player["pos"] = world.gate_position + Vector2(170, 0)
	world.simulate(1.0 / 60.0)
	check(world.system_id == "cinder", "gate autopilot completes intersystem travel")
	check(game.profile["current_system"] == "cinder", "travel persists current system")

	# Destruction and insurance recovery.
	world._damage_player(100000.0)
	await process_frame
	game.recover_ship()
	check(Data.cargo_used(game.profile) == 0, "insurance recovery clears lost cargo")
	check(float(world.player["hull"]) > 0.0, "insurance recovery restores ship hull")

	# Update metadata, version ordering, and panel behavior (no network required).
	check(UpdateManager.is_newer_version("0.3.0", "0.2.0"), "updater detects a newer release")
	check(not UpdateManager.is_newer_version("0.2.0", "0.2.0"), "updater rejects the installed version")
	check(UpdateManager.is_newer_version("0.10.0", "0.9.9"), "updater compares numeric version segments")
	check(not UpdateManager.is_newer_version("0.1.9", "0.2.0"), "updater rejects older releases")
	var release_payload := {
		"tag_name": "v0.3.0",
		"name": "Voidfarer test update",
		"body": "Updater test notes",
		"draft": false,
		"prerelease": false,
		"html_url": "https://github.com/tensozanghetzu-hub/Voidfarer/releases/tag/v0.3.0",
		"assets": [{
			"name": "Voidfarer.apk",
			"browser_download_url": "https://github.com/tensozanghetzu-hub/Voidfarer/releases/download/v0.3.0/Voidfarer.apk",
			"size": 24371660,
			"digest": "sha256:abc123"
		}]
	}
	var parsed_release := UpdateManager.parse_release(release_payload)
	check(str(parsed_release.get("version", "")) == "0.3.0" and str(parsed_release.get("digest", "")) == "abc123", "updater parses release asset and digest")
	release_payload["assets"][0]["browser_download_url"] = "https://example.com/Voidfarer.apk"
	check(UpdateManager.parse_release(release_payload).is_empty(), "updater rejects an untrusted APK URL")
	game.show_menu()
	check(game.update_download_button.disabled, "updater disables download before a release is selected")
	game.updater.latest_release = parsed_release
	game.updater.status = "Update available · Voidfarer v0.3.0"
	game.open_updater()
	check(game.state == "updater" and game.update_screen.visible, "update panel opens from the main menu")
	check(not game.update_download_button.disabled, "available release enables the download button")
	game.close_updater()
	check(game.state == "menu" and not game.update_screen.visible, "update panel closes safely")

	SaveManager.delete_save()
	if failures.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("TEST FAILURES: ", failures)
		quit(1)
