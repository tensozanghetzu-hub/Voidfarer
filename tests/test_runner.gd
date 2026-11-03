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
	asteroid["resource"] = "crystal"
	game.profile["contracts"]["deep_core_survey"]["accepted"] = true
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
	check(int(game.profile["contracts"]["deep_core_survey"]["progress"]) > 0, "mining advances survey contract")
	world.mining = false
	var depleted_id := int(asteroid["id"])
	asteroid["amount"] = 1
	world.mining = true
	world.mine_accumulator = 0.0
	for i in range(180):
		world.simulate(1.0 / 60.0)
	var depleted_asteroid_present := false
	for rock in world.asteroids:
		if int(rock["id"]) == depleted_id:
			depleted_asteroid_present = true
	check(not depleted_asteroid_present, "depleted asteroid disappears")
	check(world.target_id != depleted_id and not world.mining, "depletion clears target and mining")

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
	var salvage: Dictionary = world.loot[0]
	game.profile["contracts"]["salvage_sweep"]["accepted"] = true
	salvage["pos"] = world.player["pos"] + Vector2(500, 0)
	var cargo_before_tractor := Data.cargo_used(game.profile)
	world.toggle_tractor()
	check(world.tractor_active, "salvage tractor can be engaged")
	for i in range(300):
		world.simulate(1.0 / 60.0)
		if world.loot.is_empty():
			break
	check(world.loot.is_empty() and Data.cargo_used(game.profile) > cargo_before_tractor, "tractor pulls salvage into cargo")
	check(int(game.profile["contracts"]["salvage_sweep"]["progress"]) > 0, "salvage recovery advances contract")
	world.tractor_active = false

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
	check(game.station_credits_label.visible and game.station_credits_label.text == "%s CR" % game._number(game.profile["credits"]), "fitting keeps credit balance visible")
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

	# New objective types and completion claims.
	world.record_contract_event("mining", "crystal", 100)
	world.record_contract_event("salvage", "salvage", 100)
	check(int(game.profile["contracts"]["deep_core_survey"]["progress"]) == int(Data.CONTRACTS["deep_core_survey"]["target"]), "survey objective reaches its target")
	var objective_credits: int = game.profile["credits"]
	game.contract_action("deep_core_survey")
	game.contract_action("salvage_sweep")
	check(int(game.profile["credits"]) == objective_credits + int(Data.CONTRACTS["deep_core_survey"]["reward"]) + int(Data.CONTRACTS["salvage_sweep"]["reward"]), "mining and salvage contracts pay exact rewards")
	game.undock()
	game.profile["contracts"]["revenant_hunt"]["accepted"] = true
	world.load_system("umbra")
	var elite: Dictionary = world.enemies[0]
	check(bool(elite["elite"]), "Umbra generates an elite contract target")
	world._damage_enemy(elite, 100000.0)
	check(int(game.profile["contracts"]["revenant_hunt"]["progress"]) == 1, "elite kill advances Revenant contract")
	world.respawn_timer = 0.0
	world.simulate(1.0 / 60.0)
	var elite_respawned := false
	for respawned_enemy in world.enemies:
		if bool(respawned_enemy["elite"]):
			elite_respawned = true
			break
	check(elite_respawned, "Umbra restores an elite target for later hunts")
	game.open_station()
	objective_credits = game.profile["credits"]
	game.contract_action("revenant_hunt")
	check(int(game.profile["credits"]) == objective_credits + int(Data.CONTRACTS["revenant_hunt"]["reward"]), "elite contract pays exact reward")

	# Tactical system map, live minimap, and galaxy routing page.
	game.undock()
	check(game.minimap.visible and not game.minimap.full_map, "live radar minimap is visible during flight")
	game.open_map()
	check(game.state == "map" and game.system_map.visible and game.system_map.full_map, "full tactical system map opens from flight")
	game.show_map_page("galaxy")
	check(not game.system_map.visible and game.map_list.get_child_count() == Data.SYSTEMS.size(), "galaxy page retains all gate destinations")
	game.close_map()
	check(game.state == "space" and game.minimap.visible, "closing navigation restores flight and radar")

	# Five-hull shipyard, persistent ownership, and save migration.
	game.open_station()
	game.profile["credits"] = 50000
	game.ship_action("atlas")
	check(str(game.profile["ship"]) == "atlas" and game.profile["owned_ships"].has("atlas"), "Atlas purchase registers a new owned hull")
	check(int(world.stats["cargo"]) > int(Data.SHIPS["wisp"]["cargo"]), "Atlas provides specialized cargo capacity")
	game.ship_action("razor")
	check(float(world.stats["speed"]) > float(Data.SHIPS["atlas"]["speed"]), "Razor provides interceptor speed")
	game.ship_action("delver")
	check(float(world.stats["mining_rate"]) > float(Data.SHIPS["wisp"]["mining_rate"]), "Delver provides specialized mining yield")
	var before_refit: int = game.profile["credits"]
	game.ship_action("atlas")
	check(int(game.profile["credits"]) == before_refit and str(game.profile["ship"]) == "atlas", "owned hulls can be refitted without another charge")
	var legacy_profile := Data.default_profile()
	legacy_profile["ship"] = "kestrel"
	legacy_profile.erase("owned_ships")
	legacy_profile = Data.normalize_profile(legacy_profile)
	check(legacy_profile["owned_ships"].has("wisp") and legacy_profile["owned_ships"].has("kestrel"), "legacy saves migrate current ship ownership")
	var razor_capacity := int(Data.ship_stats(game.profile, "razor")["cargo"])
	game.profile["cargo"]["ferrite"] = razor_capacity + 1
	game.ship_action("razor")
	check(str(game.profile["ship"]) == "atlas", "ship fitting prevents switching below current cargo load")
	for resource_id in game.profile["cargo"]:
		game.profile["cargo"][resource_id] = 0

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
