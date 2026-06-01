extends GutTest

const WorkoutBrowserScene := preload("res://scenes/workout_browser.tscn")
const SESSION_PATH := "user://modio_workout_browser_testbed_session.cfg"

var _session_backup_exists := false
var _session_backup_text := ""

class MockUploadFlow:
	extends RefCounted

	var calls: Array[Dictionary] = []
	var response: Dictionary = {
		"ok": true,
		"mod_id": 987,
		"file_id": 654,
		"publish_requested": true,
		"steps": [
			{"stage": "create_draft", "ok": true},
			{"stage": "upload_modfile", "ok": true},
			{"stage": "publish_mod", "ok": true}
		],
		"message": "Created draft mod 987 and uploaded modfile 654. Published the workout to the public catalog."
	}

	func submit_workout(manager, payload: Dictionary) -> Dictionary:
		calls.append({
			"manager": manager,
			"payload": payload.duplicate(true)
		})
		return response.duplicate(true)

func before_each() -> void:
	_session_backup_exists = FileAccess.file_exists(SESSION_PATH)
	if _session_backup_exists:
		var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
		_session_backup_text = file.get_as_text() if file != null else ""
	else:
		_session_backup_text = ""

func after_each() -> void:
	if _session_backup_exists:
		_write_text(SESSION_PATH, _session_backup_text)
	elif FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))

func _instantiate_scene() -> Control:
	var scene: Control = WorkoutBrowserScene.instantiate()
	scene.call("set_config_paths_for_testing", "", SESSION_PATH)
	return scene

func test_ready_restores_saved_email_without_wiping_session_values() -> void:
	_write_text(SESSION_PATH, "".join([
		"[modio]\n",
		"\n",
		"environment=\"test\"\n",
		"host_kind=\"\"\n",
		"\n",
		"[modio.test]\n",
		"\n",
		"access_token=\"qa-stale-token\"\n",
		"user_id=\"qa-user-id\"\n",
		"email=\"qa-athlete@example.com\"\n",
		"last_requested_email=\"qa-athlete@example.com\"\n",
		"browser_tab=\"profile\"\n"
	]))

	var scene: Control = _instantiate_scene()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var email_edit: LineEdit = scene.find_child("EmailLineEdit", true, false)
	var browser_state: ModioWorkoutBrowserState = scene.get("_state")
	assert_not_null(email_edit)
	assert_not_null(browser_state)
	assert_eq(email_edit.text, "qa-athlete@example.com")
	assert_eq(browser_state.email, "qa-athlete@example.com")
	assert_eq(browser_state.access_token, "qa-stale-token")
	assert_eq(browser_state.active_tab, "profile")

	scene.queue_free()
	await get_tree().process_frame

func test_public_listing_keeps_visible_card_viewport_after_ui_update() -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_TOP_LEFT)
	host.custom_minimum_size = Vector2(1440, 900)
	host.size = Vector2(1440, 900)
	get_tree().root.add_child(host)

	var scene: Control = _instantiate_scene()
	host.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var browser_state: ModioWorkoutBrowserState = scene.get("_state")
	assert_not_null(browser_state)
	browser_state.set_listing_for_context(ModioWorkoutBrowserState.TAB_PUBLIC, {
		"data": [_sample_mod_entry(101), _sample_mod_entry(102)],
		"result_count": 2,
		"result_offset": 0,
		"result_limit": 9,
		"result_total": 2,
		"page": {
			"count": 2,
			"offset": 0,
			"limit": 9,
			"total": 2,
			"has_next": false,
			"has_previous": false,
			"next_offset": -1,
			"previous_offset": -1,
			"page_index": 0,
			"page_count": 1
		}
	})
	scene.call("_update_listing_ui", ModioWorkoutBrowserState.TAB_PUBLIC)
	await get_tree().process_frame
	await get_tree().process_frame

	var cards_grid: GridContainer = scene.find_child("PublicCardsGrid", true, false)
	assert_not_null(cards_grid)
	assert_eq(cards_grid.get_child_count(), 2)

	var listing_scroll: ScrollContainer = scene.find_child("PublicCardsGridScroll", true, false)
	assert_not_null(listing_scroll)
	assert_true(cards_grid.get_child(0) is Control)
	assert_gt((cards_grid.get_child(0) as Control).custom_minimum_size.y, 0.0)

	host.queue_free()
	await get_tree().process_frame

