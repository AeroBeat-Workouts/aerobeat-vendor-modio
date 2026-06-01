extends Control

const ModioWorkoutUploadFlow = preload("res://addons/aerobeat-vendor-modio/src/modio_workout_upload_flow.gd")
const AeroDeviceDetectionModioMetadata = preload("res://addons/aerobeat-tool-device-detection/src/AeroDeviceDetectionModioMetadata.gd")

const GLOBAL_TAB_CONNECTION_INDEX := 0
const GLOBAL_TAB_AUTH_INDEX := 1
const GLOBAL_TAB_BROWSER_INDEX := 2
const BROWSER_TAB_PUBLIC_INDEX := 0
const BROWSER_TAB_PROFILE_INDEX := 1
const BROWSER_TAB_WORKOUT_INDEX := 2
const BROWSER_TAB_SUBSCRIBED_INDEX := 3
const BROWSER_TAB_UPLOAD_INDEX := 4
const CARD_PREVIEW_SIZE := Vector2i(320, 180)
const IMAGE_CACHE_DIR := "user://modio_workout_browser_images"
const DOWNLOAD_CACHE_DIR := "user://modio_workout_browser_downloads"
const DETAIL_ACTION_SUBSCRIBE := "subscribe"
const DETAIL_ACTION_UNSUBSCRIBE := "unsubscribe"
const AUTH_TOKEN_REQUEST_MAX_SECONDS := 31536000
const SORT_OPTIONS := [
	{"label": "Recently Updated", "value": "-date_updated"},
	{"label": "Newest", "value": "-date_live"},
	{"label": "Most Popular", "value": "-popular"},
	{"label": "Most Downloaded", "value": "-downloads_total"},
	{"label": "Alphabetical", "value": "name"}
]
const UPLOAD_METADATA_BASE_SEED := {
	"aerobeat_version": "1.0.0",
	"upload_surface": "modio_workout_browser_testbed",
	"upload_flow": "staged_draft_then_modfile"
}
const UPLOAD_METADATA_DEVICE_SEED := {
	"profile": "surface_pro_8_upload_fixture",
	"device_name": "Surface Pro 8",
	"model_name": "Surface Pro 8",
	"platform": "windows",
	"os_name": "Windows",
	"os_version": "11",
	"cpu_name": "11th Gen Intel(R) Core(TM) i7-1185G7",
	"gpu_name": "Intel Iris Xe Graphics",
	"gpu_vendor": "Intel",
	"renderer_name": "forward_plus",
	"rendering_method": "forward_plus",
	"display_server": "windows",
	"screen_size": {"width": 2880, "height": 1920},
	"memory_gb": 16.0,
	"tags": ["surface", "intel", "portable"],
	"metadata": {
		"engine": {"major": 4},
		"feature_tags": ["debug"]
	}
}

var _loader := ModioEnvLoader.new()
var _store := ModioSessionConfigStore.new()
var _state := ModioWorkoutBrowserState.new()
var _manager = null
var _base_config: ModioClientConfig
var _upload_flow = ModioWorkoutUploadFlow.new()
var _image_cache: Dictionary = {}
var _ui_built: bool = false
var _suspend_session_persistence: bool = false
var _stable_config_path_override: String = ""
var _session_config_path_override: String = ""

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
var _global_tab_container: TabContainer
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
var _upload_intro_label: Label
var _upload_name_line_edit: LineEdit
var _upload_name_id_line_edit: LineEdit
var _upload_summary_line_edit: LineEdit
var _upload_description_text_edit: TextEdit
var _upload_metadata_text_edit: TextEdit
var _upload_tags_line_edit: LineEdit
var _upload_logo_path_line_edit: LineEdit
var _upload_logo_browse_button: Button
var _upload_zip_path_line_edit: LineEdit
var _upload_zip_browse_button: Button
var _upload_version_line_edit: LineEdit
var _upload_changelog_text_edit: TextEdit
var _upload_publish_checkbox: CheckBox
var _upload_submit_button: Button
var _upload_status_label: Label
var _upload_result_label: RichTextLabel
var _upload_logo_file_dialog: FileDialog
var _upload_zip_file_dialog: FileDialog
var _detail_overlay: ColorRect
var _detail_panel: PanelContainer
var _detail_title_label: Label
var _detail_image: TextureRect
var _detail_summary_label: RichTextLabel
var _detail_close_button: Button
var _detail_action_button: Button
var _detail_download_button: Button
var _detail_download_path_line_edit: LineEdit
var _detail_download_browse_button: Button
var _detail_download_hint_label: Label
var _detail_status_label: Label
var _detail_file_dialog: FileDialog
var _detail_entry: Dictionary = {}
var _detail_action_mode: String = ""
var _manager_factory: Callable = Callable()

func _ready() -> void:
	name = "WorkoutBrowserTestbed"
	_suspend_session_persistence = true
	_ensure_ui_built()
	_load_initial_state()
	_refresh_all_ui()
	_restore_saved_runtime_state()
	_suspend_session_persistence = false

func set_config_paths_for_testing(stable_path: String = "", session_path: String = "") -> void:
	_stable_config_path_override = stable_path.strip_edges()
	_session_config_path_override = session_path.strip_edges()

func set_manager_factory_for_testing(factory: Callable) -> void:
	_manager_factory = factory

func _stable_config_path() -> String:
	return _stable_config_path_override if not _stable_config_path_override.is_empty() else ModioEnvLoader.CONFIG_STABLE_PATH

func _session_config_path() -> String:
	return _session_config_path_override if not _session_config_path_override.is_empty() else ModioEnvLoader.CONFIG_SESSION_PATH

func describe_scene_surface() -> Dictionary:
	_ensure_ui_built()
	return {
		"group_id": "workout_browser",
		"description": "Default operator-facing mod.io workout browser scene with editable server credentials, email-code auth, profile summary, public browsing, athlete browsing, subscribed workout management, and staged workout uploads.",
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"has_connection_controls": is_instance_valid(_server_option_button) and is_instance_valid(_game_id_line_edit) and is_instance_valid(_api_key_line_edit),
		"has_auth_controls": is_instance_valid(_email_line_edit) and is_instance_valid(_security_code_line_edit),
		"has_global_tabs": is_instance_valid(_global_tab_container),
		"has_tab_container": is_instance_valid(_tab_container),
		"has_upload_controls": is_instance_valid(_upload_name_line_edit) and is_instance_valid(_upload_logo_path_line_edit) and is_instance_valid(_upload_zip_path_line_edit) and is_instance_valid(_upload_submit_button),
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
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Workout Browser"
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	_global_tab_container = TabContainer.new()
	_global_tab_container.name = "GlobalTabContainer"
	_global_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_global_tab_container)

	var connection_tab := VBoxContainer.new()
	connection_tab.name = "ConnectionTab"
	connection_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	connection_tab.add_child(_build_connection_panel())
	_global_tab_container.add_child(connection_tab)
	_global_tab_container.set_tab_title(GLOBAL_TAB_CONNECTION_INDEX, "Connection")

	var auth_tab := VBoxContainer.new()
	auth_tab.name = "AuthTab"
	auth_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	auth_tab.add_child(_build_auth_panel())
	_global_tab_container.add_child(auth_tab)
	_global_tab_container.set_tab_title(GLOBAL_TAB_AUTH_INDEX, "Auth")

	var browser_tab := VBoxContainer.new()
	browser_tab.name = "BrowserTab"
	browser_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browser_tab.add_theme_constant_override("separation", 8)
	_global_tab_container.add_child(browser_tab)
	_global_tab_container.set_tab_title(GLOBAL_TAB_BROWSER_INDEX, "Browser")

	_tab_container = TabContainer.new()
	_tab_container.name = "BrowserTabContainer"
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.tab_changed.connect(_on_tab_changed)
	browser_tab.add_child(_tab_container)

	_tab_container.add_child(_build_public_tab())
	_tab_container.set_tab_title(BROWSER_TAB_PUBLIC_INDEX, "Public Catalog")
	_tab_container.add_child(_build_profile_tab())
	_tab_container.set_tab_title(BROWSER_TAB_PROFILE_INDEX, "Profile")
	_tab_container.add_child(_build_workout_tab())
	_tab_container.set_tab_title(BROWSER_TAB_WORKOUT_INDEX, "Workout Browser")
	_tab_container.add_child(_build_subscribed_tab())
	_tab_container.set_tab_title(BROWSER_TAB_SUBSCRIBED_INDEX, "Subscribed Workouts")
	_tab_container.add_child(_build_upload_tab())
	_tab_container.set_tab_title(BROWSER_TAB_UPLOAD_INDEX, "Upload Workout")

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
	description.text = "Real mod.io athlete auth uses emailrequest → emailexchange. That in-game bearer path already defaults to roughly the longest direct session mod.io documents (about one common year), but it is not a permanent-login toggle and longer silent renewals would require a different backend OAuth architecture. Saved email + token state can be restored here, but athlete username/display-name edits are not supported through our current public REST access."
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
	_email_line_edit.text_changed.connect(_on_email_text_changed)
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

