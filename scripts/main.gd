extends Node2D

const Data = preload("res://scripts/game_data.gd")
const SaveManager = preload("res://scripts/save_manager.gd")
const WorldScript = preload("res://scripts/space_world.gd")
const JoystickScript = preload("res://scripts/touch_joystick.gd")
const UpdateManagerScript = preload("res://scripts/update_manager.gd")

const CYAN := Color("69e8f2")
const TEXT := Color("d7edf2")
const MUTED := Color("7d9ba9")
const PANEL := Color(0.025, 0.065, 0.105, 0.94)
const BORDER := Color(0.22, 0.65, 0.73, 0.34)

var world: Node2D
var profile: Dictionary = {}
var ui_layer: CanvasLayer
var theme: Theme
var state := "menu"

var menu_screen: Control
var hud: Control
var station_screen: Control
var map_screen: Control
var pause_screen: Control
var death_screen: Control
var continue_button: Button

var system_label: Label
var security_label: Label
var credits_label: Label
var cargo_label: Label
var target_title: Label
var target_detail: Label
var target_bar: ProgressBar
var shield_bar: ProgressBar
var armor_bar: ProgressBar
var hull_bar: ProgressBar
var energy_bar: ProgressBar
var condition_label: Label
var notice_label: Label
var hint_label: Label
var fire_button: Button
var mine_button: Button
var orbit_button: Button
var dock_button: Button
var station_title: Label
var station_subtitle: Label
var station_content: VBoxContainer
var station_notice: Label
var station_page := "overview"
var map_list: VBoxContainer
var map_subtitle: Label
var death_detail: Label

var updater: Node
var update_screen: Control
var update_version_label: Label
var update_status_label: Label
var update_notes_label: Label
var update_progress_bar: ProgressBar
var update_progress_label: Label
var update_check_button: Button
var update_download_button: Button
var update_install_button: Button
var update_cancel_button: Button

var notice_timer := 0.0
var hud_timer := 0.0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_register_inputs()
	_build_theme()
	world = WorldScript.new()
	world.name = "SpaceWorld"
	add_child(world)
	world.notice.connect(show_notice)
	world.dock_requested.connect(open_station)
	world.destruction_requested.connect(open_death)
	world.travelled.connect(func(): save_game())
	profile = Data.default_profile()
	world.setup(profile, false)
	ui_layer = CanvasLayer.new()
	ui_layer.name = "Interface"
	add_child(ui_layer)
	updater = UpdateManagerScript.new()
	updater.name = "UpdateManager"
	add_child(updater)
	updater.changed.connect(_refresh_update_panel)
	updater.progress_changed.connect(_on_update_progress)
	_build_menu()
	_build_hud()
	_build_station()
	_build_map()
	_build_pause()
	_build_death()
	_build_updater()
	show_menu()

func _register_inputs() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("fire", [KEY_SPACE])
	_add_key_action("mine", [KEY_M])
	_add_key_action("orbit", [KEY_O])
	_add_key_action("dock", [KEY_F])
	_add_key_action("target", [KEY_TAB])
	_add_key_action("galaxy_map", [KEY_G])

func _add_key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color("a9fbff"))
	theme.set_color("font_disabled_color", "Button", Color("4d6570"))
	theme.set_stylebox("normal", "Button", _style(Color("0d2534"), BORDER, 7))
	theme.set_stylebox("hover", "Button", _style(Color("153b4b"), Color(CYAN, 0.65), 7))
	theme.set_stylebox("pressed", "Button", _style(Color("1a4c59"), CYAN, 7))
	theme.set_stylebox("disabled", "Button", _style(Color("09151e"), Color("263c47"), 7))
	theme.set_stylebox("panel", "PanelContainer", _style(PANEL, BORDER, 10))
	theme.set_stylebox("panel", "Panel", _style(PANEL, BORDER, 10))
	theme.set_stylebox("background", "ProgressBar", _style(Color("07131d"), Color("203b47"), 4))
	theme.set_stylebox("fill", "ProgressBar", _style(CYAN, Color.TRANSPARENT, 4))

func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

func _full_control(parent: Node) -> Control:
	var control := Control.new()
	parent.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control

func _overlay(name: String, dim := true) -> Control:
	var root := _full_control(ui_layer)
	root.name = name
	if dim:
		var background := ColorRect.new()
		root.add_child(background)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.color = Color(0.005, 0.015, 0.027, 0.86)
		background.mouse_filter = Control.MOUSE_FILTER_STOP
	return root

func _center_panel(parent: Control, width: float, height: float) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5
	panel.theme = theme
	return panel

func _margin(parent: Node, amount := 18) -> MarginContainer:
	var margin := MarginContainer.new()
	parent.add_child(margin)
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_top", amount)
	margin.add_theme_constant_override("margin_bottom", amount)
	return margin

