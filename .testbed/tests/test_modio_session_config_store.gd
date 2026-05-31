extends GutTest

const ModioSessionConfigStore = preload("res://scripts/modio_session_config_store.gd")

const SESSION_PATH := "user://modio_session_config_store.cfg"

func after_each() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))

func test_save_session_values_persists_environment_and_token() -> void:
	var store := ModioSessionConfigStore.new()
	var result := store.save_session_values("live", {
		"access_token": "live-token",
		"user_id": "4444"
	}, SESSION_PATH)

	assert_true(result.ok)
	assert_eq(store.read_environment(SESSION_PATH), "live")
	assert_eq(store.read_env_value("live", "access_token", SESSION_PATH), "live-token")
	assert_eq(store.read_env_value("live", "user_id", SESSION_PATH), "4444")

func test_clear_session_values_removes_only_requested_keys() -> void:
	var store := ModioSessionConfigStore.new()
	store.save_session_values("test", {
		"access_token": "test-token",
		"user_id": "2222",
		"note": "keep-me"
	}, SESSION_PATH)

	var result := store.clear_session_values("test", PackedStringArray(["access_token", "user_id"]), SESSION_PATH)

	assert_true(result.ok)
	assert_eq(store.read_env_value("test", "access_token", SESSION_PATH), "")
	assert_eq(store.read_env_value("test", "user_id", SESSION_PATH), "")
	assert_eq(store.read_env_value("test", "note", SESSION_PATH), "keep-me")
