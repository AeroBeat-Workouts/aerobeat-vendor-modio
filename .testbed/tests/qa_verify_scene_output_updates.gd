extends SceneTree

const SMOKE_SCENES := [
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
	_verify_main_scene(failures)
	_verify_smoke_scenes(failures)

	if failures.is_empty():
		print("Scene output update QA passed for all mod.io testbed scenes.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
		print(failure)
	quit(1)

func _verify_main_scene(failures: PackedStringArray) -> void:
	var scene_path := "res://scenes/workout_browser.tscn"
	var packed_scene: PackedScene = load(scene_path)
	if packed_scene == null:
		failures.append("Failed to load main scene: %s" % scene_path)
		return
	var instance: Node = packed_scene.instantiate()
	if instance == null:
		failures.append("Failed to instantiate main scene: %s" % scene_path)
		return
	root.add_child(instance)
	await process_frame
	var global_tab_container: TabContainer = instance.get_node_or_null("MarginContainer/VBoxContainer/GlobalTabContainer")
	var connection_panel := instance.get_node_or_null("MarginContainer/VBoxContainer/GlobalTabContainer/ConnectionTab/ConnectionPanel")
	var auth_panel := instance.get_node_or_null("MarginContainer/VBoxContainer/GlobalTabContainer/AuthTab/AuthPanel")
	var tab_container: TabContainer = instance.get_node_or_null("MarginContainer/VBoxContainer/GlobalTabContainer/BrowserTab/BrowserTabContainer")
	var detail_overlay := instance.find_child("DetailOverlay", true, false)
	var detail_action: Button = instance.find_child("DetailActionButton", true, false)
	if global_tab_container == null:
		failures.append("Main scene missing GlobalTabContainer")
	else:
		if global_tab_container.get_tab_title(0) != "Connection":
			failures.append("Unexpected global tab 0 title: %s" % global_tab_container.get_tab_title(0))
		if global_tab_container.get_tab_title(1) != "Auth":
			failures.append("Unexpected global tab 1 title: %s" % global_tab_container.get_tab_title(1))
		if global_tab_container.get_tab_title(2) != "Browser":
			failures.append("Unexpected global tab 2 title: %s" % global_tab_container.get_tab_title(2))
	if connection_panel == null:
		failures.append("Main scene missing ConnectionPanel")
	if auth_panel == null:
		failures.append("Main scene missing AuthPanel")
	if tab_container == null:
		failures.append("Main scene missing BrowserTabContainer")
	else:
		if tab_container.get_tab_title(0) != "Public Catalog":
			failures.append("Unexpected browser tab 0 title: %s" % tab_container.get_tab_title(0))
		if tab_container.get_tab_title(2) != "Workout Browser":
			failures.append("Unexpected browser tab 2 title: %s" % tab_container.get_tab_title(2))
	if detail_overlay == null:
		failures.append("Main scene missing DetailOverlay")
	elif detail_action == null:
		failures.append("Main scene missing DetailActionButton")
	else:
		var sample_entries: Array = _fixture("mods.json").get("data", [])
		if sample_entries.is_empty():
			failures.append("Fixture mods.json did not contain any sample entries for detail QA")
		else:
			var sample_entry: Dictionary = sample_entries[0]
			instance.call("_open_detail", sample_entry, "public")
			await process_frame
			if not detail_overlay.visible:
				failures.append("Detail overlay did not open for public context")
			if detail_action.visible:
				failures.append("Public detail should not expose a subscribe/unsubscribe CTA")
			instance.call("_close_detail_overlay")
			await process_frame

			instance.call("_open_detail", sample_entry, "workout")
			await process_frame
			if not detail_action.visible or detail_action.text != "Subscribe":
				failures.append("Workout detail did not expose the Subscribe CTA")
			instance.call("_close_detail_overlay")
			await process_frame

			instance.call("_open_detail", sample_entry, "subscribed")
			await process_frame
			if not detail_action.visible or detail_action.text != "Unsubscribe":
				failures.append("Subscribed detail did not expose the Unsubscribe CTA")
			instance.call("_close_detail_overlay")
			await process_frame
	instance.queue_free()
	await process_frame

func _fixture(path: String) -> Dictionary:
	var file := FileAccess.open("res://tests/fixtures/%s" % path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _verify_smoke_scenes(failures: PackedStringArray) -> void:
	for scene_config in SMOKE_SCENES:
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

		instance.queue_free()
		await process_frame