func _vbox(parent: Node, separation := 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	parent.add_child(box)
	box.add_theme_constant_override("separation", separation)
	return box

func _hbox(parent: Node, separation := 10) -> HBoxContainer:
	var box := HBoxContainer.new()
	parent.add_child(box)
	box.add_theme_constant_override("separation", separation)
	return box

func _label(parent: Node, text: String, size := 17, color := TEXT) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.text = text
	label.theme = theme
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(parent: Node, text: String, callback: Callable, minimum := Vector2(130, 46)) -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.text = text
	button.theme = theme
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button

func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	parent.add_child(bar)
	bar.custom_minimum_size = Vector2(150, 12)
	bar.show_percentage = false
	bar.theme = theme
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT, 4))
	return bar

func _fixed_label(parent: Node, text: String, width: float, size := 17, color := TEXT) -> Label:
	var label := _label(parent, text, size, color)
	label.custom_minimum_size.x = width
	return label

func _stat_row(parent: Node, title: String, value: String, color := TEXT) -> void:
	var row := _hbox(parent, 18)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fixed_label(row, title, 175, 15, MUTED)
	var value_label := _label(row, value, 17, color)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _spacer(parent: Node, height := 8) -> void:
	var spacer := Control.new()
	parent.add_child(spacer)
	spacer.custom_minimum_size = Vector2(1, height)

