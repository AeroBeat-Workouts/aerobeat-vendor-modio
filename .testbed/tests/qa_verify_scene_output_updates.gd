extends SceneTree

const SCENES := [
	{
		"path": "res://scenes/public_catalog_testbed.tscn",
		"group": "public_catalog"
	},
	{
		"path": "res://scenes/authenticated_user_testbed.tscn",
		"group": "authenticated_user"
	},
	{
		"path": "res://scenes/safe_write_testbed.tscn",
		"group": "safe_write"
	},
	{
		"path": "res://scenes/paid_mods_testbed.tscn",
		"group": "paid_mods"
	}
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: PackedStringArray = []
	for scene_config in SCENES:
		var scene_path := String(scene_config.get("path", ""))
		var expected_group := String(scene_config.get("group", ""))
		var packed_scene: PackedScene = load(scene_path)
		if packed_scene == null:
			failures.append("Failed to load scene: %s" % scene_path)
			continue

		var instance: Node = packed_scene.instantiate()
		if instance == null:
			failures.append("Failed to instantiate scene: %s" % scene_path)
			continue

		root.add_child(instance)
		await process_frame

		var output_edit: TextEdit = instance.get_node_or_null("MarginContainer/VBoxContainer/OutputEdit")
		var run_button: Button = instance.get_node_or_null("MarginContainer/VBoxContainer/RunButton")
		if output_edit == null:
			failures.append("Missing OutputEdit: %s" % scene_path)
			instance.queue_free()
			await process_frame
			continue
		if run_button == null:
			failures.append("Missing RunButton: %s" % scene_path)
			instance.queue_free()
			await process_frame
			continue

		var initial_text := output_edit.text
		var expected_initial := "Press Run Checks to exercise the %s slice." % expected_group
		if initial_text != expected_initial:
			failures.append("Unexpected initial text for %s: %s" % [scene_path, initial_text])

		run_button.emit_signal("pressed")
		await process_frame
		var final_text := output_edit.text

		if final_text == initial_text:
			failures.append("Output did not change after Run Checks: %s" % scene_path)
		if not final_text.contains("group: %s" % expected_group):
			failures.append("Final report missing expected group id for %s: %s" % [scene_path, final_text])
		if not final_text.contains("environment: "):
			failures.append("Final report missing environment line for %s" % scene_path)
		if not final_text.contains("base_url: "):
			failures.append("Final report missing base_url line for %s" % scene_path)
		if not final_text.contains("ok: "):
			failures.append("Final report missing ok line for %s" % scene_path)
		if final_text.contains("Press Run Checks"):
			failures.append("Initial prompt still present after run for %s" % scene_path)

		print("Verified scene output update: %s" % scene_path)
		print(final_text)
		print("---")

		instance.queue_free()
		await process_frame

	if failures.is_empty():
		print("Scene output update QA passed for all mod.io testbed scenes.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
		print(failure)
	quit(1)
