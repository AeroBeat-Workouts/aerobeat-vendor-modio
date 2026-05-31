extends Control

const AeroModIOManager = preload("res://addons/aerobeat-vendor-modio/src/AeroModIOManager.gd")
const ModioClientConfig = preload("res://addons/aerobeat-vendor-modio/src/models/modio_client_config.gd")
const ModioListingQuery = preload("res://addons/aerobeat-vendor-modio/src/models/modio_listing_query.gd")
const ModioEnvLoader = preload("res://scripts/modio_env_loader.gd")
const ModioSessionConfigStore = preload("res://scripts/modio_session_config_store.gd")
const ModioWorkoutBrowserState = preload("res://scripts/modio_workout_browser_state.gd")

const TAB_PUBLIC_INDEX := 0
const TAB_PROFILE_INDEX := 1
const TAB_WORKOUT_INDEX := 2
const TAB_SUBSCRIBED_INDEX := 3
const CARD_PREVIEW_SIZE := Vector2i(320, 180)
const IMAGE_CACHE_DIR := "user://modio_workout_browser_images"
const SORT_OPTIONS := [
	{"label": "Recently Updated", "value": "-date_updated"},
	{"label": "Newest", "value": "-date_live"},
	{"label": "Most Popular", "value": "-popular"},
	{"label": "Most Downloaded", "value": "-downloads_total"},
	{"label": "Alphabetical", "value": "name"}
]

var _loader := ModioEnvLoader.new()
var _store := ModioSessionConfigStore.new()
var _state := ModioWorkoutBrowserState.new()
var _manager: AeroModIOManager
var _base_config: ModioClientConfig
var _image_cache: Dictionary = {}
var _ui_built: bool = false

var _status_label: Label
var _server_option_button: OptionButton
var _game_id_line_edit: LineEdit
var _api_key_line_edit: LineEdit
var _storage_disclosure_label: Label
var _email_line_edit: LineEdit
var _request_code_button: Button
var _security_code_line_edit: LineEdit
var _exchange_code_button: Button
var _clear_session_button: Button
var _auth_state_label: Label
var _tab_container: TabContainer
var _profile_summary_label: RichTextLabel
var _profile_raw_toggle: CheckBox
var _profile_raw_text: TextEdit
var _profile_refresh_button: Button
var _public_search_line_edit: LineEdit
var _public_sort_option_button: OptionButton
var _public_tags_line_edit: LineEdit
var _public_exclude_tags_line_edit: LineEdit
var _public_fetch_button: Button
var _public_prev_button: Button
var _public_next_button: Button
var _public_page_label: Label
var _public_cards_grid: GridContainer
var _public_empty_label: Label
var _workout_search_line_edit: LineEdit
var _workout_sort_option_button: OptionButton
var _workout_tags_line_edit: LineEdit
var _workout_exclude_tags_line_edit: LineEdit
var _workout_fetch_button: Button
var _workout_prev_button: Button
var _workout_next_button: Button
var _workout_page_label: Label
var _workout_cards_grid: GridContainer
var _workout_empty_label: Label
var _subscribed_search_line_edit: LineEdit
var _subscribed_sort_option_button: OptionButton
var _subscribed_tags_line_edit: LineEdit
var _subscribed_exclude_tags_line_edit: LineEdit
var _subscribed_fetch_button: Button
var _subscribed_prev_button: Button
var _subscribed_next_button: Button
var _subscribed_page_label: Label
var _subscribed_cards_grid: GridContainer
var _subscribed_empty_label: Label
var _detail_overlay: ColorRect
var _detail_panel: PanelContainer
var _detail_title_label: Label
var _detail_image: TextureRect
var _detail_summary_label: RichTextLabel
var _detail_close_button: Button
var _detail_action_button: Button
var _detail_status_label: Label

func _ready() -> void:
	name = "WorkoutBrowserTestbed"
	_ensure_ui_built()
	_load_initial_state()
	_refresh_all_ui()

func describe_scene_surface() -> Dictionary:
	_ensure_ui_built()
	return {
		"group_id": "workout_browser",
		"description": "Default operator-facing mod.io workout browser scene with editable server credentials, email-code auth, profile summary, public browsing, athlete browsing, and subscribed workout management.",
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"has_connection_controls": is_instance_valid(_server_option_button) and is_instance_valid(_game_id_line_edit) and is_instance_valid(_api_key_line_edit),
		"has_auth_controls": is_instance_valid(_email_line_edit) and is_instance_valid(_security_code_line_edit),
		"has_tab_container": is_instance_valid(_tab_container),
		"has_detail_overlay": is_instance_valid(_detail_overlay),
		"has_output": true,
		"has_run_button": false
	}

func _ensure_ui_built() -> void:
	if _ui_built:
		return
	_build_ui()
	_ui_built = true

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "VBoxContainer"
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Workout Browser"
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)

	root.add_child(_build_connection_panel())
	root.add_child(_build_auth_panel())

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	_tab_container = TabContainer.new()
	_tab_container.name = "TabContainer"
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.tab_changed.connect(_on_tab_changed)
	root.add_child(_tab_container)

	_tab_container.add_child(_build_public_tab())
	_tab_container.set_tab_title(TAB_PUBLIC_INDEX, "Public Catalog")
	_tab_container.add_child(_build_profile_tab())
	_tab_container.set_tab_title(TAB_PROFILE_INDEX, "Profile")
	_tab_container.add_child(_build_workout_tab())
	_tab_container.set_tab_title(TAB_WORKOUT_INDEX, "Workout Browser")
	_tab_container.add_child(_build_subscribed_tab())
	_tab_container.set_tab_title(TAB_SUBSCRIBED_INDEX, "Subscribed Workouts")

	_detail_overlay = _build_detail_overlay()
	add_child(_detail_overlay)