func _build_upload_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "UploadWorkoutTab"
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_theme_constant_override("separation", 8)

	var scroll := ScrollContainer.new()
	scroll.name = "UploadWorkoutScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)

	var scroll_root := VBoxContainer.new()
	scroll_root.name = "UploadWorkoutScrollRoot"
	scroll_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_root.add_theme_constant_override("separation", 8)
	scroll.add_child(scroll_root)

	var intro_panel := PanelContainer.new()
	intro_panel.name = "UploadWorkoutIntroPanel"
	scroll_root.add_child(intro_panel)

	var intro_margin := MarginContainer.new()
	intro_margin.add_theme_constant_override("margin_left", 12)
	intro_margin.add_theme_constant_override("margin_top", 12)
	intro_margin.add_theme_constant_override("margin_right", 12)
	intro_margin.add_theme_constant_override("margin_bottom", 12)
	intro_panel.add_child(intro_margin)

	var intro_root := VBoxContainer.new()
	intro_root.add_theme_constant_override("separation", 8)
	intro_margin.add_child(intro_root)

	var heading := Label.new()
	heading.text = "Upload Workout"
	heading.add_theme_font_size_override("font_size", 18)
	intro_root.add_child(heading)

	_upload_intro_label = Label.new()
	_upload_intro_label.name = "UploadWorkoutIntroLabel"
	_upload_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_root.add_child(_upload_intro_label)

	var form_panel := PanelContainer.new()
	form_panel.name = "UploadWorkoutFormPanel"
	scroll_root.add_child(form_panel)

	var form_margin := MarginContainer.new()
	form_margin.add_theme_constant_override("margin_left", 12)
	form_margin.add_theme_constant_override("margin_top", 12)
	form_margin.add_theme_constant_override("margin_right", 12)
	form_margin.add_theme_constant_override("margin_bottom", 12)
	form_panel.add_child(form_margin)

	var form_root := VBoxContainer.new()
	form_root.name = "UploadWorkoutFormRoot"
	form_root.add_theme_constant_override("separation", 10)
	form_margin.add_child(form_root)

	var name_row := HBoxContainer.new()
	name_row.name = "UploadWorkoutNameRow"
	name_row.add_theme_constant_override("separation", 8)
	form_root.add_child(name_row)

	name_row.add_child(_build_upload_text_line("Workout Name", "UploadWorkoutNameLineEdit", "Cardio Blast 30", func(control: LineEdit) -> void:
		_upload_name_line_edit = control
	))
	name_row.add_child(_build_upload_text_line("Name ID / Slug (optional)", "UploadWorkoutNameIdLineEdit", "cardio-blast-30", func(control: LineEdit) -> void:
		_upload_name_id_line_edit = control
	))

	var summary_description_row := HBoxContainer.new()
	summary_description_row.name = "UploadWorkoutSummaryDescriptionRow"
	summary_description_row.add_theme_constant_override("separation", 8)
	form_root.add_child(summary_description_row)
	summary_description_row.add_child(_build_upload_text_line("Summary", "UploadWorkoutSummaryLineEdit", "Short operator-visible summary", func(control: LineEdit) -> void:
		_upload_summary_line_edit = control
	))
	var description_box := _build_upload_multiline_box("Description", "UploadWorkoutDescriptionTextEdit", Vector2(0, 88), "", func(control: TextEdit) -> void:
		_upload_description_text_edit = control
	)
	summary_description_row.add_child(description_box)

	var metadata_tags_row := HBoxContainer.new()
	metadata_tags_row.name = "UploadWorkoutMetadataTagsRow"
	metadata_tags_row.add_theme_constant_override("separation", 8)
	form_root.add_child(metadata_tags_row)
	var metadata_box := _build_upload_multiline_box("Metadata KVP (required, one entry per line)", "UploadWorkoutMetadataTextEdit", Vector2(0, 88), _default_upload_metadata_text(), func(control: TextEdit) -> void:
		_upload_metadata_text_edit = control
	)
	metadata_tags_row.add_child(metadata_box)
	metadata_tags_row.add_child(_build_upload_text_line("Tags (taxonomy/discovery, comma-separated)", "UploadWorkoutTagsLineEdit", "boxing, easy, edm", func(control: LineEdit) -> void:
		_upload_tags_line_edit = control
	))

	var file_row := HBoxContainer.new()
	file_row.name = "UploadWorkoutFileRow"
	file_row.add_theme_constant_override("separation", 8)
	form_root.add_child(file_row)
	file_row.add_child(_build_upload_file_row("Workout Logo", "UploadWorkoutLogoPathLineEdit", "Choose the required logo image", "UploadWorkoutLogoBrowseButton", func(path_edit: LineEdit, browse_button: Button) -> void:
		_upload_logo_path_line_edit = path_edit
		_upload_logo_browse_button = browse_button
		browse_button.pressed.connect(_on_upload_logo_browse_pressed)
	))
	file_row.add_child(_build_upload_file_row("Workout ZIP", "UploadWorkoutZipPathLineEdit", "Choose the workout ZIP to upload", "UploadWorkoutZipBrowseButton", func(path_edit: LineEdit, browse_button: Button) -> void:
		_upload_zip_path_line_edit = path_edit
		_upload_zip_browse_button = browse_button
		browse_button.pressed.connect(_on_upload_zip_browse_pressed)
	))

	var version_row := HBoxContainer.new()
	version_row.name = "UploadWorkoutVersionRow"
	version_row.add_theme_constant_override("separation", 8)
	form_root.add_child(version_row)
	version_row.add_child(_build_upload_text_line("Version (optional)", "UploadWorkoutVersionLineEdit", "1.0.0", func(control: LineEdit) -> void:
		_upload_version_line_edit = control
	))
	var changelog_box := _build_upload_multiline_box("Changelog (optional)", "UploadWorkoutChangelogTextEdit", Vector2(0, 88), "", func(control: TextEdit) -> void:
		_upload_changelog_text_edit = control
	)
	version_row.add_child(changelog_box)

	_upload_publish_checkbox = CheckBox.new()
	_upload_publish_checkbox.name = "UploadWorkoutPublishCheckBox"
	_upload_publish_checkbox.text = "Publish immediately after the ZIP upload succeeds"
	form_root.add_child(_upload_publish_checkbox)

	_upload_submit_button = Button.new()
	_upload_submit_button.name = "UploadWorkoutSubmitButton"
	_upload_submit_button.text = "Create Draft + Upload ZIP"
	_upload_submit_button.pressed.connect(_on_upload_workout_pressed)
	form_root.add_child(_upload_submit_button)

	_upload_status_label = Label.new()
	_upload_status_label.name = "UploadWorkoutStatusLabel"
	_upload_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form_root.add_child(_upload_status_label)

	_upload_result_label = RichTextLabel.new()
	_upload_result_label.name = "UploadWorkoutResultLabel"
	_upload_result_label.bbcode_enabled = true
	_upload_result_label.fit_content = true
	_upload_result_label.scroll_active = false
	form_root.add_child(_upload_result_label)

	_upload_logo_file_dialog = FileDialog.new()
	_upload_logo_file_dialog.name = "UploadWorkoutLogoFileDialog"
	_upload_logo_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_upload_logo_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_upload_logo_file_dialog.title = "Choose Workout Logo"
	_upload_logo_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	_upload_logo_file_dialog.file_selected.connect(_on_upload_logo_path_selected)
	tab.add_child(_upload_logo_file_dialog)

	_upload_zip_file_dialog = FileDialog.new()
	_upload_zip_file_dialog.name = "UploadWorkoutZipFileDialog"
	_upload_zip_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_upload_zip_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_upload_zip_file_dialog.title = "Choose Workout ZIP"
	_upload_zip_file_dialog.filters = PackedStringArray(["*.zip ; ZIP archive"])
	_upload_zip_file_dialog.file_selected.connect(_on_upload_zip_path_selected)
	tab.add_child(_upload_zip_file_dialog)

	return tab

