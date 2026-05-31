extends GutTest

const WorkoutBrowserScene := preload("res://scenes/workout_browser.tscn")
const ModioSessionConfigStore = preload("res://scripts/modio_session_config_store.gd")
const SESSION_PATH := "res://configs/modio.session.local.cfg"

var _session_backup_exists := false
var _session_backup_text := ""

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

	var scene: Control = WorkoutBrowserScene.instantiate()
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var store := ModioSessionConfigStore.new()
	var email_edit: LineEdit = scene.find_child("EmailLineEdit", true, false)
	assert_not_null(email_edit)
	assert_eq(email_edit.text, "qa-athlete@example.com")
	assert_eq(store.read_env_value("test", "email", SESSION_PATH), "qa-athlete@example.com")
	assert_eq(store.read_env_value("test", "access_token", SESSION_PATH), "qa-stale-token")
	assert_eq(store.read_env_value("test", "browser_tab", SESSION_PATH), "profile")

	scene.queue_free()
	await get_tree().process_frame

func test_public_listing_keeps_visible_card_viewport_after_ui_update() -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_TOP_LEFT)
	host.custom_minimum_size = Vector2(1440, 900)
	host.size = Vector2(1440, 900)
	get_tree().root.add_child(host)

	var scene: Control = WorkoutBrowserScene.instantiate()
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
	assert_gt(listing_scroll.size.y, 0.0)
	assert_gt(listing_scroll.get_rect().size.y, 0.0)
	assert_gt(cards_grid.get_child(0).size.y, 0.0)

	host.queue_free()
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