func _build_connection_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ConnectionPanel"
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)

	var heading := Label.new()
	heading.text = "Connection Controls"
	heading.add_theme_font_size_override("font_size", 18)
	inner.add_child(heading)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inner.add_child(row)

	var server_box := VBoxContainer.new()
	server_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(server_box)
	server_box.add_child(_field_label("Server"))
	_server_option_button = OptionButton.new()
	_server_option_button.name = "ServerOptionButton"
	_server_option_button.add_item("Test")
	_server_option_button.add_item("Live")
	_server_option_button.item_selected.connect(_on_connection_field_changed)
	server_box.add_child(_server_option_button)

	var game_box := VBoxContainer.new()
	game_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(game_box)
	game_box.add_child(_field_label("Game ID"))
	_game_id_line_edit = LineEdit.new()
	_game_id_line_edit.name = "GameIdLineEdit"
	_game_id_line_edit.placeholder_text = "1325"
	_game_id_line_edit.text_submitted.connect(_on_apply_connection_pressed)
	_game_id_line_edit.text_changed.connect(_on_connection_text_changed)
	game_box.add_child(_game_id_line_edit)

	var api_box := VBoxContainer.new()
	api_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(api_box)
	api_box.add_child(_field_label("API Key"))
	_api_key_line_edit = LineEdit.new()
	_api_key_line_edit.name = "ApiKeyLineEdit"
	_api_key_line_edit.placeholder_text = "mod.io API key"
	_api_key_line_edit.secret = false
	_api_key_line_edit.text_submitted.connect(_on_apply_connection_pressed)
	_api_key_line_edit.text_changed.connect(_on_connection_text_changed)
	api_box.add_child(_api_key_line_edit)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	inner.add_child(button_row)

	var apply_button := Button.new()
	apply_button.name = "ApplyConnectionButton"
	apply_button.text = "Apply & Refresh Public"
	apply_button.pressed.connect(_on_apply_connection_pressed)
	button_row.add_child(apply_button)

	var reload_button := Button.new()
	reload_button.name = "ReloadDefaultsButton"
	reload_button.text = "Reload Saved Defaults"
	reload_button.pressed.connect(_on_reload_defaults_pressed)
	button_row.add_child(reload_button)

	_storage_disclosure_label = Label.new()
	_storage_disclosure_label.name = "StorageDisclosureLabel"
	_storage_disclosure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_storage_disclosure_label)

	return panel

func _build_auth_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "AuthPanel"
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)

	var heading := Label.new()
	heading.text = "Athlete Auth"
	heading.add_theme_font_size_override("font_size", 18)
	inner.add_child(heading)

	var description := Label.new()
	description.text = "Real mod.io athlete auth uses emailrequest → emailexchange. No username/password façade here."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(description)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inner.add_child(row)

	var email_box := VBoxContainer.new()
	email_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(email_box)
	email_box.add_child(_field_label("Email"))
	_email_line_edit = LineEdit.new()
	_email_line_edit.name = "EmailLineEdit"
	_email_line_edit.placeholder_text = "athlete@example.com"
	email_box.add_child(_email_line_edit)

	_request_code_button = Button.new()
	_request_code_button.name = "RequestCodeButton"
	_request_code_button.text = "Request Code"
	_request_code_button.pressed.connect(_on_request_code_pressed)
	row.add_child(_request_code_button)

	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	inner.add_child(code_row)

	var code_box := VBoxContainer.new()
	code_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_row.add_child(code_box)
	code_box.add_child(_field_label("Security Code"))
	_security_code_line_edit = LineEdit.new()
	_security_code_line_edit.name = "SecurityCodeLineEdit"
	_security_code_line_edit.placeholder_text = "Paste the emailed code"
	_security_code_line_edit.text_submitted.connect(_on_exchange_code_pressed)
	code_box.add_child(_security_code_line_edit)

	_exchange_code_button = Button.new()
	_exchange_code_button.name = "ExchangeCodeButton"
	_exchange_code_button.text = "Exchange Code"
	_exchange_code_button.pressed.connect(_on_exchange_code_pressed)
	code_row.add_child(_exchange_code_button)

	_clear_session_button = Button.new()
	_clear_session_button.name = "ClearSessionButton"
	_clear_session_button.text = "Clear Saved Session"
	_clear_session_button.pressed.connect(_on_clear_session_pressed)
	code_row.add_child(_clear_session_button)

	_auth_state_label = Label.new()
	_auth_state_label.name = "AuthStateLabel"
	_auth_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_auth_state_label)

	return panel

func _build_public_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "PublicCatalogTab"
	tab.add_theme_constant_override("separation", 8)
	tab.add_child(_listing_controls(
		"PublicBrowserControls",
		func() -> void:
			_fetch_listing(ModioWorkoutBrowserState.TAB_PUBLIC),
		func(direction: int) -> void:
			_shift_page(ModioWorkoutBrowserState.TAB_PUBLIC, direction),
		func(search: LineEdit, sort_button: OptionButton, tags: LineEdit, tags_not: LineEdit, fetch: Button, prev: Button, next: Button, page: Label) -> void:
			_public_search_line_edit = search
			_public_sort_option_button = sort_button
			_public_tags_line_edit = tags
			_public_exclude_tags_line_edit = tags_not
			_public_fetch_button = fetch
			_public_prev_button = prev
			_public_next_button = next
			_public_page_label = page
	))
	var browser := _listing_browser("PublicCardsGrid", "PublicEmptyLabel")
	_public_cards_grid = browser.grid
	_public_empty_label = browser.empty_label
	tab.add_child(browser.root)
	return tab