func _build_upload_text_line(label_text: String, line_name: String, placeholder: String, assign: Callable) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_field_label(label_text))
	var line_edit := LineEdit.new()
	line_edit.name = line_name
	line_edit.placeholder_text = placeholder
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(line_edit)
	assign.call(line_edit)
	return box

func _build_upload_multiline_box(label_text: String, control_name: String, minimum_size: Vector2, placeholder: String, assign: Callable) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_field_label(label_text))
	var text_edit := TextEdit.new()
	text_edit.name = control_name
	text_edit.custom_minimum_size = minimum_size
	text_edit.placeholder_text = placeholder
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(text_edit)
	assign.call(text_edit)
	return box

func _build_upload_file_row(label_text: String, line_name: String, placeholder: String, button_name: String, assign: Callable) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_field_label(label_text))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var line_edit := LineEdit.new()
	line_edit.name = line_name
	line_edit.placeholder_text = placeholder
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line_edit)
	var button := Button.new()
	button.name = button_name
	button.text = "Browse…"
	row.add_child(button)
	assign.call(line_edit, button)
	return box

func _listing_controls(control_name: String, on_fetch: Callable, on_page_shift: Callable, assign_fields: Callable) -> Control:
	var panel := PanelContainer.new()
	panel.name = control_name
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inner.add_child(row)

	var search := LineEdit.new()
	search.name = "%sSearchLineEdit" % control_name
	search.placeholder_text = "Search workouts"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_submitted.connect(func(_text: String) -> void:
		on_fetch.call()
	)
	row.add_child(search)

	var sort_button := OptionButton.new()
	sort_button.name = "%sSortOptionButton" % control_name
	for option in SORT_OPTIONS:
		sort_button.add_item(option.label)
	row.add_child(sort_button)

	var tags := LineEdit.new()
	tags.name = "%sTagsLineEdit" % control_name
	tags.placeholder_text = "tags (comma-separated, all)"
	tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tags)

	var tags_not := LineEdit.new()
	tags_not.name = "%sExcludeTagsLineEdit" % control_name
	tags_not.placeholder_text = "exclude tags"
	tags_not.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tags_not)

	var fetch_button := Button.new()
	fetch_button.name = "%sFetchButton" % control_name
	fetch_button.text = "Fetch"
	fetch_button.pressed.connect(func() -> void:
		on_fetch.call()
	)
	row.add_child(fetch_button)

	var pagination := HBoxContainer.new()
	pagination.add_theme_constant_override("separation", 8)
	inner.add_child(pagination)

	var prev_button := Button.new()
	prev_button.name = "%sPrevButton" % control_name
	prev_button.text = "Previous"
	prev_button.pressed.connect(func() -> void:
		on_page_shift.call(-1)
	)
	pagination.add_child(prev_button)

	var page_label := Label.new()
	page_label.name = "%sPageLabel" % control_name
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pagination.add_child(page_label)

	var next_button := Button.new()
	next_button.name = "%sNextButton" % control_name
	next_button.text = "Next"
	next_button.pressed.connect(func() -> void:
		on_page_shift.call(1)
	)
	pagination.add_child(next_button)

	assign_fields.call(search, sort_button, tags, tags_not, fetch_button, prev_button, next_button, page_label)
	return panel

func _listing_browser(grid_name: String, empty_name: String) -> Dictionary:
	var root := VBoxContainer.new()
	root.name = "%sRoot" % grid_name
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)

	var scroll := ScrollContainer.new()
	scroll.name = "%sScroll" % grid_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	var dock_row := HBoxContainer.new()
	dock_row.name = "DetailDockRow"
	dock_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dock_row)

	var spacer := Control.new()
	spacer.name = "DetailDockSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_row.add_child(spacer)

	_detail_panel = PanelContainer.new()
	_detail_panel.name = "DetailPanel"
	_detail_panel.custom_minimum_size = Vector2(560, 0)
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_row.add_child(_detail_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_detail_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.name = "DetailPanelRoot"
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 4)
	header.add_child(title_box)

	var eyebrow := Label.new()
	eyebrow.name = "DetailEyebrowLabel"
	eyebrow.text = "Workout Details"
	eyebrow.modulate = Color(0.8, 0.84, 0.92, 0.9)
	title_box.add_child(eyebrow)

	_detail_title_label = Label.new()
	_detail_title_label.name = "DetailTitleLabel"
	_detail_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title_label.add_theme_font_size_override("font_size", 24)
	title_box.add_child(_detail_title_label)

	_detail_close_button = Button.new()
	_detail_close_button.name = "DetailCloseButton"
	_detail_close_button.text = "Close"
	_detail_close_button.pressed.connect(_close_detail_overlay)
	header.add_child(_detail_close_button)

	_detail_image = TextureRect.new()
	_detail_image.name = "DetailImage"
	_detail_image.custom_minimum_size = Vector2(0, 280)
	_detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(_detail_image)

	_detail_summary_label = RichTextLabel.new()
	_detail_summary_label.name = "DetailSummaryLabel"
	_detail_summary_label.bbcode_enabled = true
	_detail_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_detail_summary_label)

	var download_panel := PanelContainer.new()
	download_panel.name = "DetailDownloadPanel"
	root.add_child(download_panel)

	var download_margin := MarginContainer.new()
	download_margin.add_theme_constant_override("margin_left", 12)
	download_margin.add_theme_constant_override("margin_top", 12)
	download_margin.add_theme_constant_override("margin_right", 12)
	download_margin.add_theme_constant_override("margin_bottom", 12)
	download_panel.add_child(download_margin)

	var download_root := VBoxContainer.new()
	download_root.add_theme_constant_override("separation", 8)
	download_margin.add_child(download_root)

	var download_title := Label.new()
	download_title.text = "Download"
	download_title.add_theme_font_size_override("font_size", 18)
	download_root.add_child(download_title)

	_detail_download_hint_label = Label.new()
	_detail_download_hint_label.name = "DetailDownloadHintLabel"
	_detail_download_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	download_root.add_child(_detail_download_hint_label)

	var download_row := HBoxContainer.new()
	download_row.add_theme_constant_override("separation", 8)
	download_root.add_child(download_row)

	_detail_download_path_line_edit = LineEdit.new()
	_detail_download_path_line_edit.name = "DetailDownloadPathLineEdit"
	_detail_download_path_line_edit.placeholder_text = "Choose a ZIP save path"
	_detail_download_path_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	download_row.add_child(_detail_download_path_line_edit)

	_detail_download_browse_button = Button.new()
	_detail_download_browse_button.name = "DetailDownloadBrowseButton"
	_detail_download_browse_button.text = "Browse…"
	_detail_download_browse_button.pressed.connect(_on_detail_download_browse_pressed)
	download_row.add_child(_detail_download_browse_button)

	_detail_status_label = Label.new()
	_detail_status_label.name = "DetailStatusLabel"
	_detail_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_detail_status_label)

	var footer := HBoxContainer.new()
	footer.name = "DetailFooter"
	footer.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(footer)

	_detail_download_button = Button.new()
	_detail_download_button.name = "DetailDownloadButton"
	_detail_download_button.text = "Download ZIP"
	_detail_download_button.pressed.connect(_on_detail_download_pressed)
	footer.add_child(_detail_download_button)

	_detail_action_button = Button.new()
	_detail_action_button.name = "DetailActionButton"
	_detail_action_button.visible = false
	_detail_action_button.custom_minimum_size = Vector2(220, 52)
	_detail_action_button.pressed.connect(_on_detail_action_pressed)
	footer.add_child(_detail_action_button)

	_detail_file_dialog = FileDialog.new()
	_detail_file_dialog.name = "DetailDownloadFileDialog"
	_detail_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_detail_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_detail_file_dialog.title = "Save Workout ZIP"
	_detail_file_dialog.filters = PackedStringArray(["*.zip ; ZIP archive"])
	_detail_file_dialog.file_selected.connect(_on_detail_download_path_selected)
	overlay.add_child(_detail_file_dialog)
	return overlay

