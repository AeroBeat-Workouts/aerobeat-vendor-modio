extends SceneTree

func _initialize() -> void:
	var failures: PackedStringArray = []
	var scene_paths := [
		"res://scenes/public_catalog_testbed.tscn",
		"res://scenes/authenticated_user_testbed.tscn",
		"res://scenes/safe_write_testbed.tscn",
		"res://scenes/paid_mods_testbed.tscn"
	]

	for scene_path in scene_paths:
		var packed_scene := load(scene_path)
		if packed_scene == null:
			failures.append("Failed to load scene: %s" % scene_path)
			continue
		var instance = packed_scene.instantiate()
		if instance == null:
			failures.append("Failed to instantiate scene: %s" % scene_path)
			continue
		if not instance.has_method("describe_scene_surface"):
			failures.append("Scene is missing describe_scene_surface(): %s" % scene_path)
		else:
			var summary: Dictionary = instance.describe_scene_surface()
			if str(summary.get("group_id", "")).is_empty():
				failures.append("Scene reported an empty group_id: %s" % scene_path)
			if not bool(summary.get("has_run_button", false)):
				failures.append("Scene is missing a run button: %s" % scene_path)
			if not bool(summary.get("has_output", false)):
				failures.append("Scene is missing an output surface: %s" % scene_path)
		instance.queue_free()

	if failures.is_empty():
		print("Mod.io testbed scene validation passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
		print(failure)
	quit(1)