func _build_profile_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "ProfileTab"
	tab.add_theme_constant_override("separation", 8)

	_profile_refresh_button = Button.new()
	_profile_refresh_button.name = "ProfileRefreshButton"
	_profile_refresh_button.text = "Refresh Profile / Wallet / Purchases"
	_profile_refresh_button.pressed.connect(_on_profile_refresh_pressed)
	tab.add_child(_profile_refresh_button)

	_profile_summary_label = RichTextLabel.new()
	_profile_summary_label.name = "ProfileSummaryLabel"
	_profile_summary_label.fit_content = true
	_profile_summary_label.bbcode_enabled = true
	_profile_summary_label.scroll_active = false
	tab.add_child(_profile_summary_label)

	_profile_raw_toggle = CheckBox.new()
	_profile_raw_toggle.name = "ProfileRawToggle"
	_profile_raw_toggle.text = "Show raw/debug payloads"
	_profile_raw_toggle.toggled.connect(func(pressed: bool) -> void:
		_profile_raw_text.visible = pressed
	)
	tab.add_child(_profile_raw_toggle)

	_profile_raw_text = TextEdit.new()
	_profile_raw_text.name = "ProfileRawText"
	_profile_raw_text.custom_minimum_size = Vector2(0, 280)
	_profile_raw_text.editable = false
	_profile_raw_text.visible = false
	tab.add_child(_profile_raw_text)

	return tab

func _build_workout_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "WorkoutBrowserTab"
	tab.add_theme_constant_override("separation", 8)
	tab.add_child(_listing_controls(
		"WorkoutBrowserControls",
		func() -> void:
			_fetch_listing(ModioWorkoutBrowserState.TAB_WORKOUT),
		func(direction: int) -> void:
			_shift_page(ModioWorkoutBrowserState.TAB_WORKOUT, direction),
		func(search: LineEdit, sort_button: OptionButton, tags: LineEdit, tags_not: LineEdit, fetch: Button, prev: Button, next: Button, page: Label) -> void:
			_workout_search_line_edit = search
			_workout_sort_option_button = sort_button
			_workout_tags_line_edit = tags
			_workout_exclude_tags_line_edit = tags_not
			_workout_fetch_button = fetch
			_workout_prev_button = prev
			_workout_next_button = next
			_workout_page_label = page
	))
	var browser := _listing_browser("WorkoutCardsGrid", "WorkoutEmptyLabel")
	_workout_cards_grid = browser.grid
	_workout_empty_label = browser.empty_label
	tab.add_child(browser.root)
	return tab

func _build_subscribed_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "SubscribedWorkoutsTab"
	tab.add_theme_constant_override("separation", 8)
	tab.add_child(_listing_controls(
		"SubscribedBrowserControls",
		func() -> void:
			_fetch_listing(ModioWorkoutBrowserState.TAB_SUBSCRIBED),
		func(direction: int) -> void:
			_shift_page(ModioWorkoutBrowserState.TAB_SUBSCRIBED, direction),
		func(search: LineEdit, sort_button: OptionButton, tags: LineEdit, tags_not: LineEdit, fetch: Button, prev: Button, next: Button, page: Label) -> void:
			_subscribed_search_line_edit = search
			_subscribed_sort_option_button = sort_button
			_subscribed_tags_line_edit = tags
			_subscribed_exclude_tags_line_edit = tags_not
			_subscribed_fetch_button = fetch
			_subscribed_prev_button = prev
			_subscribed_next_button = next
			_subscribed_page_label = page
	))
	var browser := _listing_browser("SubscribedCardsGrid", "SubscribedEmptyLabel")
	_subscribed_cards_grid = browser.grid
	_subscribed_empty_label = browser.empty_label
	tab.add_child(browser.root)
	return tab

func _listing_controls(name: String, on_fetch: Callable, on_page_shift: Callable, assign_fields: Callable) -> Control:
	var panel := PanelContainer.new()
	panel.name = name
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inner.add_child(row)

	var search := LineEdit.new()
	search.name = "%sSearchLineEdit" % name
	search.placeholder_text = "Search workouts"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_submitted.connect(func(_text: String) -> void:
		on_fetch.call()
	)
	row.add_child(search)

	var sort_button := OptionButton.new()
	sort_button.name = "%sSortOptionButton" % name
	for option in SORT_OPTIONS:
		sort_button.add_item(option.label)
	row.add_child(sort_button)

	var tags := LineEdit.new()
	tags.name = "%sTagsLineEdit" % name
	tags.placeholder_text = "tags (comma-separated, all)"
	tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tags)

	var tags_not := LineEdit.new()
	tags_not.name = "%sExcludeTagsLineEdit" % name
	tags_not.placeholder_text = "exclude tags"
	tags_not.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tags_not)

	var fetch_button := Button.new()
	fetch_button.name = "%sFetchButton" % name
	fetch_button.text = "Fetch"
	fetch_button.pressed.connect(func() -> void:
		on_fetch.call()
	)
	row.add_child(fetch_button)

	var pagination := HBoxContainer.new()
	pagination.add_theme_constant_override("separation", 8)
	inner.add_child(pagination)

	var prev_button := Button.new()
	prev_button.name = "%sPrevButton" % name
	prev_button.text = "Previous"
	prev_button.pressed.connect(func() -> void:
		on_page_shift.call(-1)
	)
	pagination.add_child(prev_button)

	var page_label := Label.new()
	page_label.name = "%sPageLabel" % name
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pagination.add_child(page_label)

	var next_button := Button.new()
	next_button.name = "%sNextButton" % name
	next_button.text = "Next"
	next_button.pressed.connect(func() -> void:
		on_page_shift.call(1)
	)
	pagination.add_child(next_button)

	assign_fields.call(search, sort_button, tags, tags_not, fetch_button, prev_button, next_button, page_label)
	return panel

func _listing_browser(grid_name: String, empty_name: String) -> Dictionary:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = grid_name
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	var empty := Label.new()
	empty.name = empty_name
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(empty)

	return {
		"root": root,
		"grid": grid,
		"empty_label": empty
	}