func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _load_initial_state() -> void:
	var session_config_path := _session_config_path()
	var stable_config_path := _stable_config_path()
	var explicit_env := _store.read_environment(session_config_path)
	var resolved_env := _loader.resolve_environment(explicit_env, stable_config_path, session_config_path)
	_base_config = _loader.build_client_config(resolved_env, stable_config_path, session_config_path)
	_state.environment = resolved_env
	_state.game_id = _base_config.game_id
	_state.api_key = _base_config.api_key
	_state.access_token = _base_config.access_token
	_state.access_token_expires_at = _read_saved_access_token_expiry(resolved_env, session_config_path)
	_state.user_id = _base_config.user_id
	_state.email = _store.read_env_value(resolved_env, "email", session_config_path)
	_state.last_requested_email = _store.read_env_value(resolved_env, "last_requested_email", session_config_path, _state.email)
	_state.active_tab = _store.read_env_value(resolved_env, "browser_tab", session_config_path, ModioWorkoutBrowserState.TAB_PUBLIC)
	_seed_upload_draft_defaults()
	_state.raw_debug_sections["saved_token_restore_note"] = _build_saved_token_restore_note()
	_state.status_text = "Public browsing auto-loads when valid Game ID + API Key are already configured. Athlete-only tabs unlock after email-code auth."
	_rebuild_manager()

func _seed_upload_draft_defaults() -> void:
	var seeded_metadata := _default_upload_metadata_text()
	if str(_state.upload_draft.get("metadata_kvp", "")).strip_edges().is_empty():
		_state.upload_draft["metadata_kvp"] = seeded_metadata
	if str(_state.upload_draft.get("tags", "")).strip_edges().is_empty():
		_state.upload_draft["tags"] = "boxing, easy, edm"

func _default_upload_metadata_text() -> String:
	var lines := PackedStringArray([
		"aerobeat_version=%s" % UPLOAD_METADATA_BASE_SEED["aerobeat_version"],
		"upload_surface=%s" % UPLOAD_METADATA_BASE_SEED["upload_surface"],
		"upload_flow=%s" % UPLOAD_METADATA_BASE_SEED["upload_flow"],
	])
	lines.append_array(PackedStringArray(AeroDeviceDetectionModioMetadata.build_metadata_kvp_pairs(UPLOAD_METADATA_DEVICE_SEED)))
	return "\n".join(lines)

func _rebuild_manager() -> void:
	var portal := _base_config.portal if _base_config != null else ""
	var platform := _base_config.platform if _base_config != null else ""
	var service_token := _base_config.service_token if _base_config != null else ""
	var monetization_team_id := _base_config.monetization_team_id if _base_config != null else ""
	var owned_mod_id := _base_config.owned_mod_id if _base_config != null else ""
	var paid_mod_id := _base_config.paid_mod_id if _base_config != null else ""
	var accept_language := _base_config.accept_language if _base_config != null else ModioClientConfig.DEFAULT_ACCEPT_LANGUAGE
	var config := ModioClientConfig.new(
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
	)
	if _manager_factory.is_valid():
		var built_manager = _manager_factory.call(config, _state)
		if built_manager != null:
			_manager = built_manager
			return
	_manager = AeroModIOManager.new(config)

func _refresh_all_ui() -> void:
	_server_option_button.select(0 if _state.environment == ModioEnvLoader.ENV_TEST else 1)
	_game_id_line_edit.text = _state.game_id
	_api_key_line_edit.text = _state.api_key
	_storage_disclosure_label.text = "Game ID + API key are read from %s. Athlete email + auth/session values are read from and written back to %s." % [_stable_config_path(), _store.get_storage_path(_session_config_path())]
	if _email_line_edit.text != _state.email:
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
	_sync_upload_controls()
	_tab_container.set_tab_disabled(BROWSER_TAB_PROFILE_INDEX, not _state.is_authenticated())
	_tab_container.set_tab_disabled(BROWSER_TAB_WORKOUT_INDEX, not _state.is_authenticated())
	_tab_container.set_tab_disabled(BROWSER_TAB_SUBSCRIBED_INDEX, not _state.is_authenticated())
	_tab_container.set_tab_disabled(BROWSER_TAB_UPLOAD_INDEX, not _state.is_authenticated())
	_sync_browser_tab_selection()

func _build_auth_state_text() -> String:
	var lines := PackedStringArray()
	lines.append("Server: %s" % _state.environment.capitalize())
	lines.append("Session path: %s" % _store.get_storage_path(_session_config_path()))
	lines.append("Athlete email: %s" % (_state.email if not _state.email.is_empty() else "(not saved yet)"))
	if _state.is_authenticated():
		lines.append("Access token loaded: yes")
		lines.append("User ID: %s" % (_state.user_id if not _state.user_id.is_empty() else "(will refresh from /me)"))
		if _state.has_access_token_expiry():
			lines.append("Saved token expiry: %s%s" % [_format_unix_timestamp(_state.access_token_expires_at), " (expired)" if _state.is_access_token_expired() else ""])
		else:
			lines.append("Saved token expiry: unknown (provider did not return date_expires)")
	else:
		lines.append("Access token loaded: no")
	var restore_note := str(_state.raw_debug_sections.get("saved_token_restore_note", "")).strip_edges()
	if not restore_note.is_empty():
		lines.append(restore_note)
	return "\n".join(lines)

