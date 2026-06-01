extends GutTest

const ModioSessionConfigStore = preload("res://scripts/modio_session_config_store.gd")

const SESSION_PATH := "user://modio_session_config_store.cfg"

func after_each() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))

func test_save_session_values_persists_environment_token_and_email() -> void:
	var store := ModioSessionConfigStore.new()
	var result := store.save_session_values("live", {
		"access_token": "live-token",
		"access_token_expires_at": "4102444800",
		"user_id": "4444",
		"email": "athlete@example.com",
		"browser_tab": "profile"
	}, SESSION_PATH)

	assert_true(result.ok)
	assert_eq(store.read_environment(SESSION_PATH), "live")
	assert_eq(store.read_env_value("live", "access_token", SESSION_PATH), "live-token")
	assert_eq(store.read_env_value("live", "access_token_expires_at", SESSION_PATH), "4102444800")
	assert_eq(store.read_env_value("live", "user_id", SESSION_PATH), "4444")
	assert_eq(store.read_env_value("live", "email", SESSION_PATH), "athlete@example.com")
	assert_eq(store.read_env_value("live", "browser_tab", SESSION_PATH), "profile")

func test_clear_session_values_removes_only_requested_keys() -> void:
	var store := ModioSessionConfigStore.new()
	store.save_session_values("test", {
		"access_token": "test-token",
		"user_id": "2222",
		"note": "keep-me"
	}, SESSION_PATH)

	var result := store.clear_session_values("test", PackedStringArray(["access_token", "user_id", "email"]), SESSION_PATH)

	assert_true(result.ok)
	assert_eq(store.read_env_value("test", "access_token", SESSION_PATH), "")
	assert_eq(store.read_env_value("test", "user_id", SESSION_PATH), "")
	assert_eq(store.read_env_value("test", "email", SESSION_PATH), "")
	assert_eq(store.read_env_value("test", "note", SESSION_PATH), "keep-me")