func _build_detail_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = "DetailOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.visible = false

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	overlay.add_child(center)

	_detail_panel = PanelContainer.new()
	_detail_panel.name = "DetailPanel"
	_detail_panel.custom_minimum_size = Vector2(820, 560)
	center.add_child(_detail_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_detail_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	_detail_title_label = Label.new()
	_detail_title_label.name = "DetailTitleLabel"
	_detail_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_detail_title_label)

	_detail_close_button = Button.new()
	_detail_close_button.name = "DetailCloseButton"
	_detail_close_button.text = "X"
	_detail_close_button.pressed.connect(_close_detail_overlay)
	header.add_child(_detail_close_button)

	_detail_image = TextureRect.new()
	_detail_image.name = "DetailImage"
	_detail_image.custom_minimum_size = Vector2(640, 240)
	_detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(_detail_image)

	_detail_summary_label = RichTextLabel.new()
	_detail_summary_label.name = "DetailSummaryLabel"
	_detail_summary_label.bbcode_enabled = true
	_detail_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_detail_summary_label)

	_detail_status_label = Label.new()
	_detail_status_label.name = "DetailStatusLabel"
	_detail_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_detail_status_label)

	var footer := HBoxContainer.new()
	root.add_child(footer)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_detail_action_button = Button.new()
	_detail_action_button.name = "DetailActionButton"
	_detail_action_button.visible = false
	_detail_action_button.pressed.connect(_on_detail_action_pressed)
	footer.add_child(_detail_action_button)
	return overlay

func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _load_initial_state() -> void:
	var explicit_env := _store.read_environment()
	var resolved_env := _loader.resolve_environment(explicit_env)
	_base_config = _loader.build_client_config(resolved_env)
	_state.environment = resolved_env
	_state.game_id = _base_config.game_id
	_state.api_key = _base_config.api_key
	_state.access_token = _base_config.access_token
	_state.user_id = _base_config.user_id
	_state.status_text = "Public browsing works with Game ID + API Key. Athlete-only tabs unlock after email-code auth."
	_rebuild_manager()

func _rebuild_manager() -> void:
	var portal := _base_config.portal if _base_config != null else ""
	var platform := _base_config.platform if _base_config != null else ""
	var service_token := _base_config.service_token if _base_config != null else ""
	var monetization_team_id := _base_config.monetization_team_id if _base_config != null else ""
	var owned_mod_id := _base_config.owned_mod_id if _base_config != null else ""
	var paid_mod_id := _base_config.paid_mod_id if _base_config != null else ""
	var accept_language := _base_config.accept_language if _base_config != null else ModioClientConfig.DEFAULT_ACCEPT_LANGUAGE
	_manager = AeroModIOManager.new(ModioClientConfig.new(
		_state.game_id,
		_state.api_key,
		"",
		_state.access_token,
		accept_language,
		portal,
		platform,
		ModioClientConfig.HOST_GAME,
		_state.user_id,
		_state.environment == ModioEnvLoader.ENV_TEST,
		service_token,
		monetization_team_id,
		owned_mod_id,
		paid_mod_id
	))

func _refresh_all_ui() -> void:
	_server_option_button.select(0 if _state.environment == ModioEnvLoader.ENV_TEST else 1)
	_game_id_line_edit.text = _state.game_id
	_api_key_line_edit.text = _state.api_key
	_storage_disclosure_label.text = "Game ID + API key are read from %s. Auth/session values are read from and written back to %s." % [ModioEnvLoader.CONFIG_STABLE_PATH, _store.get_storage_path()]
	_email_line_edit.text = _state.email
	_auth_state_label.text = _build_auth_state_text()
	_status_label.text = _state.status_text
	_update_profile_ui()
	_sync_query_controls(ModioWorkoutBrowserState.TAB_PUBLIC)
	_sync_query_controls(ModioWorkoutBrowserState.TAB_WORKOUT)
	_sync_query_controls(ModioWorkoutBrowserState.TAB_SUBSCRIBED)
	_update_listing_ui(ModioWorkoutBrowserState.TAB_PUBLIC)
	_update_listing_ui(ModioWorkoutBrowserState.TAB_WORKOUT)
	_update_listing_ui(ModioWorkoutBrowserState.TAB_SUBSCRIBED)
	_tab_container.set_tab_disabled(TAB_PROFILE_INDEX, not _state.is_authenticated())
	_tab_container.set_tab_disabled(TAB_WORKOUT_INDEX, not _state.is_authenticated())
	_tab_container.set_tab_disabled(TAB_SUBSCRIBED_INDEX, not _state.is_authenticated())
	if not _state.is_authenticated() and _tab_container.current_tab != TAB_PUBLIC_INDEX:
		_tab_container.current_tab = TAB_PUBLIC_INDEX

func _build_auth_state_text() -> String:
	var lines := PackedStringArray()
	lines.append("Server: %s" % _state.environment.capitalize())
	lines.append("Session path: %s" % _store.get_storage_path())
	if _state.is_authenticated():
		lines.append("Access token loaded: yes")
		lines.append("User ID: %s" % (_state.user_id if not _state.user_id.is_empty() else "(will refresh from /me)"))
	else:
		lines.append("Access token loaded: no")
	return "\n".join(lines)

func _sync_query_controls(context: String) -> void:
	var query := _state.query_for_context(context)
	var search: LineEdit
	var sort_button: OptionButton
	var tags: LineEdit
	var tags_not: LineEdit
	match context:
		ModioWorkoutBrowserState.TAB_WORKOUT:
			search = _workout_search_line_edit
			sort_button = _workout_sort_option_button
			tags = _workout_tags_line_edit
			tags_not = _workout_exclude_tags_line_edit
		ModioWorkoutBrowserState.TAB_SUBSCRIBED:
			search = _subscribed_search_line_edit
			sort_button = _subscribed_sort_option_button
			tags = _subscribed_tags_line_edit
			tags_not = _subscribed_exclude_tags_line_edit
		_:
			search = _public_search_line_edit
			sort_button = _public_sort_option_button
			tags = _public_tags_line_edit
			tags_not = _public_exclude_tags_line_edit
	search.text = str(query.get("search", ""))
	tags.text = ", ".join(query.get("tags_all", PackedStringArray()))
	tags_not.text = ", ".join(query.get("tags_not", PackedStringArray()))
	sort_button.select(_find_sort_index(str(query.get("sort", ""))))