func _read_saved_access_token_expiry(environment: String, session_config_path: String) -> int:
	var raw_expiry := _store.read_env_value(environment, "access_token_expires_at", session_config_path)
	if raw_expiry.is_empty() or not raw_expiry.is_valid_int():
		return 0
	return maxi(0, int(raw_expiry))

func _format_unix_timestamp(value: int) -> String:
	if value <= 0:
		return "(unknown)"
	return Time.get_datetime_string_from_unix_time(value, true)

func _build_saved_token_restore_note() -> String:
	if not _state.is_authenticated():
		return ""
	if _state.is_access_token_expired():
		return "Stored token expired at %s." % _format_unix_timestamp(_state.access_token_expires_at)
	if _state.has_access_token_expiry():
		return "Stored token detected. Rehydrating /me + wallet + purchases on reopen before the saved expiry of %s." % _format_unix_timestamp(_state.access_token_expires_at)
	return "Stored token detected. Rehydrating /me + wallet + purchases on reopen, but no saved expiry metadata is available."

func _is_clearly_token_related_failure(response: Dictionary) -> bool:
	var error_payload = response.get("error", {})
	if error_payload is Dictionary:
		if bool(error_payload.get("should_clear_session", false)):
			return true
		if str(error_payload.get("category", "")) == "auth" and int(response.get("status_code", 0)) in [401, 403]:
			return true
		var message := str(error_payload.get("message", "")).to_lower()
		if int(response.get("status_code", 0)) in [401, 403] and (message.contains("token") or message.contains("expired") or message.contains("unauthor")):
			return true
	return false

func _invalidate_saved_auth(reason: String, clear_persisted_state: bool) -> void:
	var preserved_email := _state.email
	var preserved_last_requested_email := _state.last_requested_email
	_state.clear_session()
	_state.email = preserved_email
	_state.last_requested_email = preserved_last_requested_email
	_state.raw_debug_sections["saved_token_restore_note"] = reason.strip_edges()
	if clear_persisted_state:
		_store.clear_session_values(_state.environment, PackedStringArray(["access_token", "access_token_expires_at", "user_id"]), _session_config_path())
	_rebuild_manager()

func _restore_saved_runtime_state() -> void:
	if is_instance_valid(_global_tab_container):
		_global_tab_container.current_tab = GLOBAL_TAB_BROWSER_INDEX
	if _state.can_browse_public():
		_fetch_listing(ModioWorkoutBrowserState.TAB_PUBLIC)
	if _state.is_authenticated() and _state.is_access_token_expired():
		_invalidate_saved_auth("Stored token expired at %s, so saved athlete auth was cleared before restore." % _format_unix_timestamp(_state.access_token_expires_at), true)
		_refresh_all_ui()
		return
	if _state.is_authenticated():
		_refresh_profile_data(false, true)

func _persist_session_state(extra_values: Dictionary = {}) -> Dictionary:
	var values := {
		"access_token": _state.access_token,
		"access_token_expires_at": str(_state.access_token_expires_at),
		"user_id": _state.user_id,
		"email": _state.email,
		"last_requested_email": _state.last_requested_email,
		"browser_tab": _state.active_tab
	}
	values.merge(extra_values, true)
	return _store.save_session_values(_state.environment, values, _session_config_path())

func _sync_browser_tab_selection() -> void:
	if not is_instance_valid(_tab_container):
		return
	var target_index := _browser_tab_index_for_context(_state.active_tab)
	if not _state.is_authenticated() and target_index != BROWSER_TAB_PUBLIC_INDEX:
		target_index = BROWSER_TAB_PUBLIC_INDEX
	if _tab_container.current_tab != target_index:
		_tab_container.current_tab = target_index

func _sync_upload_controls() -> void:
	if not is_instance_valid(_upload_name_line_edit):
		return
	var draft: Dictionary = _state.upload_draft
	_upload_name_line_edit.text = str(draft.get("name", ""))
	_upload_name_id_line_edit.text = str(draft.get("name_id", ""))
	_upload_summary_line_edit.text = str(draft.get("summary", ""))
	_upload_description_text_edit.text = str(draft.get("description", ""))
	_upload_metadata_text_edit.text = str(draft.get("metadata_kvp", ""))
	_upload_tags_line_edit.text = str(draft.get("tags", ""))
	_upload_logo_path_line_edit.text = str(draft.get("logo_path", ""))
	_upload_zip_path_line_edit.text = str(draft.get("zip_path", ""))
	_upload_version_line_edit.text = str(draft.get("version", ""))
	_upload_changelog_text_edit.text = str(draft.get("changelog", ""))
	_upload_publish_checkbox.button_pressed = bool(draft.get("publish_after_upload", false))
	_upload_submit_button.disabled = not _state.is_authenticated()
	var auth_truth := "Athlete sign-in is required. This tab stays disabled until the email-code flow resolves a bearer token."
	if _state.is_authenticated():
		auth_truth = "This staged authoring flow uses the signed-in athlete bearer. It creates a draft mod first, uploads the workout ZIP as the latest modfile second, and only publishes if you opt in below."
	_upload_intro_label.text = auth_truth
	_upload_status_label.text = _state.upload_status_text if not _state.upload_status_text.is_empty() else "Provide a workout name, required metadata entries, a required logo file, and a required workout ZIP before running the staged upload."
	_upload_result_label.text = _format_upload_result(_state.upload_result)

func _browser_tab_index_for_context(context: String) -> int:
	match context:
		ModioWorkoutBrowserState.TAB_PROFILE:
			return BROWSER_TAB_PROFILE_INDEX
		ModioWorkoutBrowserState.TAB_WORKOUT:
			return BROWSER_TAB_WORKOUT_INDEX
		ModioWorkoutBrowserState.TAB_SUBSCRIBED:
			return BROWSER_TAB_SUBSCRIBED_INDEX
		ModioWorkoutBrowserState.TAB_UPLOAD:
			return BROWSER_TAB_UPLOAD_INDEX
		_:
			return BROWSER_TAB_PUBLIC_INDEX

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

func _read_upload_form_from_controls() -> Dictionary:
	return {
		"name": _upload_name_line_edit.text.strip_edges(),
		"name_id": _upload_name_id_line_edit.text.strip_edges(),
		"summary": _upload_summary_line_edit.text.strip_edges(),
		"description": _upload_description_text_edit.text.strip_edges(),
		"metadata_kvp": _upload_metadata_text_edit.text.strip_edges(),
		"tags": _upload_tags_line_edit.text.strip_edges(),
		"logo_path": _upload_logo_path_line_edit.text.strip_edges(),
		"zip_path": _upload_zip_path_line_edit.text.strip_edges(),
		"version": _upload_version_line_edit.text.strip_edges(),
		"changelog": _upload_changelog_text_edit.text.strip_edges(),
		"publish_after_upload": _upload_publish_checkbox.button_pressed
	}

func _format_upload_result(result: Dictionary) -> String:
	if result.is_empty():
		return ""
	var lines := PackedStringArray()
	lines.append("[b]Last Upload Attempt[/b]")
	lines.append("Status: %s" % ("ok" if bool(result.get("ok", false)) else "failed"))
	if not str(result.get("message", "")).is_empty():
		lines.append("Message: %s" % str(result.get("message", "")))
	if int(result.get("mod_id", 0)) > 0:
		lines.append("Mod ID: %s" % str(result.get("mod_id", 0)))
	if int(result.get("file_id", 0)) > 0:
		lines.append("File ID: %s" % str(result.get("file_id", 0)))
	var steps: Array = result.get("steps", [])
	if not steps.is_empty():
		var step_bits := PackedStringArray()
		for step in steps:
			if step is Dictionary:
				step_bits.append("%s=%s" % [str(step.get("stage", "step")), "ok" if bool(step.get("ok", false)) else "failed"])
		lines.append("Steps: %s" % ", ".join(step_bits))
	return "\n".join(lines)

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
			return "Saved connection values auto-load the public catalog on reopen; otherwise apply connection values and fetch public workouts."

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