func test_public_detail_cta_depends_on_auth_and_subscription_state() -> void:
	var scene: Control = _instantiate_scene()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var browser_state: ModioWorkoutBrowserState = scene.get("_state")
	assert_not_null(browser_state)
	var detail_action: Button = scene.find_child("DetailActionButton", true, false)
	var detail_status: Label = scene.find_child("DetailStatusLabel", true, false)
	assert_not_null(detail_action)
	assert_not_null(detail_status)
	browser_state.access_token = ""

	scene.call("_open_detail", _sample_mod_entry(321), ModioWorkoutBrowserState.TAB_PUBLIC)
	await get_tree().process_frame
	assert_true(detail_action.visible)
	assert_eq(detail_action.text, "Subscribe")
	assert_true(detail_action.disabled)
	assert_string_contains(detail_status.text, "Authenticate")

	browser_state.access_token = "qa-token"
	scene.call("_open_detail", _sample_mod_entry(321), ModioWorkoutBrowserState.TAB_PUBLIC)
	await get_tree().process_frame
	assert_false(detail_action.disabled)
	assert_eq(detail_action.text, "Subscribe")

	browser_state.set_listing_for_context(ModioWorkoutBrowserState.TAB_SUBSCRIBED, {
		"data": [_sample_mod_entry(321)],
		"result_count": 1,
		"result_offset": 0,
		"result_limit": 9,
		"result_total": 1,
		"page": {
			"count": 1,
			"offset": 0,
			"limit": 9,
			"total": 1,
			"has_next": false,
			"has_previous": false,
			"next_offset": -1,
			"previous_offset": -1,
			"page_index": 0,
			"page_count": 1
		}
	})
	scene.call("_open_detail", _sample_mod_entry(321), ModioWorkoutBrowserState.TAB_PUBLIC)
	await get_tree().process_frame
	assert_eq(detail_action.text, "Unsubscribe")
	assert_false(detail_action.disabled)

	scene.queue_free()
	await get_tree().process_frame

func test_detail_slideout_exposes_download_controls() -> void:
	var scene: Control = _instantiate_scene()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var detail_panel: PanelContainer = scene.find_child("DetailPanel", true, false)
	var detail_path: LineEdit = scene.find_child("DetailDownloadPathLineEdit", true, false)
	var detail_download: Button = scene.find_child("DetailDownloadButton", true, false)
	var detail_browse: Button = scene.find_child("DetailDownloadBrowseButton", true, false)
	assert_not_null(detail_panel)
	assert_not_null(detail_path)
	assert_not_null(detail_download)
	assert_not_null(detail_browse)
	assert_eq(detail_panel.get_parent().name, "DetailDockRow")

	scene.call("_open_detail", _sample_mod_entry(777), ModioWorkoutBrowserState.TAB_PUBLIC)
	await get_tree().process_frame
	assert_false(detail_download.disabled)
	assert_true(detail_path.text.ends_with("fixture-777.zip"))

	scene.queue_free()
	await get_tree().process_frame

func test_upload_tab_is_auth_gated_and_exposes_required_path_controls() -> void:
	var scene: Control = _instantiate_scene()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var browser_state: ModioWorkoutBrowserState = scene.get("_state")
	assert_not_null(browser_state)
	browser_state.access_token = ""
	scene.call("_refresh_all_ui")
	await get_tree().process_frame

	var tab_container: TabContainer = scene.find_child("BrowserTabContainer", true, false)
	var upload_scroll: ScrollContainer = scene.find_child("UploadWorkoutScroll", true, false)
	var summary_description_row: HBoxContainer = scene.find_child("UploadWorkoutSummaryDescriptionRow", true, false)
	var metadata_tags_row: HBoxContainer = scene.find_child("UploadWorkoutMetadataTagsRow", true, false)
	var file_row: HBoxContainer = scene.find_child("UploadWorkoutFileRow", true, false)
	var upload_name: LineEdit = scene.find_child("UploadWorkoutNameLineEdit", true, false)
	var upload_logo: LineEdit = scene.find_child("UploadWorkoutLogoPathLineEdit", true, false)
	var upload_zip: LineEdit = scene.find_child("UploadWorkoutZipPathLineEdit", true, false)
	var upload_button: Button = scene.find_child("UploadWorkoutSubmitButton", true, false)
	assert_not_null(tab_container)
	assert_eq(tab_container.get_tab_title(4), "Upload Workout")
	assert_true(tab_container.is_tab_disabled(4))
	assert_not_null(upload_scroll)
	assert_not_null(summary_description_row)
	assert_eq(summary_description_row.get_child_count(), 2)
	assert_not_null(metadata_tags_row)
	assert_eq(metadata_tags_row.get_child_count(), 2)
	assert_not_null(file_row)
	assert_eq(file_row.get_child_count(), 2)
	assert_not_null(upload_name)
	assert_not_null(upload_logo)
	assert_not_null(upload_zip)
	assert_not_null(upload_button)
	assert_true(upload_button.disabled)

	scene.queue_free()
	await get_tree().process_frame

