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

func _write_text(path: String, content: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	var parent_dir := global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(content)