func _placeholder_texture(_text: String) -> Texture2D:
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
	_detail_entry = entry.duplicate(true)
	_state.selected_mod_id = int(entry.get("id", 0))
	_state.selected_mod_context = context
	_detail_title_label.text = str(entry.get("name", "Workout"))
	_detail_summary_label.text = _detail_bbcode(entry)
	_detail_status_label.text = ""
	_set_preview_texture(_detail_image, entry)
	_apply_detail_download_state(entry)
	_apply_detail_action_state(entry, context)
	_detail_overlay.visible = true

func _detail_bbcode(entry: Dictionary) -> String:
	var tags := PackedStringArray()
	for tag in entry.get("tags", []):
		if tag is Dictionary:
			tags.append(str(tag.get("name", tag.get("tag", ""))))
		else:
			tags.append(str(tag))
	var metadata_pairs := PackedStringArray()
	var metadata = entry.get("metadata_kvp", [])
	if metadata is Dictionary:
		for key in metadata.keys():
			metadata_pairs.append("%s=%s" % [str(key), JSON.stringify(metadata[key])])
	elif metadata is Array:
		for item in metadata:
			if item is Dictionary:
				var key := str(item.get("metakey", item.get("key", "")))
				var value = item.get("metavalue", item.get("value", ""))
				if key.is_empty() and item.has("name"):
					key = str(item.get("name", ""))
				metadata_pairs.append("%s=%s" % [key, JSON.stringify(value)])
			else:
				metadata_pairs.append(str(item))
	var modfile: Dictionary = entry.get("modfile", {})
	var filehash: Dictionary = modfile.get("filehash", {}) if modfile is Dictionary else {}
	return "\n".join([
		"[b]Summary[/b]\n%s" % str(entry.get("summary", "")),
		"[b]Description[/b]\n%s" % str(entry.get("description_plaintext", entry.get("description", ""))),
		"[b]Tags[/b] %s" % (", ".join(tags) if not tags.is_empty() else "(none)"),
		"[b]Downloads[/b] %s" % str(entry.get("stats", {}).get("downloads_total", 0)),
		"[b]Subscribers[/b] %s" % str(entry.get("stats", {}).get("subscribers_total", 0)),
		"[b]Latest File[/b] %s" % str(modfile.get("filename", "(not exposed on this entry)")),
		"[b]Expected MD5[/b] %s" % str(filehash.get("md5", "(not exposed)")),
		"[b]Price[/b] %s | [b]Tax[/b] %s" % [str(entry.get("price", 0)), str(entry.get("tax", 0))],
		"[b]Metadata[/b] %s" % ("; ".join(metadata_pairs) if not metadata_pairs.is_empty() else "(none)"),
		"[b]Profile URL[/b] %s" % str(entry.get("profile_url", ""))
	])

func _apply_detail_action_state(entry: Dictionary, context: String) -> void:
	var mod_id := int(entry.get("id", 0))
	var is_subscribed := context == ModioWorkoutBrowserState.TAB_SUBSCRIBED or _is_mod_in_listing(ModioWorkoutBrowserState.TAB_SUBSCRIBED, mod_id)
	if is_subscribed:
		_detail_action_mode = DETAIL_ACTION_UNSUBSCRIBE
		_detail_action_button.visible = true
		_detail_action_button.disabled = not _state.is_authenticated()
		_detail_action_button.text = "Unsubscribe"
		if not _state.is_authenticated():
			_detail_status_label.text = "This workout appears in subscribed state, but this session needs athlete auth before it can send unsubscribe writes."
		return
	if mod_id <= 0:
		_detail_action_mode = ""
		_detail_action_button.visible = true
		_detail_action_button.disabled = true
		_detail_action_button.text = "Subscribe Unavailable"
		_detail_status_label.text = "This workout is missing a valid mod id, so subscribe is unavailable."
		return
	_detail_action_mode = DETAIL_ACTION_SUBSCRIBE
	_detail_action_button.visible = true
	_detail_action_button.text = "Subscribe"
	_detail_action_button.disabled = not _state.is_authenticated()
	if not _state.is_authenticated():
		_detail_status_label.text = "Authenticate with the email-code flow to subscribe from public or athlete browser details."

func _apply_detail_download_state(entry: Dictionary) -> void:
	var modfile: Dictionary = entry.get("modfile", {}) if entry.get("modfile", null) is Dictionary else {}
	var filename := str(modfile.get("filename", "workout.zip")).strip_edges()
	if filename.is_empty():
		filename = "workout-%s.zip" % str(entry.get("id", "download"))
	var default_path := _default_download_path(filename)
	if _detail_download_path_line_edit.text.strip_edges().is_empty() or _detail_download_path_line_edit.text.begins_with(ProjectSettings.globalize_path(DOWNLOAD_CACHE_DIR)):
		_detail_download_path_line_edit.text = default_path
	var has_download_metadata := not str(modfile.get("download", {}).get("binary_url", "")).is_empty()
	_detail_download_button.disabled = not has_download_metadata
	_detail_download_hint_label.text = "Each download uses a fresh mod.io delivery URL and saves to the exact ZIP path you choose. The hashed binary_url is treated as expiring transport, not a permanent link."
	if not has_download_metadata:
		_detail_download_hint_label.text += "\nThis entry does not currently expose modfile download metadata, so Download stays disabled."

func _default_download_path(filename: String) -> String:
	var download_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if download_dir.is_empty():
		download_dir = ProjectSettings.globalize_path(DOWNLOAD_CACHE_DIR)
	DirAccess.make_dir_recursive_absolute(download_dir)
	return download_dir.path_join(filename)

func _is_mod_in_listing(context: String, mod_id: int) -> bool:
	if mod_id <= 0:
		return false
	for entry in _state.listing_for_context(context).get("data", []):
		if entry is Dictionary and int(entry.get("id", 0)) == mod_id:
			return true
	return false

func _close_detail_overlay() -> void:
	_detail_overlay.visible = false
	_detail_action_button.disabled = false
	_detail_download_button.disabled = false
	_detail_status_label.text = ""
	_detail_action_mode = ""
	_detail_entry = {}

func _on_detail_action_pressed() -> void:
	if _state.selected_mod_id <= 0:
		return
	if not _state.is_authenticated():
		_detail_status_label.text = "Authenticate first."
		return
	_rebuild_manager()
	var response: Dictionary
	if _detail_action_mode == DETAIL_ACTION_UNSUBSCRIBE:
		response = _manager.execute_adapter_request("build_unsubscribe_request", [str(_state.selected_mod_id)])
		if bool(response.get("ok", false)):
			_state.remove_subscribed_mod(_state.selected_mod_id)
			_state.selected_mod_context = ModioWorkoutBrowserState.TAB_PUBLIC
			_detail_status_label.text = "Unsubscribed successfully. Removed from the subscribed list immediately."
			_update_listing_ui(ModioWorkoutBrowserState.TAB_SUBSCRIBED)
			_update_profile_ui()
			_apply_detail_action_state(_detail_entry, ModioWorkoutBrowserState.TAB_PUBLIC)
			return
		_detail_status_label.text = _response_error_message(response, "Failed to unsubscribe.")
		return
	response = _manager.execute_adapter_request("build_subscribe_request", [str(_state.selected_mod_id), false])
	if bool(response.get("ok", false)):
		var normalized = _manager.normalize_with_adapter("normalize_subscription_write_response", [int(response.get("status_code", 0)), response.get("headers", {}), response.get("payload", {})])
		var already := bool(normalized.get("already_subscribed", false)) if normalized is Dictionary else false
		_state.selected_mod_context = ModioWorkoutBrowserState.TAB_SUBSCRIBED
		_detail_status_label.text = "Already subscribed." if already else "Subscribed successfully."
		_apply_detail_action_state(_detail_entry, ModioWorkoutBrowserState.TAB_SUBSCRIBED)
		return
	_detail_status_label.text = _response_error_message(response, "Failed to subscribe.")