func _find_sort_index(value: String) -> int:
	for index in range(SORT_OPTIONS.size()):
		if String(SORT_OPTIONS[index].value) == value:
			return index
	return 0

func _read_query_from_controls(context: String) -> Dictionary:
	var search := ""
	var sort_button: OptionButton
	var tags_text := ""
	var tags_not_text := ""
	match context:
		ModioWorkoutBrowserState.TAB_WORKOUT:
			search = _workout_search_line_edit.text
			sort_button = _workout_sort_option_button
			tags_text = _workout_tags_line_edit.text
			tags_not_text = _workout_exclude_tags_line_edit.text
		ModioWorkoutBrowserState.TAB_SUBSCRIBED:
			search = _subscribed_search_line_edit.text
			sort_button = _subscribed_sort_option_button
			tags_text = _subscribed_tags_line_edit.text
			tags_not_text = _subscribed_exclude_tags_line_edit.text
		_:
			search = _public_search_line_edit.text
			sort_button = _public_sort_option_button
			tags_text = _public_tags_line_edit.text
			tags_not_text = _public_exclude_tags_line_edit.text
	var existing := _state.query_for_context(context).duplicate(true)
	existing["search"] = search.strip_edges()
	existing["sort"] = String(SORT_OPTIONS[sort_button.selected].value)
	existing["tags_all"] = _parse_csv(tags_text)
	existing["tags_not"] = _parse_csv(tags_not_text)
	return existing

func _parse_csv(value: String) -> PackedStringArray:
	var result := PackedStringArray()
	for part in value.split(","):
		var cleaned := part.strip_edges()
		if not cleaned.is_empty():
			result.append(cleaned)
	return result

func _build_listing_query(context: String) -> ModioListingQuery:
	var query_data := _state.query_for_context(context)
	var query := ModioListingQuery.new(
		str(query_data.get("search", "")),
		query_data.get("tags_all", PackedStringArray()),
		int(query_data.get("limit", ModioWorkoutBrowserState.DEFAULT_PAGE_LIMIT)),
		int(query_data.get("offset", 0)),
		str(query_data.get("sort", "")),
		query_data.get("tags_any", PackedStringArray()),
		query_data.get("tags_not", PackedStringArray())
	)
	query.game_id = _state.game_id
	return query

func _fetch_listing(context: String) -> void:
	_state.query_for_context(context).merge(_read_query_from_controls(context), true)
	if not _state.can_browse_public():
		_set_status("Enter both Game ID and API Key before browsing mod.io.")
		_refresh_all_ui()
		return
	if context != ModioWorkoutBrowserState.TAB_PUBLIC and not _state.is_authenticated():
		_set_status("Athlete-only tabs require an access token from the email-code auth flow.")
		_refresh_all_ui()
		return
	_rebuild_manager()
	var response: Dictionary
	if context == ModioWorkoutBrowserState.TAB_SUBSCRIBED:
		response = _manager.execute_adapter_request("build_user_subscriptions_request", [_build_listing_query(context)])
	else:
		response = _manager.execute_adapter_request("build_listing_request", [_build_listing_query(context)])
	if not bool(response.get("ok", false)):
		_set_status(_response_error_message(response, "Failed to fetch %s." % context))
		return
	var normalized = _manager.normalize_with_adapter(
		"normalize_subscriptions_response" if context == ModioWorkoutBrowserState.TAB_SUBSCRIBED else "normalize_mod_list_response",
		[response.get("payload", {})]
	)
	_state.set_listing_for_context(context, normalized if normalized is Dictionary else ModioWorkoutBrowserState._empty_listing())
	_state.raw_debug_sections[context] = response.get("payload", {})
	_set_status("Loaded %s (%d result(s))." % [context.replace("_", " "), int(_state.listing_for_context(context).get("result_count", 0))])
	_update_listing_ui(context)
	if context == ModioWorkoutBrowserState.TAB_SUBSCRIBED:
		_update_profile_ui()

func _shift_page(context: String, direction: int) -> void:
	var query: Dictionary = _state.query_for_context(context)
	var listing: Dictionary = _state.listing_for_context(context)
	var page: Dictionary = listing.get("page", {})
	if direction < 0 and bool(page.get("has_previous", false)):
		query["offset"] = int(page.get("previous_offset", 0))
	elif direction > 0 and bool(page.get("has_next", false)):
		query["offset"] = int(page.get("next_offset", 0))
	else:
		return
	_fetch_listing(context)

func _update_listing_ui(context: String) -> void:
	var listing: Dictionary = _state.listing_for_context(context)
	var grid: GridContainer
	var empty_label: Label
	var page_label: Label
	var prev_button: Button
	var next_button: Button
	match context:
		ModioWorkoutBrowserState.TAB_WORKOUT:
			grid = _workout_cards_grid
			empty_label = _workout_empty_label
			page_label = _workout_page_label
			prev_button = _workout_prev_button
			next_button = _workout_next_button
		ModioWorkoutBrowserState.TAB_SUBSCRIBED:
			grid = _subscribed_cards_grid
			empty_label = _subscribed_empty_label
			page_label = _subscribed_page_label
			prev_button = _subscribed_prev_button
			next_button = _subscribed_next_button
		_:
			grid = _public_cards_grid
			empty_label = _public_empty_label
			page_label = _public_page_label
			prev_button = _public_prev_button
			next_button = _public_next_button
	for child in grid.get_children():
		child.queue_free()
	var page: Dictionary = listing.get("page", {})
	page_label.text = "Page %d of %d · showing %d of %d" % [
		int(page.get("page_index", 0)) + 1,
		maxi(1, int(page.get("page_count", 0))),
		int(listing.get("result_count", 0)),
		int(listing.get("result_total", 0))
	]
	prev_button.disabled = not bool(page.get("has_previous", false))
	next_button.disabled = not bool(page.get("has_next", false))
	var data: Array = listing.get("data", [])
	empty_label.text = "" if not data.is_empty() else _empty_listing_text(context)
	for entry in data:
		if entry is Dictionary:
			grid.add_child(_build_mod_card(entry, context))