func test_upload_submit_invokes_reusable_flow_and_reports_result() -> void:
	var scene: Control = _instantiate_scene()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var browser_state: ModioWorkoutBrowserState = scene.get("_state")
	assert_not_null(browser_state)
	browser_state.game_id = "777"
	browser_state.api_key = "demo-key"
	browser_state.access_token = "qa-token"
	browser_state.active_tab = ModioWorkoutBrowserState.TAB_UPLOAD
	var mock_flow := MockUploadFlow.new()
	scene.set("_upload_flow", mock_flow)
	scene.call("_refresh_all_ui")
	await get_tree().process_frame

	var upload_name: LineEdit = scene.find_child("UploadWorkoutNameLineEdit", true, false)
	var upload_summary: LineEdit = scene.find_child("UploadWorkoutSummaryLineEdit", true, false)
	var upload_metadata: TextEdit = scene.find_child("UploadWorkoutMetadataTextEdit", true, false)
	var upload_logo: LineEdit = scene.find_child("UploadWorkoutLogoPathLineEdit", true, false)
	var upload_zip: LineEdit = scene.find_child("UploadWorkoutZipPathLineEdit", true, false)
	var upload_publish: CheckBox = scene.find_child("UploadWorkoutPublishCheckBox", true, false)
	var upload_button: Button = scene.find_child("UploadWorkoutSubmitButton", true, false)
	var upload_status: Label = scene.find_child("UploadWorkoutStatusLabel", true, false)
	var upload_result: RichTextLabel = scene.find_child("UploadWorkoutResultLabel", true, false)
	assert_not_null(upload_name)
	assert_not_null(upload_summary)
	assert_not_null(upload_metadata)
	assert_not_null(upload_logo)
	assert_not_null(upload_zip)
	assert_not_null(upload_publish)
	assert_not_null(upload_button)
	assert_not_null(upload_status)
	assert_not_null(upload_result)
	assert_false(upload_button.disabled)

	upload_name.text = "Tempo Ladder"
	upload_summary.text = "Climb intervals"
	upload_metadata.text = "difficulty=hard\ncoach=chip"
	upload_logo.text = "/tmp/tempo-ladder-logo.png"
	upload_zip.text = "/tmp/tempo-ladder.zip"
	upload_publish.button_pressed = true
	upload_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_eq(mock_flow.calls.size(), 1)
	assert_eq(mock_flow.calls[0].payload.name, "Tempo Ladder")
	assert_eq(mock_flow.calls[0].payload.summary, "Climb intervals")
	assert_eq(mock_flow.calls[0].payload.metadata_kvp, "difficulty=hard\ncoach=chip")
	assert_eq(mock_flow.calls[0].payload.logo_path, "/tmp/tempo-ladder-logo.png")
	assert_eq(mock_flow.calls[0].payload.zip_path, "/tmp/tempo-ladder.zip")
	assert_true(mock_flow.calls[0].payload.publish_after_upload)
	assert_string_contains(upload_status.text, "Created draft mod 987")
	assert_string_contains(upload_result.text, "Mod ID: 987")
	assert_string_contains(upload_result.text, "publish_mod=ok")

	scene.queue_free()
	await get_tree().process_frame

func _sample_mod_entry(mod_id: int) -> Dictionary:
	return {
		"id": mod_id,
		"name": "Workout %d" % mod_id,
		"summary": "Regression fixture card %d" % mod_id,
		"description_plaintext": "Regression fixture card %d description" % mod_id,
		"stats": {
			"downloads_total": mod_id,
			"subscribers_total": mod_id + 1
		},
		"logo": {},
		"media": {
			"images": []
		},
		"modfile": {
			"id": mod_id + 5000,
			"filename": "fixture-%d.zip" % mod_id,
			"filehash": {"md5": "fixture-md5-%d" % mod_id},
			"download": {
				"binary_url": "https://example.invalid/download/%d" % mod_id,
				"date_expires": 4102444800
			}
		},
		"tags": [],
		"metadata_kvp": [],
		"profile_url": "https://example.invalid/mod/%d" % mod_id
	}

func _write_text(path: String, content: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	var parent_dir := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(content)