func _on_detail_download_browse_pressed() -> void:
	if not is_instance_valid(_detail_file_dialog):
		return
	_detail_file_dialog.current_path = _detail_download_path_line_edit.text.strip_edges()
	_detail_file_dialog.popup_centered_ratio(0.6)

func _on_detail_download_path_selected(path: String) -> void:
	_detail_download_path_line_edit.text = path

func _on_detail_download_pressed() -> void:
	await _download_selected_mod()

func _download_selected_mod() -> void:
	if _state.selected_mod_id <= 0:
		_detail_status_label.text = "Open a workout detail before attempting a download."
		return
	var requested_path := _detail_download_path_line_edit.text.strip_edges()
	if requested_path.is_empty():
		_detail_status_label.text = "Choose a destination ZIP path before downloading."
		return
	_detail_download_button.disabled = true
	_detail_status_label.text = "Resolving a fresh modfile URL from mod.io…"
	var detail_entry := _fetch_fresh_detail_entry(str(_state.selected_mod_id))
	if detail_entry.is_empty():
		_detail_download_button.disabled = false
		if _detail_status_label.text.is_empty():
			_detail_status_label.text = "Failed to refresh workout detail before downloading."
		return
	var modfile: Dictionary = detail_entry.get("modfile", {})
	if modfile.is_empty():
		_detail_download_button.disabled = false
		_detail_status_label.text = "mod.io did not expose a latest modfile for this workout, so Download cannot continue yet."
		return
	var download_request_obj = _manager.get_adapter().resolve_download_request_from_modfile(str(_state.selected_mod_id), modfile)
	if download_request_obj == null or not download_request_obj.is_valid():
		_detail_download_button.disabled = false
		_detail_status_label.text = "This workout does not currently expose a valid expiring download URL."
		return
	var download_metadata: Dictionary = _manager.get_adapter().build_download_request(download_request_obj)
	var save_path := _normalize_download_target_path(requested_path, str(download_metadata.get("filename", "workout.zip")))
	var result := await _download_binary_to_path(download_metadata, save_path)
	_detail_download_button.disabled = false
	if bool(result.get("ok", false)):
		_detail_download_path_line_edit.text = save_path
		var md5_message := ""
		if bool(result.get("checked_md5", false)):
			md5_message = " MD5 %s." % ("matched" if bool(result.get("md5_matches", false)) else "did not match")
		_detail_status_label.text = "Saved %s to %s.%s" % [str(download_metadata.get("filename", "workout.zip")), save_path, md5_message]
		return
	_detail_status_label.text = str(result.get("message", "Download failed."))

func _fetch_fresh_detail_entry(mod_id: String) -> Dictionary:
	_rebuild_manager()
	var response: Dictionary = _manager.execute_adapter_request("build_mod_detail_request", [mod_id])
	if not bool(response.get("ok", false)):
		_detail_status_label.text = _response_error_message(response, "Failed to refresh workout detail before downloading.")
		return {}
	var normalized = _manager.normalize_with_adapter("normalize_mod_detail_response", [response.get("payload", {})])
	if normalized is Dictionary:
		return normalized
	_detail_status_label.text = "Failed to normalize the refreshed workout detail response."
	return {}

func _normalize_download_target_path(path: String, filename: String) -> String:
	var cleaned := path.strip_edges()
	if cleaned.is_empty():
		return _default_download_path(filename)
	if cleaned.ends_with("/") or cleaned.ends_with("\\"):
		return cleaned.path_join(filename)
	if cleaned.get_extension().is_empty():
		return "%s.zip" % cleaned
	return cleaned

func _download_binary_to_path(download_metadata: Dictionary, save_path: String) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var request_error := http.request(str(download_metadata.get("binary_url", "")))
	if request_error != OK:
		http.queue_free()
		return {"ok": false, "message": "Failed to start the download request (%s)." % request_error}
	var completed: Array = await http.request_completed
	var response_code := int(completed[1])
	var body: PackedByteArray = completed[3]
	if response_code < 200 or response_code >= 300:
		http.queue_free()
		return {"ok": false, "message": "Download request failed with HTTP %s." % response_code}
	var absolute_path := _absolute_filesystem_path(save_path)
	var parent_dir := absolute_path.get_base_dir()
	if not parent_dir.is_empty() and not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		http.queue_free()
		return {"ok": false, "message": "Failed to open %s for writing." % absolute_path}
	file.store_buffer(body)
	file.close()
	var expected_md5 := str(download_metadata.get("md5", "")).strip_edges().to_lower()
	var actual_md5 := _compute_md5(body)
	http.queue_free()
	if not expected_md5.is_empty() and actual_md5 != expected_md5:
		return {
			"ok": false,
			"message": "Saved the ZIP, but the md5 check failed. Expected %s, got %s." % [expected_md5, actual_md5],
			"checked_md5": true,
			"md5_matches": false,
			"actual_md5": actual_md5
		}
	return {
		"ok": true,
		"path": save_path,
		"checked_md5": not expected_md5.is_empty(),
		"md5_matches": true,
		"actual_md5": actual_md5
	}

func _absolute_filesystem_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path

func _compute_md5(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_MD5)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func _on_upload_logo_browse_pressed() -> void:
	if is_instance_valid(_upload_logo_file_dialog):
		_upload_logo_file_dialog.current_path = _upload_logo_path_line_edit.text.strip_edges()
		_upload_logo_file_dialog.popup_centered_ratio(0.6)

func _on_upload_zip_browse_pressed() -> void:
	if is_instance_valid(_upload_zip_file_dialog):
		_upload_zip_file_dialog.current_path = _upload_zip_path_line_edit.text.strip_edges()
		_upload_zip_file_dialog.popup_centered_ratio(0.6)

func _on_upload_logo_path_selected(path: String) -> void:
	_upload_logo_path_line_edit.text = path
	_state.upload_draft = _read_upload_form_from_controls()

func _on_upload_zip_path_selected(path: String) -> void:
	_upload_zip_path_line_edit.text = path
	_state.upload_draft = _read_upload_form_from_controls()

func _on_upload_workout_pressed() -> void:
	_state.upload_draft = _read_upload_form_from_controls()
	_state.active_tab = ModioWorkoutBrowserState.TAB_UPLOAD
	if not _state.is_authenticated():
		_state.upload_status_text = "Athlete sign-in is required before staged workout uploads can run."
		_state.upload_result = {"ok": false, "message": _state.upload_status_text}
		_set_status(_state.upload_status_text)
		_refresh_all_ui()
		return
	_rebuild_manager()
	var result: Dictionary = _upload_flow.submit_workout(_manager, _state.upload_draft)
	_state.upload_result = result
	_state.upload_status_text = str(result.get("message", "Workout upload attempt finished.")).strip_edges()
	_set_status(_state.upload_status_text)
	_refresh_all_ui()