func _empty_listing_text(context: String) -> String:
	match context:
		ModioWorkoutBrowserState.TAB_SUBSCRIBED:
			return "No subscribed workouts matched the current filters."
		ModioWorkoutBrowserState.TAB_WORKOUT:
			return "Authenticate, then fetch workouts to browse athlete-only actions."
		_:
			return "Enter connection values and fetch public workouts."

func _build_mod_card(entry: Dictionary, context: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 260)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(0, 120)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(image)
	_set_preview_texture(image, entry)

	var name_label := Label.new()
	name_label.text = str(entry.get("name", "Unnamed Workout"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(name_label)

	var summary_label := Label.new()
	summary_label.text = _truncate(str(entry.get("summary", entry.get("description_plaintext", ""))), 96)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(summary_label)

	var meta_label := Label.new()
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_label.text = "Downloads: %s · Subscribers: %s" % [
		str(entry.get("stats", {}).get("downloads_total", 0)),
		str(entry.get("stats", {}).get("subscribers_total", 0))
	]
	root.add_child(meta_label)

	var button := Button.new()
	button.text = "Open Details"
	button.pressed.connect(func() -> void:
		_open_detail(entry, context)
	)
	root.add_child(button)
	return card

func _set_preview_texture(texture_rect: TextureRect, entry: Dictionary) -> void:
	var image_url := _extract_image_url(entry)
	if image_url.is_empty():
		texture_rect.texture = _placeholder_texture("No image")
		return
	if _image_cache.has(image_url):
		texture_rect.texture = _image_cache[image_url]
		return
	var cache_path := _cache_path_for_url(image_url)
	if FileAccess.file_exists(cache_path):
		var image := Image.new()
		if image.load(cache_path) == OK:
			var texture := ImageTexture.create_from_image(image)
			_image_cache[image_url] = texture
			texture_rect.texture = texture
			return
	texture_rect.texture = _placeholder_texture("Loading…")
	var http := HTTPRequest.new()
	texture_rect.add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
		if response_code < 200 or response_code >= 300:
			texture_rect.texture = _placeholder_texture("Image unavailable")
			http.queue_free()
			return
		var image := Image.new()
		var load_error := _load_image_bytes(image, headers, body, image_url)
		if load_error != OK:
			texture_rect.texture = _placeholder_texture("Image unavailable")
			http.queue_free()
			return
		image.resize(CARD_PREVIEW_SIZE.x, CARD_PREVIEW_SIZE.y, Image.INTERPOLATE_LANCZOS)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(IMAGE_CACHE_DIR))
		image.save_png(cache_path)
		var texture := ImageTexture.create_from_image(image)
		_image_cache[image_url] = texture
		texture_rect.texture = texture
		http.queue_free()
	)
	http.request.call_deferred(image_url)

func _extract_image_url(entry: Dictionary) -> String:
	var logo: Dictionary = entry.get("logo", {})
	if not str(logo.get("thumb_320x180", "")).is_empty():
		return str(logo.get("thumb_320x180", ""))
	if not str(logo.get("original", "")).is_empty():
		return str(logo.get("original", ""))
	var media: Dictionary = entry.get("media", {})
	var images: Array = media.get("images", [])
	if not images.is_empty():
		var first = images[0]
		if first is Dictionary:
			return str(first.get("thumb_320x180", first.get("original", "")))
	return ""

func _placeholder_texture(text: String) -> Texture2D:
	var image := Image.create(CARD_PREVIEW_SIZE.x, CARD_PREVIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.12, 0.12, 0.16, 1.0))
	return ImageTexture.create_from_image(image)

func _cache_path_for_url(url: String) -> String:
	return "%s/%s.png" % [IMAGE_CACHE_DIR, str(url.hash())]

func _load_image_bytes(image: Image, headers: PackedStringArray, body: PackedByteArray, url: String) -> int:
	var content_type := ""
	for header in headers:
		var normalized := String(header).to_lower()
		if normalized.begins_with("content-type:"):
			content_type = normalized.split(":", false, 1)[1].strip_edges()
	if content_type.contains("jpeg") or url.to_lower().ends_with(".jpg") or url.to_lower().ends_with(".jpeg"):
		return image.load_jpg_from_buffer(body)
	if content_type.contains("webp") or url.to_lower().ends_with(".webp"):
		return image.load_webp_from_buffer(body)
	return image.load_png_from_buffer(body)

func _open_detail(entry: Dictionary, context: String) -> void:
	_state.selected_mod_id = int(entry.get("id", 0))
	_state.selected_mod_context = context
	_detail_title_label.text = str(entry.get("name", "Workout"))
	_detail_summary_label.text = _detail_bbcode(entry)
	_detail_status_label.text = ""
	_set_preview_texture(_detail_image, entry)
	match context:
		ModioWorkoutBrowserState.TAB_WORKOUT:
			_detail_action_button.visible = true
			_detail_action_button.text = "Subscribe"
		ModioWorkoutBrowserState.TAB_SUBSCRIBED:
			_detail_action_button.visible = true
			_detail_action_button.text = "Unsubscribe"
		_:
			_detail_action_button.visible = false
	_detail_overlay.visible = true

