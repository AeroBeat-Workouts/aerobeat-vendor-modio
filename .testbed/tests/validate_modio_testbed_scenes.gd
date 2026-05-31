extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/workout_browser.tscn"
const SMOKE_SCENE_PATHS := [
	"res://scenes/public_catalog_testbed.tscn",
	"res://scenes/authenticated_user_testbed.tscn",
	"res://scenes/safe_write_testbed.tscn",
	"res://scenes/paid_mods_testbed.tscn"
]

func _initialize() -> void:
	var failures: PackedStringArray = []
	_validate_main_scene(failures)
	_validate_smoke_scenes(failures)

	if failures.is_empty():
		print("Mod.io testbed scene validation passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
		print(failure)
	quit(1)

func _validate_main_scene(failures: PackedStringArray) -> void:
	var configured_main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if configured_main_scene != MAIN_SCENE_PATH:
		failures.append("Expected application/run/main_scene to be %s, got %s" % [MAIN_SCENE_PATH, configured_main_scene])

	var packed_scene: PackedScene = load(MAIN_SCENE_PATH)
	if packed_scene == null:
		failures.append("Failed to load main scene: %s" % MAIN_SCENE_PATH)
		return
	var instance: Node = packed_scene.instantiate()
	if instance == null:
		failures.append("Failed to instantiate main scene: %s" % MAIN_SCENE_PATH)
		return
	root.add_child(instance)
	if not instance.has_method("describe_scene_surface"):
		failures.append("Main scene is missing describe_scene_surface(): %s" % MAIN_SCENE_PATH)
	else:
		var summary: Dictionary = instance.describe_scene_surface()
		if str(summary.get("group_id", "")) != "workout_browser":
			failures.append("Main scene reported an unexpected group_id: %s" % str(summary.get("group_id", "")))
		if not bool(summary.get("has_connection_controls", false)):
			failures.append("Main scene is missing connection controls.")
		if not bool(summary.get("has_auth_controls", false)):
			failures.append("Main scene is missing auth controls.")
		if not bool(summary.get("has_global_tabs", false)):
			failures.append("Main scene is missing the global tab container.")
		if not bool(summary.get("has_tab_container", false)):
			failures.append("Main scene is missing the browser tab container.")
		if not bool(summary.get("has_detail_overlay", false)):
			failures.append("Main scene is missing the detail overlay.")
	instance.queue_free()

func _validate_smoke_scenes(failures: PackedStringArray) -> void:
	for scene_path in SMOKE_SCENE_PATHS:
		var packed_scene := load(scene_path)
		if packed_scene == null:
			failures.append("Failed to load smoke-test scene: %s" % scene_path)
			continue
		var instance = packed_scene.instantiate()
		if instance == null:
			failures.append("Failed to instantiate smoke-test scene: %s" % scene_path)
			continue
		if not instance.has_method("describe_scene_surface"):
			failures.append("Smoke-test scene is missing describe_scene_surface(): %s" % scene_path)
		else:
			var summary: Dictionary = instance.describe_scene_surface()
			if str(summary.get("group_id", "")).is_empty():
				failures.append("Smoke-test scene reported an empty group_id: %s" % scene_path)
			if not bool(summary.get("has_run_button", false)):
				failures.append("Smoke-test scene is missing a run button: %s" % scene_path)
			if not bool(summary.get("has_output", false)):
				failures.append("Smoke-test scene is missing an output surface: %s" % scene_path)
		instance.queue_free()