func _build_menu() -> void:
	menu_screen = _overlay("MainMenu", false)
	var shade := ColorRect.new()
	menu_screen.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.015, 0.027, 0.44)
	var panel := _center_panel(menu_screen, 570, 600)
	var box := _vbox(_margin(panel, 28), 13)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var eyebrow := _label(box, "O F F L I N E   S P A C E   S A N D B O X", 14, CYAN)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _label(box, "VOIDFARER", 54, Color("e5fdff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label(box, "Chart your own course through a compact, living frontier.", 18, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spacer(box, 14)
	_button(box, "NEW FLIGHT", start_new_game, Vector2(0, 54))
	continue_button = _button(box, "CONTINUE", continue_game, Vector2(0, 50))
	_button(box, "FLIGHT MANUAL", show_flight_manual, Vector2(0, 46))
	_button(box, "CHECK FOR UPDATES", open_updater, Vector2(0, 44))
	_button(box, "QUIT", func(): get_tree().quit(), Vector2(0, 42))
	_spacer(box, 6)
	var footer := _label(box, "FIRST LIGHT  ·  v%s  ·  NO AUDIO  ·  LOCAL SAVE" % Data.GAME_VERSION, 12, MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_hud() -> void:
	hud = _full_control(ui_layer)
	hud.name = "FlightHUD"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := PanelContainer.new()
	hud.add_child(top)
	top.theme = theme
	top.anchor_left = 0.015
	top.anchor_right = 0.985
	top.offset_top = 12
	top.offset_bottom = 74
	var row := _hbox(_margin(top, 9), 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var brand := _label(row, "VOIDFARER", 20, CYAN)
	brand.custom_minimum_size.x = 145
	system_label = _label(row, "HAVEN REACH", 18)
	system_label.custom_minimum_size.x = 205
	security_label = _label(row, "SEC 0.9", 15, MUTED)
	security_label.custom_minimum_size.x = 90
	credits_label = _label(row, "650 CR", 18, Color("ffd28a"))
	credits_label.custom_minimum_size.x = 145
	cargo_label = _label(row, "CARGO 0/60", 15)
	cargo_label.custom_minimum_size.x = 150
	var flex := Control.new()
	row.add_child(flex)
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row, "MAP", open_map, Vector2(82, 40))
	_button(row, "II", open_pause, Vector2(58, 40))

	var target_panel := PanelContainer.new()
	hud.add_child(target_panel)
	target_panel.theme = theme
	target_panel.anchor_left = 0.5
	target_panel.anchor_right = 0.5
	target_panel.offset_left = -210
	target_panel.offset_right = 210
	target_panel.offset_top = 88
	target_panel.offset_bottom = 172
	var target_box := _vbox(_margin(target_panel, 8), 4)
	target_title = _label(target_box, "NO TARGET", 15, CYAN)
	target_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_detail = _label(target_box, "Tap a ship or asteroid", 12, MUTED)
	target_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_bar = _bar(target_box, Color("ff9c75"))
	target_bar.custom_minimum_size.y = 7

	var status := PanelContainer.new()
	hud.add_child(status)
	status.theme = theme
	status.anchor_left = 0.5
	status.anchor_right = 0.5
	status.anchor_top = 1.0
	status.anchor_bottom = 1.0
	status.offset_left = -215
	status.offset_right = 215
	status.offset_top = -124
	status.offset_bottom = -16
	var status_box := _vbox(_margin(status, 8), 5)
	condition_label = _label(status_box, "SHIELD 120  ·  ARMOR 80  ·  HULL 70", 12, MUTED)
	condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shield_bar = _bar(status_box, Color("58d9f0"))
	armor_bar = _bar(status_box, Color("a8b7c8"))
	hull_bar = _bar(status_box, Color("ff9b73"))
	energy_bar = _bar(status_box, Color("c399ff"))

	var joystick := JoystickScript.new()
	hud.add_child(joystick)
	joystick.anchor_left = 0.02
	joystick.anchor_right = 0.02
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_right = 190
	joystick.offset_top = -206
	joystick.offset_bottom = -16
	joystick.changed.connect(func(value: Vector2):
		world.input_vector = value
		if value.length() > 0.15:
			world.clear_course()
	)

	var actions := PanelContainer.new()
	hud.add_child(actions)
	actions.theme = theme
	actions.anchor_left = 1.0
	actions.anchor_right = 1.0
	actions.anchor_top = 1.0
	actions.anchor_bottom = 1.0
	actions.offset_left = -388
	actions.offset_right = -16
	actions.offset_top = -206
	actions.offset_bottom = -16
	var action_margin := _margin(actions, 10)
	var grid := GridContainer.new()
	action_margin.add_child(grid)
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	fire_button = _button(grid, "FIRE", func(): world.toggle_fire(), Vector2(110, 66))
	mine_button = _button(grid, "MINE", func(): world.toggle_mine(), Vector2(110, 66))
	orbit_button = _button(grid, "ORBIT", func(): world.toggle_orbit(), Vector2(110, 66))
	_button(grid, "TARGET", func(): world.cycle_target(), Vector2(110, 66))
	dock_button = _button(grid, "DOCK", func(): world.request_dock(), Vector2(110, 66))
	_button(grid, "MAP", open_map, Vector2(110, 66))

	hint_label = _label(hud, "", 13, MUTED)
	hint_label.anchor_left = 0.02
	hint_label.anchor_right = 0.40
	hint_label.offset_top = 86
	hint_label.offset_bottom = 150
	notice_label = _label(hud, "", 16, Color("c7fbff"))
	notice_label.anchor_left = 0.25
	notice_label.anchor_right = 0.75
	notice_label.anchor_top = 1.0
	notice_label.anchor_bottom = 1.0
	notice_label.offset_top = -178
	notice_label.offset_bottom = -136
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_station() -> void:
	station_screen = _overlay("Station")
	var panel := _center_panel(station_screen, 1100, 630)
	var outer := _vbox(_margin(panel, 20), 12)
	var header := _hbox(outer, 12)
	var titles := _vbox(header, 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	station_title = _label(titles, "ASTERION ANCHORAGE", 27, CYAN)
	station_subtitle = _label(titles, "Docked", 14, MUTED)
	_button(header, "SAVE", func(): save_game(); show_notice("Flight saved"), Vector2(110, 44))
	_button(header, "UNDOCK", undock, Vector2(140, 44))
	var navigation := _hbox(outer, 8)
	_button(navigation, "OVERVIEW", func(): show_station_page("overview"), Vector2(150, 42))
	_button(navigation, "MARKET", func(): show_station_page("market"), Vector2(150, 42))
	_button(navigation, "CONTRACTS", func(): show_station_page("contracts"), Vector2(150, 42))
	_button(navigation, "FITTING", func(): show_station_page("fitting"), Vector2(150, 42))
	var rule := HSeparator.new()
	outer.add_child(rule)
	var scroll := ScrollContainer.new()
	outer.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	station_content = _vbox(scroll, 12)
	station_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	station_notice = _label(outer, "", 15, Color("ffd28a"))
	station_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	station_notice.visible = false

func _build_map() -> void:
	map_screen = _overlay("GalaxyMap")
	var panel := _center_panel(map_screen, 950, 610)
	var outer := _vbox(_margin(panel, 22), 12)
	var title_row := _hbox(outer, 12)
	var titles := _vbox(title_row, 3)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(titles, "GALAXY MAP", 28, CYAN)
	map_subtitle = _label(titles, "", 14, MUTED)
	_button(title_row, "RETURN TO FLIGHT", close_map, Vector2(190, 44))
	_label(outer, "Plotting a route engages autopilot toward the local jump gate. Manual movement cancels the route.", 14, MUTED)
	var scroll := ScrollContainer.new()
	outer.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_list = _vbox(scroll, 10)
	map_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _build_pause() -> void:
	pause_screen = _overlay("Pause")
	var panel := _center_panel(pause_screen, 450, 410)
	var box := _vbox(_margin(panel, 24), 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := _label(box, "FLIGHT PAUSED", 30, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(box, "RESUME", close_pause, Vector2(0, 52))
	_button(box, "SAVE FLIGHT", func(): save_game(); show_notice("Flight saved"), Vector2(0, 48))
	_button(box, "FLIGHT MANUAL", show_flight_manual, Vector2(0, 48))
	_button(box, "SAVE & MAIN MENU", func(): save_game(); show_menu(), Vector2(0, 48))

func _build_death() -> void:
	death_screen = _overlay("ShipLost")
	var panel := _center_panel(death_screen, 540, 390)
	var box := _vbox(_margin(panel, 24), 15)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := _label(box, "SHIP LOST", 34, Color("ff9a78"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_detail = _label(box, "Your rescue capsule has been recovered. Cargo was lost, but your ship can be restored through frontier insurance.", 17, MUTED)
	death_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(box, "RECOVER AT STATION", recover_ship, Vector2(0, 54))
	_button(box, "RETURN TO MAIN MENU", show_menu, Vector2(0, 46))

func _build_updater() -> void:
	update_screen = _overlay("FlightUpdates")
	var panel := _center_panel(update_screen, 800, 620)
	var outer := _vbox(_margin(panel, 22), 10)
	var title_row := _hbox(outer, 10)
	var titles := _vbox(title_row, 3)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(titles, "FLIGHT UPDATES", 28, CYAN)
	update_version_label = _label(titles, "", 13, MUTED)
	update_cancel_button = _button(title_row, "CANCEL", func(): updater.cancel(), Vector2(105, 42))
	_button(title_row, "CLOSE", close_updater, Vector2(105, 42))
	_label(outer, "Manual GitHub updates · no automatic checks · Android confirms every installation.", 14, MUTED)
	update_status_label = _label(outer, "", 16, Color("ffd28a"))
	update_status_label.custom_minimum_size.y = 48
	update_progress_bar = _bar(outer, CYAN)
	update_progress_bar.custom_minimum_size.y = 14
	update_progress_label = _label(outer, "", 12, MUTED)
	update_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var notes_scroll := ScrollContainer.new()
	outer.add_child(notes_scroll)
	notes_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	update_notes_label = _label(notes_scroll, "", 14, MUTED)
	update_notes_label.custom_minimum_size.x = 710
	update_notes_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var actions := _hbox(outer, 10)
	update_check_button = _button(actions, "CHECK AGAIN", func(): updater.check_for_updates(), Vector2(150, 46))
	update_download_button = _button(actions, "DOWNLOAD UPDATE", func(): updater.download_update(), Vector2(180, 46))
	update_install_button = _button(actions, "INSTALL UPDATE", func(): updater.install_downloaded(), Vector2(170, 46))
	_button(actions, "RELEASES", func(): updater.open_releases(), Vector2(150, 46))
	_label(outer, "Keep the same signing key for future builds. Updating preserves app data; uninstalling can erase the local save.", 12, MUTED)
	_refresh_update_panel()

func open_updater() -> void:
	if state != "menu":
		return
	state = "updater"
	_hide_all_screens()
	update_screen.visible = true
	_refresh_update_panel()
	if not updater.is_busy() and not updater.has_update() and not updater.has_download():
		updater.check_for_updates()

func close_updater() -> void:
	if updater.is_busy():
		updater.cancel()
	show_menu()

func _refresh_update_panel() -> void:
	if update_status_label == null:
		return
	update_version_label.text = "INSTALLED v%s  ·  GITHUB RELEASES" % str(updater.current_version)
	update_status_label.text = str(updater.status)
	var available: bool = updater.has_update()
	var ready: bool = updater.has_download()
	var busy: bool = updater.is_busy()
	if available:
		var notes := str(updater.latest_release["notes"]).strip_edges()
		update_notes_label.text = "%s\n\n%s" % [str(updater.latest_release["title"]), notes if not notes.is_empty() else "No release notes were provided."]
	else:
		update_notes_label.text = "Check manually for a newer release. Gameplay never requires a connection, and no update is downloaded or installed without your action."
	update_check_button.disabled = busy
	update_download_button.disabled = busy or not available or ready
	update_download_button.text = "DOWNLOADED" if ready else "DOWNLOAD UPDATE"
	update_install_button.disabled = busy or not ready
	update_cancel_button.visible = busy
	if updater.operation == "check":
		update_progress_bar.max_value = 1.0
		update_progress_bar.value = 0.0
		update_progress_label.text = "Contacting GitHub…"

func _on_update_progress(received: int, total: int) -> void:
	if update_progress_bar == null:
		return
	update_progress_bar.max_value = maxf(float(total), 1.0)
	update_progress_bar.value = float(received)
	if total > 0:
		var percent := int(round(100.0 * float(received) / float(total)))
		update_progress_label.text = "%.1f / %.1f MB  ·  %d%%" % [float(received) / 1048576.0, float(total) / 1048576.0, percent]
	elif received > 0:
		update_progress_label.text = "%.1f MB downloaded" % (float(received) / 1048576.0)
	else:
		update_progress_label.text = ""

func show_menu() -> void:
	state = "menu"
	world.set_active(false)
	_hide_all_screens()
	menu_screen.visible = true
	continue_button.disabled = not SaveManager.has_save()

func _hide_all_screens() -> void:
	for screen in [menu_screen, hud, station_screen, map_screen, pause_screen, death_screen, update_screen]:
		screen.visible = false

func start_new_game() -> void:
	profile = Data.default_profile()
	world.setup(profile, false)
	_show_space()
	save_game()
	show_notice("Welcome, Capsuleer · select an asteroid and engage MINE")

func continue_game() -> void:
	var loaded := SaveManager.read_save()
	if loaded.is_empty():
		show_notice("No compatible local save found")
		return
	profile = Data.normalize_profile(loaded)
	world.setup(profile, true)
	_show_space()
	show_notice("Flight restored · " + str(Data.SYSTEMS[profile["current_system"]]["name"]))

func _show_space() -> void:
	state = "space"
	_hide_all_screens()
	hud.visible = true
	world.set_active(true)

func open_station() -> void:
	if state == "station":
		return
	state = "station"
	world.set_active(false)
	_hide_all_screens()
	station_screen.visible = true
	station_title.text = str(Data.SYSTEMS[world.system_id]["station"]).to_upper()
	station_subtitle.text = "%s  ·  Security %.1f  ·  %s" % [world.system["name"], float(world.system["security"]), str(Data.SHIPS[profile["ship"]]["name"])]
	show_station_page("overview")
	save_game()

func undock() -> void:
	world.player["pos"] = world.station_position + Vector2(330, 70)
	world.player["vel"] = Vector2.ZERO
	_show_space()
	show_notice("Undocked · fly safe")

func show_station_page(page: String) -> void:
	station_page = page
	for child in station_content.get_children():
		station_content.remove_child(child)
		child.queue_free()
	match page:
		"overview":
			_build_station_overview()
		"market":
			_build_station_market()
		"contracts":
			_build_station_contracts()
		"fitting":
			_build_station_fitting()

func _build_station_overview() -> void:
	_label(station_content, "COMMAND DECK", 20, CYAN)
	_label(station_content, str(world.system["description"]), 16, MUTED)
	_spacer(station_content, 4)
	_stat_row(station_content, "Credits", "%s CR" % _number(profile["credits"]), Color("ffd28a"))
	_stat_row(station_content, "Current ship", "%s · %s" % [Data.SHIPS[profile["ship"]]["name"], Data.SHIPS[profile["ship"]]["class"]])
	_stat_row(station_content, "Cargo", "%d / %d units" % [Data.cargo_used(profile), int(world.stats["cargo"])])
	_stat_row(station_content, "Lifetime", "%d pirates  ·  %d mined  ·  %s CR earned" % [profile["total_kills"], profile["total_mined"], _number(profile["total_earned"])])
	_spacer(station_content, 10)
	_label(station_content, "Station services repair your ship and replenish its capacitor automatically whenever you dock.", 15, MUTED)
	var row := _hbox(station_content, 10)
	_button(row, "SAVE FLIGHT", func(): save_game(); show_station_page("overview"), Vector2(180, 46))
	_button(row, "OPEN MARKET", func(): show_station_page("market"), Vector2(180, 46))
	_button(row, "BROWSE CONTRACTS", func(): show_station_page("contracts"), Vector2(220, 46))

func _build_station_market() -> void:
	_label(station_content, "REGIONAL MARKET", 20, CYAN)
	_label(station_content, "Prices vary by system. Buy low, transport cargo through the gate network, and sell where demand is higher.", 14, MUTED)
	var header := _hbox(station_content, 12)
	_fixed_label(header, "RESOURCE", 190, 12, MUTED)
	_fixed_label(header, "HOLD", 60, 12, MUTED)
	_fixed_label(header, "BUY", 90, 12, MUTED)
	_fixed_label(header, "SELL", 90, 12, MUTED)
	_fixed_label(header, "ACQUIRE", 112, 12, MUTED)
	_fixed_label(header, "LIQUIDATE", 122, 12, MUTED)
	for resource_id in Data.RESOURCES:
		var resource: Dictionary = Data.RESOURCES[resource_id]
		var prices := Data.market_prices(world.system_id, resource_id)
		var row := _hbox(station_content, 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fixed_label(row, str(resource["name"]), 190, 17, Color(str(resource["color"])))
		_fixed_label(row, str(profile["cargo"][resource_id]), 60, 17)
		_fixed_label(row, "%d CR" % prices["buy"], 90, 16)
		_fixed_label(row, "%d CR" % prices["sell"], 90, 16)
		_button(row, "BUY 1", func(): buy_resource(resource_id), Vector2(112, 38))
		_button(row, "SELL ALL", func(): sell_resource(resource_id), Vector2(122, 38))
	_spacer(station_content, 8)
	_label(station_content, "Wallet: %s CR    ·    Cargo: %d/%d" % [_number(profile["credits"]), Data.cargo_used(profile), int(world.stats["cargo"])], 17, Color("ffd28a"))

func buy_resource(resource_id: String) -> void:
	var price := int(Data.market_prices(world.system_id, resource_id)["buy"])
	if int(profile["credits"]) < price:
		show_notice("Insufficient credits")
		return
	if world.cargo_free() < 1:
		show_notice("Cargo hold full")
		return
	profile["credits"] -= price
	world.add_cargo(resource_id, 1)
	save_game()
	show_station_page("market")

func sell_resource(resource_id: String) -> void:
	var amount := int(profile["cargo"][resource_id])
	if amount <= 0:
		show_notice("No %s in cargo" % str(Data.RESOURCES[resource_id]["name"]))
		return
	var price := int(Data.market_prices(world.system_id, resource_id)["sell"])
	var revenue := amount * price
	world.remove_cargo(resource_id, amount)
	profile["credits"] += revenue
	profile["total_earned"] = int(profile["total_earned"]) + revenue
	save_game()
	show_notice("Sold %d units · +%s CR" % [amount, _number(revenue)])
	show_station_page("market")

func _build_station_contracts() -> void:
	_label(station_content, "CONTRACT BOARD", 20, CYAN)
	_label(station_content, "Contracts are local, offline objectives. Completion must be claimed while docked.", 14, MUTED)
	for contract_id in Data.CONTRACTS:
		var definition: Dictionary = Data.CONTRACTS[contract_id]
		var progress: Dictionary = profile["contracts"][contract_id]
		var panel := PanelContainer.new()
		station_content.add_child(panel)
		panel.theme = theme
		var row := _hbox(_margin(panel, 12), 16)
		var text_box := _vbox(row, 5)
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(text_box, str(definition["name"]), 19)
		_label(text_box, str(definition["description"]), 14, MUTED)
		_label(text_box, "Reward · %s CR" % _number(definition["reward"]), 15, Color("ffd28a"))
		var status := "AVAILABLE"
		var button_text := "ACCEPT"
		if progress["completed"]:
			status = "COMPLETED"
			button_text = "CLAIMED"
		elif progress["accepted"]:
			if definition["type"] == "bounty":
				status = "Progress · %d/%d" % [progress["progress"], definition["target"]]
			else:
				status = "Cargo · %d/%d" % [profile["cargo"][definition["resource"]], definition["target"]]
			button_text = "CLAIM"
		_label(text_box, status, 13, CYAN)
		var action := _button(row, button_text, func(): contract_action(contract_id), Vector2(130, 48))
		action.disabled = bool(progress["completed"])

func contract_action(contract_id: String) -> void:
	var definition: Dictionary = Data.CONTRACTS[contract_id]
	var progress: Dictionary = profile["contracts"][contract_id]
	if progress["completed"]:
		return
	if not progress["accepted"]:
		progress["accepted"] = true
		show_notice("Contract accepted · " + str(definition["name"]))
		save_game()
		show_station_page("contracts")
		return
	var ready := false
	if definition["type"] == "bounty":
		ready = int(progress["progress"]) >= int(definition["target"])
	else:
		ready = int(profile["cargo"][definition["resource"]]) >= int(definition["target"])
		if definition.has("destination") and str(definition["destination"]) != world.system_id:
			ready = false
	if not ready:
		show_notice("Contract requirements are not yet complete")
		return
	if definition["type"] == "delivery":
		world.remove_cargo(str(definition["resource"]), int(definition["target"]))
	profile["credits"] += int(definition["reward"])
	profile["total_earned"] = int(profile["total_earned"]) + int(definition["reward"])
	progress["completed"] = true
	progress["accepted"] = false
	save_game()
	show_notice("Contract complete · +%s CR" % _number(definition["reward"]))
	show_station_page("contracts")

func _build_station_fitting() -> void:
	_label(station_content, "SHIP FITTING", 20, CYAN)
	var ship: Dictionary = Data.SHIPS[profile["ship"]]
	_label(station_content, "%s · %s" % [ship["name"], ship["class"]], 18)
	_label(station_content, "Laser %.1f  ·  Shield %d  ·  Armor %d  ·  Hull %d  ·  Cargo %d  ·  Velocity %d" % [world.stats["damage"], int(world.stats["shield"]), int(world.stats["armor"]), int(world.stats["hull"]), int(world.stats["cargo"]), int(world.stats["speed"])], 14, MUTED)
	_spacer(station_content, 4)
	for upgrade_id in ["laser", "shield", "engine", "cargo"]:
		var level := int(profile["upgrades"][upgrade_id])
		var cost := Data.upgrade_cost(upgrade_id, level)
		var panel := PanelContainer.new()
		station_content.add_child(panel)
		panel.theme = theme
		var row := _hbox(_margin(panel, 10), 14)
		var text_box := _vbox(row, 3)
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(text_box, "%s  ·  Rank %d/3" % [Data.upgrade_name(upgrade_id), level], 17)
		_label(text_box, Data.upgrade_description(upgrade_id), 13, MUTED)
		var button := _button(row, "MAXIMUM" if level >= 3 else "%s CR" % _number(cost), func(): purchase_upgrade(upgrade_id), Vector2(145, 44))
		button.disabled = level >= 3
	_spacer(station_content, 6)
	if str(profile["ship"]) != "kestrel":
		var panel := PanelContainer.new()
		station_content.add_child(panel)
		panel.theme = theme
		var row := _hbox(_margin(panel, 12), 16)
		var text_box := _vbox(row, 4)
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(text_box, "VF-7 Kestrel · Assault Destroyer", 19, Color("ffd28a"))
		_label(text_box, "A substantial combat and cargo upgrade. Purchase includes immediate fitting, repair and registration.", 14, MUTED)
		_button(row, "4,800 CR", purchase_kestrel, Vector2(150, 48))
	else:
		_label(station_content, "VF-7 Kestrel installed · your current hull is the highest available in First Light.", 15, Color("ffd28a"))

func purchase_upgrade(upgrade_id: String) -> void:
	var level := int(profile["upgrades"][upgrade_id])
	if level >= 3:
		return
	var cost := Data.upgrade_cost(upgrade_id, level)
	if int(profile["credits"]) < cost:
		show_notice("Insufficient credits")
		return
	profile["credits"] -= cost
	profile["upgrades"][upgrade_id] = level + 1
	world.apply_upgrades()
	world.repair_and_recharge()
	save_game()
	show_notice("%s upgraded to rank %d" % [Data.upgrade_name(upgrade_id), level + 1])
	show_station_page("fitting")

func purchase_kestrel() -> void:
	var cost := int(Data.SHIPS["kestrel"]["cost"])
	if int(profile["credits"]) < cost:
		show_notice("Insufficient credits for the Kestrel")
		return
	profile["credits"] -= cost
	profile["ship"] = "kestrel"
	world.apply_upgrades()
	world.repair_and_recharge()
	save_game()
	show_notice("VF-7 Kestrel registered and ready")
	open_station()

func open_map() -> void:
	if state != "space":
		return
	state = "map"
	world.set_active(false)
	map_screen.visible = true
	map_subtitle.text = "%s  ·  Jump gate %.0f m" % [world.system["name"], world.gate_distance()]
	for child in map_list.get_children():
		map_list.remove_child(child)
		child.queue_free()
	for id in Data.SYSTEMS:
		var info: Dictionary = Data.SYSTEMS[id]
		var panel := PanelContainer.new()
		map_list.add_child(panel)
		panel.theme = theme
		var row := _hbox(_margin(panel, 10), 14)
		var text_box := _vbox(row, 3)
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(text_box, "%s  ·  SEC %.1f" % [info["name"], info["security"]], 18, Color(str(info["accent"])))
		_label(text_box, str(info["description"]), 13, MUTED)
		if id == world.system_id:
			var button := _button(row, "CURRENT", func(): pass, Vector2(150, 44))
			button.disabled = true
		elif world.system["connections"].has(id):
			_button(row, "PLOT COURSE", func(): plot_route(id), Vector2(150, 44))
		else:
			var button := _button(row, "NO DIRECT GATE", func(): pass, Vector2(150, 44))
			button.disabled = true

func plot_route(destination: String) -> void:
	if world.plot_course(destination):
		close_map()

func close_map() -> void:
	if state != "map":
		return
	map_screen.visible = false
	state = "space"
	world.set_active(true)

func open_pause() -> void:
	if state != "space":
		return
	state = "pause"
	world.set_active(false)
	pause_screen.visible = true

func close_pause() -> void:
	if state != "pause":
		return
	pause_screen.visible = false
	state = "space"
	world.set_active(true)

func open_death() -> void:
	state = "death"
	world.set_active(false)
	death_screen.visible = true
	var fee := mini(250, int(float(profile["credits"]) * 0.10))
	death_detail.text = "Your rescue capsule has been recovered. Cargo was lost. Insurance recovery costs %d CR; your hull and fittings will be restored at %s." % [fee, world.system["station"]]

func recover_ship() -> void:
	var fee := mini(250, int(float(profile["credits"]) * 0.10))
	profile["credits"] = maxi(0, int(profile["credits"]) - fee)
	for resource_id in profile["cargo"]:
		profile["cargo"][resource_id] = 0
	world.respawn_at_station()
	save_game()
	open_station()

func save_game() -> bool:
	if profile.is_empty():
		return false
	world.update_saved_state()
	return SaveManager.write_save(profile)

func show_notice(text: String) -> void:
	if notice_label == null:
		return
	notice_label.text = text
	notice_label.visible = true
	if station_notice != null:
		station_notice.text = text
		station_notice.visible = true
	notice_timer = 4.5

func show_flight_manual() -> void:
	var manual := _overlay("FlightManual")
	var panel := _center_panel(manual, 720, 580)
	var box := _vbox(_margin(panel, 24), 12)
	_label(box, "FLIGHT MANUAL", 29, CYAN)
	_label(box, "TOUCH", 16, Color("ffd28a"))
	_label(box, "Drag the left stick to thrust. Tap a ship or asteroid to target it. Use ORBIT to approach and circle the target; FIRE and MINE activate your equipment. DOCK plots an approach when you are far from the station.", 15, MUTED)
	_label(box, "KEYBOARD", 16, Color("ffd28a"))
	_label(box, "WASD / arrows: thrust  ·  Space: fire  ·  Tab: cycle target  ·  M: mining  ·  O: orbit  ·  F: dock  ·  G: galaxy map  ·  Esc: pause / back", 15, MUTED)
	_label(box, "YOUR FIRST FLIGHT", 16, Color("ffd28a"))
	_label(box, "Mine Ferrite Ore, recover salvage from pirates, then dock to sell cargo. Accept contracts for larger payouts. Upgrade the Wisp or save for the Kestrel. Higher-risk systems offer better market prices and richer crystal fields.", 15, MUTED)
	_label(box, "Travel by opening MAP, plotting a connected system, and letting autopilot carry you to the jump gate. Any manual movement cancels autopilot.", 15, MUTED)
	_button(box, "CLOSE", func(): manual.queue_free(), Vector2(0, 48))

func _process(delta: float) -> void:
	notice_timer -= delta
	if notice_timer <= 0.0 and notice_label != null:
		notice_label.visible = false
		if station_notice != null:
			station_notice.visible = false
	hud_timer -= delta
	if hud_timer <= 0.0:
		hud_timer = 0.10
		_update_hud()

func _update_hud() -> void:
	if profile.is_empty() or world.player.is_empty() or system_label == null:
		return
	system_label.text = str(world.system["name"]).to_upper()
	security_label.text = "SEC %.1f" % float(world.system["security"])
	security_label.add_theme_color_override("font_color", Color("79e5b7") if float(world.system["security"]) >= 0.5 else Color("ff9a78"))
	credits_label.text = "%s CR" % _number(profile["credits"])
	cargo_label.text = "CARGO %d/%d" % [Data.cargo_used(profile), int(world.stats["cargo"])]
	var player: Dictionary = world.player
	shield_bar.max_value = world.stats["shield"]
	shield_bar.value = player["shield"]
	armor_bar.max_value = world.stats["armor"]
	armor_bar.value = player["armor"]
	hull_bar.max_value = world.stats["hull"]
	hull_bar.value = player["hull"]
	energy_bar.max_value = world.stats["energy"]
	energy_bar.value = player["energy"]
	condition_label.text = "SHD %d  ·  ARM %d  ·  HUL %d  ·  CAP %d" % [player["shield"], player["armor"], player["hull"], player["energy"]]
	var target: Dictionary = world.get_target()
	if target.is_empty():
		target_title.text = "NO TARGET"
		target_detail.text = "Tap a ship or asteroid · TAB to cycle"
		target_bar.value = 0
	else:
		target_title.text = str(target["name"]) if world.target_kind == "enemy" else str(Data.RESOURCES[target["resource"]]["name"])
		target_detail.text = "%s  ·  %.0f m" % [world.target_kind.to_upper(), world.target_distance()]
		if world.target_kind == "enemy":
			target_bar.max_value = float(target["max_shield"]) + float(target["max_hull"])
			target_bar.value = maxf(0.0, float(target["shield"]) + float(target["hull"]))
		else:
			target_bar.max_value = target["max_amount"]
			target_bar.value = target["amount"]
	fire_button.text = "FIRING" if world.firing else "FIRE"
	mine_button.text = "MINING" if world.mining else "MINE"
	orbit_button.text = "ORBITING" if world.auto_orbit else "ORBIT"
	dock_button.text = "DOCK READY" if world.station_distance() <= 285.0 else "DOCK"
	if int(profile["total_mined"]) < 10:
		hint_label.text = "FLIGHT TIP  ·  Select an asteroid and engage MINE. Stay within 265 m."
	elif int(profile["total_kills"]) < 1:
		hint_label.text = "FLIGHT TIP  ·  Target a pirate, engage ORBIT, then FIRE."
	else:
		hint_label.text = "DOCK to sell cargo and refit  ·  MAP to travel  ·  Esc for help"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		_handle_back()
	elif state == "space":
		if event.is_action_pressed("mine"):
			world.toggle_mine()
		elif event.is_action_pressed("orbit"):
			world.toggle_orbit()
		elif event.is_action_pressed("dock"):
			world.request_dock()
		elif event.is_action_pressed("target"):
			world.cycle_target()
		elif event.is_action_pressed("galaxy_map"):
			open_map()

func _handle_back() -> void:
	match state:
		"space":
			open_pause()
		"map":
			close_map()
		"pause":
			close_pause()
		"station":
			undock()
		"death":
			show_menu()
		"updater":
			close_updater()
		"menu":
			get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()

func _number(value) -> String:
	var number := int(value)
	var text := str(absi(number))
	var result := ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	result = text + result
	return ("-" if number < 0 else "") + result