func _detail_bbcode(entry: Dictionary) -> String:
	var tags := PackedStringArray()
	for tag in entry.get("tags", []):
		if tag is Dictionary:
			tags.append(str(tag.get("name", tag.get("tag", ""))))
		else:
			tags.append(str(tag))
	var metadata_pairs := PackedStringArray()
	var metadata: Dictionary = entry.get("metadata_kvp", {})
	for key in metadata.keys():
		metadata_pairs.append("%s=%s" % [str(key), JSON.stringify(metadata[key])])
	return "\n".join([
		"[b]Summary[/b]\n%s" % str(entry.get("summary", "")),
		"[b]Description[/b]\n%s" % str(entry.get("description_plaintext", entry.get("description", ""))),
		"[b]Tags[/b] %s" % (", ".join(tags) if not tags.is_empty() else "(none)"),
		"[b]Downloads[/b] %s" % str(entry.get("stats", {}).get("downloads_total", 0)),
		"[b]Subscribers[/b] %s" % str(entry.get("stats", {}).get("subscribers_total", 0)),
		"[b]Price[/b] %s | [b]Tax[/b] %s" % [str(entry.get("price", 0)), str(entry.get("tax", 0))],
		"[b]Metadata[/b] %s" % ("; ".join(metadata_pairs) if not metadata_pairs.is_empty() else "(none)"),
		"[b]Profile URL[/b] %s" % str(entry.get("profile_url", ""))
	])

func _close_detail_overlay() -> void:
	_detail_overlay.visible = false
	_detail_action_button.disabled = false
	_detail_status_label.text = ""

func _on_detail_action_pressed() -> void:
	if _state.selected_mod_id <= 0:
		return
	if not _state.is_authenticated():
		_detail_status_label.text = "Authenticate first."
		return
	_rebuild_manager()
	var response: Dictionary
	if _state.selected_mod_context == ModioWorkoutBrowserState.TAB_SUBSCRIBED:
		response = _manager.execute_adapter_request("build_unsubscribe_request", [str(_state.selected_mod_id)])
		if bool(response.get("ok", false)):
			_state.remove_subscribed_mod(_state.selected_mod_id)
			_detail_status_label.text = "Unsubscribed successfully. Removed from the subscribed list immediately."
			_update_listing_ui(ModioWorkoutBrowserState.TAB_SUBSCRIBED)
			_update_profile_ui()
			return
		_detail_status_label.text = _response_error_message(response, "Failed to unsubscribe.")
		return
	response = _manager.execute_adapter_request("build_subscribe_request", [str(_state.selected_mod_id), false])
	if bool(response.get("ok", false)):
		var normalized = _manager.normalize_with_adapter("normalize_subscription_write_response", [int(response.get("status_code", 0)), response.get("headers", {}), response.get("payload", {})])
		var already := bool(normalized.get("already_subscribed", false)) if normalized is Dictionary else false
		_detail_status_label.text = "Already subscribed." if already else "Subscribed successfully."
		return
	_detail_status_label.text = _response_error_message(response, "Failed to subscribe.")

func _on_request_code_pressed() -> void:
	var email := _email_line_edit.text.strip_edges()
	if email.is_empty():
		_set_status("Enter an email before requesting a security code.")
		return
	_state.email = email
	_rebuild_manager()
	var response := _manager.execute_adapter_request("build_email_security_code_request", [email])
	if bool(response.get("ok", false)):
		_state.last_requested_email = email
		_state.raw_debug_sections["email_request"] = response.get("payload", {})
		_set_status("Security code requested for %s. Check the inbox, then use emailexchange below." % email)
		_refresh_all_ui()
		return
	_set_status(_response_error_message(response, "Failed to request a security code."))

func _on_exchange_code_pressed(_submitted_text: String = "") -> void:
	var code := _security_code_line_edit.text.strip_edges()
	if code.is_empty():
		_set_status("Paste the emailed security code before exchanging it.")
		return
	_rebuild_manager()
	var response := _manager.execute_adapter_request("build_auth_exchange_request", [code, 0])
	if not bool(response.get("ok", false)):
		_set_status(_response_error_message(response, "Failed to exchange the security code."))
		return
	var payload: Dictionary = response.get("payload", {})
	_state.access_token = str(payload.get("access_token", "")).strip_edges()
	_state.last_security_code = code
	_state.raw_debug_sections["auth_exchange"] = payload
	_rebuild_manager()
	var persisted := _store.save_session_values(_state.environment, {
		"access_token": _state.access_token
	})
	if not bool(persisted.get("ok", false)):
		_set_status("Exchanged code, but failed to persist access_token to %s." % _store.get_storage_path())
		_refresh_all_ui()
		return
	_set_status("Access token stored in %s. Refreshing /me to resolve athlete identity..." % _store.get_storage_path())
	_refresh_profile_data(true)

func _on_clear_session_pressed() -> void:
	_state.clear_session()
	_store.clear_session_values(_state.environment, PackedStringArray(["access_token", "user_id"]))
	_rebuild_manager()
	_set_status("Cleared access_token and user_id from %s." % _store.get_storage_path())
	_refresh_all_ui()

func _on_profile_refresh_pressed() -> void:
	_refresh_profile_data(false)