func _on_request_code_pressed() -> void:
	var email := _email_line_edit.text.strip_edges()
	if email.is_empty():
		_set_status("Enter an email before requesting a security code.")
		return
	_state.email = email
	_state.last_requested_email = email
	_persist_session_state()
	_rebuild_manager()
	var response: Dictionary = _manager.execute_adapter_request("build_email_security_code_request", [email])
	if bool(response.get("ok", false)):
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
	var requested_expiry := Time.get_unix_time_from_system() + AUTH_TOKEN_REQUEST_MAX_SECONDS
	var response: Dictionary = _manager.execute_adapter_request("build_auth_exchange_request", [code, requested_expiry])
	if not bool(response.get("ok", false)):
		_set_status(_response_error_message(response, "Failed to exchange the security code."))
		return
	var payload: Dictionary = response.get("payload", {})
	var normalized_token = _manager.normalize_with_adapter("normalize_access_token_response", [payload])
	_state.access_token = str(normalized_token.get("access_token", payload.get("access_token", ""))).strip_edges() if normalized_token is Dictionary else str(payload.get("access_token", "")).strip_edges()
	_state.access_token_expires_at = int(normalized_token.get("expires_at", payload.get("date_expires", 0))) if normalized_token is Dictionary else int(payload.get("date_expires", 0))
	_state.last_security_code = code
	_state.raw_debug_sections["auth_exchange"] = payload
	_state.raw_debug_sections["saved_token_restore_note"] = "Access token exchanged with the longest direct in-game expiry we can truthfully request (~1 year max). Saved expiry: %s. Refreshing /me + wallet + purchases now." % _format_unix_timestamp(_state.access_token_expires_at)
	_rebuild_manager()
	var persisted := _persist_session_state()
	if not bool(persisted.get("ok", false)):
		_set_status("Exchanged code, but failed to persist access_token to %s." % _store.get_storage_path(_session_config_path()))
		_refresh_all_ui()
		return
	_set_status("Access token stored in %s. Refreshing /me to resolve athlete identity..." % _store.get_storage_path(_session_config_path()))
	_refresh_profile_data(true)

func _on_clear_session_pressed() -> void:
	_state.clear_session()
	_state.email = ""
	_state.last_requested_email = ""
	_state.upload_status_text = ""
	_state.upload_result = {}
	_state.raw_debug_sections["saved_token_restore_note"] = ""
	_store.clear_session_values(_state.environment, PackedStringArray(["access_token", "access_token_expires_at", "user_id", "email", "last_requested_email", "browser_tab"]), _session_config_path())
	_rebuild_manager()
	_set_status("Cleared saved athlete email, access_token, access token expiry, user_id, and browser restore state from %s." % _store.get_storage_path(_session_config_path()))
	_refresh_all_ui()

func _on_profile_refresh_pressed() -> void:
	_refresh_profile_data(false, false)

func _refresh_profile_data(open_profile_tab: bool, restoring_saved_token: bool = false) -> void:
	if not _state.is_authenticated():
		_set_status("Profile refresh requires a valid access token.")
		_refresh_all_ui()
		return
	_rebuild_manager()
	var me_response: Dictionary = _manager.execute_adapter_request("build_authenticated_user_request")
	if not bool(me_response.get("ok", false)):
		if restoring_saved_token and _is_clearly_token_related_failure(me_response):
			var invalid_reason := "Stored token restore failed because mod.io rejected the saved bearer token%s. Saved athlete auth was cleared." % (" (it had expired at %s)" % _format_unix_timestamp(_state.access_token_expires_at) if _state.has_access_token_expiry() else "")
			_invalidate_saved_auth(invalid_reason, true)
			_set_status(_response_error_message(me_response, "Failed to load /me."))
			_refresh_all_ui()
			return
		_state.raw_debug_sections["saved_token_restore_note"] = "Stored token loaded from session config, but automatic /me refresh failed. Re-run email-code auth if this session is stale." if restoring_saved_token else ""
		_set_status(_response_error_message(me_response, "Failed to load /me."))
		_refresh_all_ui()
		return
	_state.profile = _manager.normalize_with_adapter("normalize_authenticated_user_response", [me_response.get("payload", {})])
	_state.raw_debug_sections["profile"] = me_response.get("payload", {})
	_state.user_id = str(_state.profile.get("id", _state.user_id))
	_persist_session_state()
	_rebuild_manager()
	var wallet_response: Dictionary = _manager.execute_adapter_request("build_user_wallet_request", [_state.game_id])
	if bool(wallet_response.get("ok", false)):
		_state.wallet = _manager.normalize_with_adapter("normalize_user_wallet_response", [wallet_response.get("payload", {})])
		_state.raw_debug_sections["wallet"] = wallet_response.get("payload", {})
	else:
		_state.wallet = {"error": _response_error_message(wallet_response, "Failed to load wallet.")}
	var purchased_response: Dictionary = _manager.execute_adapter_request("build_user_purchased_request", [_build_listing_query(ModioWorkoutBrowserState.TAB_WORKOUT)])
	if bool(purchased_response.get("ok", false)):
		_state.purchased = _manager.normalize_with_adapter("normalize_user_purchased_response", [purchased_response.get("payload", {})])
		_state.raw_debug_sections["purchased"] = purchased_response.get("payload", {})
	else:
		_state.purchased = {"error": _response_error_message(purchased_response, "Failed to load purchase history."), "data": []}
	_state.raw_debug_sections["saved_token_restore_note"] = "Stored token successfully rehydrated athlete profile, wallet, and purchase history on reopen. Saved expiry: %s." % _format_unix_timestamp(_state.access_token_expires_at) if restoring_saved_token else ""
	_set_status("Loaded athlete profile, wallet, and purchase history. Session values are stored in %s." % _store.get_storage_path(_session_config_path()))
	if open_profile_tab:
		_state.active_tab = ModioWorkoutBrowserState.TAB_PROFILE
	_refresh_all_ui()

func _update_profile_ui() -> void:
	if not _state.is_authenticated():
		_profile_summary_label.text = "Authenticate to inspect the athlete profile, wallet, and purchase history. Username/display-name edits stay out of scope because the current public REST seam does not support them."
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
	lines.append("Athlete email: %s" % (_state.email if not _state.email.is_empty() else "(not saved yet)"))
	lines.append("Profile editing: deferred/read-only via current REST seam")
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
		BROWSER_TAB_PROFILE_INDEX:
			_state.active_tab = ModioWorkoutBrowserState.TAB_PROFILE
		BROWSER_TAB_WORKOUT_INDEX:
			_state.active_tab = ModioWorkoutBrowserState.TAB_WORKOUT
		BROWSER_TAB_SUBSCRIBED_INDEX:
			_state.active_tab = ModioWorkoutBrowserState.TAB_SUBSCRIBED
		BROWSER_TAB_UPLOAD_INDEX:
			_state.active_tab = ModioWorkoutBrowserState.TAB_UPLOAD
		_:
			_state.active_tab = ModioWorkoutBrowserState.TAB_PUBLIC
	if _suspend_session_persistence:
		return
	_persist_session_state()

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
	_restore_saved_runtime_state()

func _truncate(value: String, max_chars: int) -> String:
	if value.length() <= max_chars:
		return value
	return "%s…" % value.substr(0, max_chars)

func _on_email_text_changed(new_text: String) -> void:
	_state.email = new_text.strip_edges()
	_auth_state_label.text = _build_auth_state_text()