func _refresh_profile_data(open_profile_tab: bool) -> void:
	if not _state.is_authenticated():
		_set_status("Profile refresh requires a valid access token.")
		_refresh_all_ui()
		return
	_rebuild_manager()
	var me_response := _manager.execute_adapter_request("build_authenticated_user_request")
	if not bool(me_response.get("ok", false)):
		_set_status(_response_error_message(me_response, "Failed to load /me."))
		return
	_state.profile = _manager.normalize_with_adapter("normalize_authenticated_user_response", [me_response.get("payload", {})])
	_state.raw_debug_sections["profile"] = me_response.get("payload", {})
	_state.user_id = str(_state.profile.get("id", _state.user_id))
	_store.save_session_values(_state.environment, {
		"access_token": _state.access_token,
		"user_id": _state.user_id
	})
	_rebuild_manager()
	var wallet_response := _manager.execute_adapter_request("build_user_wallet_request", [_state.game_id])
	if bool(wallet_response.get("ok", false)):
		_state.wallet = _manager.normalize_with_adapter("normalize_user_wallet_response", [wallet_response.get("payload", {})])
		_state.raw_debug_sections["wallet"] = wallet_response.get("payload", {})
	else:
		_state.wallet = {"error": _response_error_message(wallet_response, "Failed to load wallet.")}
	var purchased_response := _manager.execute_adapter_request("build_user_purchased_request", [_build_listing_query(ModioWorkoutBrowserState.TAB_WORKOUT)])
	if bool(purchased_response.get("ok", false)):
		_state.purchased = _manager.normalize_with_adapter("normalize_user_purchased_response", [purchased_response.get("payload", {})])
		_state.raw_debug_sections["purchased"] = purchased_response.get("payload", {})
	else:
		_state.purchased = {"error": _response_error_message(purchased_response, "Failed to load purchase history."), "data": []}
	_set_status("Loaded athlete profile, wallet, and purchase history. Session values are stored in %s." % _store.get_storage_path())
	if open_profile_tab:
		_tab_container.current_tab = TAB_PROFILE_INDEX
	_refresh_all_ui()

func _update_profile_ui() -> void:
	if not _state.is_authenticated():
		_profile_summary_label.text = "Authenticate to inspect the athlete profile, wallet, and purchase history."
		_profile_raw_text.text = ""
		return
	var profile := _state.profile
	var wallet := _state.wallet
	var purchased_names := PackedStringArray()
	for entry in _state.purchased.get("data", []):
		if entry is Dictionary:
			purchased_names.append(str(entry.get("name", "")))
	var lines := PackedStringArray()
	lines.append("[b]Curated Profile Summary[/b]")
	lines.append("Username: %s" % str(profile.get("username", "(unknown)")))
	lines.append("Name ID: %s" % str(profile.get("name_id", "")))
	lines.append("User ID: %s" % str(profile.get("id", 0)))
	lines.append("Profile URL: %s" % str(profile.get("profile_url", "")))
	lines.append("Language / TZ: %s / %s" % [str(profile.get("language", "")), str(profile.get("timezone", ""))])
	lines.append("Authenticated: %s" % str(bool(profile.get("is_authenticated", false))))
	lines.append("")
	lines.append("[b]Wallet[/b]")
	if wallet.has("error"):
		lines.append(str(wallet.get("error", "")))
	else:
		lines.append("Type: %s" % str(wallet.get("type", "")))
		lines.append("Currency: %s" % str(wallet.get("currency", "")))
		lines.append("Balance / Pending / Deficit: %s / %s / %s" % [str(wallet.get("balance", 0)), str(wallet.get("pending_balance", 0)), str(wallet.get("deficit", 0))])
		lines.append("Monetization status: %s" % str(wallet.get("monetization_status", 0)))
		lines.append("payment_method_id: %s" % str(wallet.get("payment_method_id", "(not present)")))
	lines.append("")
	lines.append("[b]Purchase History[/b]")
	lines.append("Count: %s" % str(_state.purchased.get("result_total", 0)))
	lines.append("Recent items: %s" % (", ".join(purchased_names) if not purchased_names.is_empty() else "(none)"))
	_profile_summary_label.text = "\n".join(lines)
	_profile_raw_text.text = JSON.stringify({
		"profile": _state.raw_debug_sections.get("profile", {}),
		"wallet": _state.raw_debug_sections.get("wallet", {}),
		"purchased": _state.raw_debug_sections.get("purchased", {})
	}, "\t")

func _set_status(message: String) -> void:
	_state.status_text = message
	_status_label.text = message

func _response_error_message(response: Dictionary, fallback: String) -> String:
	var error_payload = response.get("error", {})
	if error_payload is Dictionary and not str(error_payload.get("message", "")).is_empty():
		return str(error_payload.get("message", ""))
	return fallback

func _on_tab_changed(index: int) -> void:
	match index:
		TAB_PROFILE_INDEX:
			_state.active_tab = ModioWorkoutBrowserState.TAB_PROFILE
		TAB_WORKOUT_INDEX:
			_state.active_tab = ModioWorkoutBrowserState.TAB_WORKOUT
		TAB_SUBSCRIBED_INDEX:
			_state.active_tab = ModioWorkoutBrowserState.TAB_SUBSCRIBED
		_:
			_state.active_tab = ModioWorkoutBrowserState.TAB_PUBLIC

func _on_connection_field_changed(_index: int) -> void:
	_state.environment = ModioEnvLoader.ENV_TEST if _server_option_button.selected == 0 else ModioEnvLoader.ENV_LIVE

func _on_connection_text_changed(_new_text: String) -> void:
	_state.game_id = _game_id_line_edit.text.strip_edges()
	_state.api_key = _api_key_line_edit.text.strip_edges()

func _on_apply_connection_pressed(_submitted_text: String = "") -> void:
	_state.environment = ModioEnvLoader.ENV_TEST if _server_option_button.selected == 0 else ModioEnvLoader.ENV_LIVE
	_state.game_id = _game_id_line_edit.text.strip_edges()
	_state.api_key = _api_key_line_edit.text.strip_edges()
	_rebuild_manager()
	_set_status("Applied editable connection values. Public browsing now targets %s with game %s." % [_state.environment, _state.game_id])
	_refresh_all_ui()
	_fetch_listing(ModioWorkoutBrowserState.TAB_PUBLIC)

func _on_reload_defaults_pressed() -> void:
	_load_initial_state()
	_set_status("Reloaded environment defaults from the current local config files.")
	_refresh_all_ui()

func _truncate(value: String, max_chars: int) -> String:
	if value.length() <= max_chars:
		return value
	return "%s…" % value.substr(0, max_chars)
