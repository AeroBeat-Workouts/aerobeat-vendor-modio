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
	var detail_download: Button = instance.find_child("DetailDownloadButton", true, false)
	var detail_path: LineEdit = instance.find_child("DetailDownloadPathLineEdit", true, false)
	var detail_panel: PanelContainer = instance.find_child("DetailPanel", true, false)
	var upload_scroll: ScrollContainer = instance.find_child("UploadWorkoutScroll", true, false)
	var upload_summary_description_row: HBoxContainer = instance.find_child("UploadWorkoutSummaryDescriptionRow", true, false)
	var upload_metadata_tags_row: HBoxContainer = instance.find_child("UploadWorkoutMetadataTagsRow", true, false)
	var upload_file_row: HBoxContainer = instance.find_child("UploadWorkoutFileRow", true, false)
	var upload_name: LineEdit = instance.find_child("UploadWorkoutNameLineEdit", true, false)
	var upload_logo: LineEdit = instance.find_child("UploadWorkoutLogoPathLineEdit", true, false)
	var upload_zip: LineEdit = instance.find_child("UploadWorkoutZipPathLineEdit", true, false)
	var upload_button: Button = instance.find_child("UploadWorkoutSubmitButton", true, false)
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
		if tab_container.get_tab_title(4) != "Upload Workout":
			failures.append("Unexpected browser tab 4 title: %s" % tab_container.get_tab_title(4))
		if not tab_container.is_tab_disabled(4):
			failures.append("Upload Workout tab should start disabled until athlete auth exists")
	if upload_scroll == null:
		failures.append("Main scene missing UploadWorkoutScroll for viewport-safe upload access")
	if upload_summary_description_row == null or upload_summary_description_row.get_child_count() != 2:
		failures.append("Upload Workout tab is missing the paired Summary/Description row")
	if upload_metadata_tags_row == null or upload_metadata_tags_row.get_child_count() != 2:
		failures.append("Upload Workout tab is missing the paired Metadata/Tags row")
	if upload_file_row == null or upload_file_row.get_child_count() != 2:
		failures.append("Upload Workout tab is missing the paired Workout Logo/Workout ZIP row")
	if upload_name == null or upload_logo == null or upload_zip == null or upload_button == null:
		failures.append("Main scene missing staged upload controls")
	elif not upload_button.disabled:
		failures.append("Upload submit button should start disabled until athlete auth exists")
	if detail_overlay == null:
		failures.append("Main scene missing DetailOverlay")
	elif detail_action == null:
		failures.append("Main scene missing DetailActionButton")
	elif detail_download == null or detail_path == null or detail_panel == null:
		failures.append("Main scene missing download slideout controls")
	else:
		var sample_entries: Array = _fixture("mods.json").get("data", [])
		if sample_entries.is_empty():
			failures.append("Fixture mods.json did not contain any sample entries for detail QA")
		else:
			var sample_entry: Dictionary = sample_entries[0]
			instance.get("_state").access_token = ""
			instance.call("_open_detail", sample_entry, "public")
			await process_frame
			if not detail_overlay.visible:
				failures.append("Detail overlay did not open for public context")
			if not detail_action.visible or detail_action.text != "Subscribe" or not detail_action.disabled:
				failures.append("Public detail should expose a disabled Subscribe CTA until athlete auth exists")
			if detail_panel.get_parent().name != "DetailDockRow":
				failures.append("Detail panel is not mounted in the right-docked slideout row")
			if detail_download.disabled:
				failures.append("Public detail should expose the first-pass Download action when modfile metadata exists")
			if detail_path.text.is_empty():
				failures.append("Detail download path should be prefilled for the operator")
			instance.call("_close_detail_overlay")
			await process_frame

			instance.get("_state").access_token = "qa-token"
			instance.call("_open_detail", sample_entry, "workout")
			await process_frame
			if not detail_action.visible or detail_action.text != "Subscribe" or detail_action.disabled:
				failures.append("Workout detail did not expose an enabled Subscribe CTA for authenticated athletes")
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
		if expected_group == "paid_mods":
			var scene_summary: Dictionary = instance.describe_scene_surface()
			expected_initial = str(scene_summary.get("initial_output", expected_initial))
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
		if expected_group == "paid_mods":
			if not final_text.contains("run_checks_scope: "):
				failures.append("Paid-mods report missing run_checks_scope line")
			if not final_text.contains("open_question: "):
				failures.append("Paid-mods report missing open_question line")
			if not final_text.contains("[GUARDED] Guarded buyer writes"):
				failures.append("Paid-mods report missing guarded buyer writes grouping")
		if final_text.contains("Press Run Checks"):
			failures.append("Initial prompt still present after run for %s" % scene_path)

		instance.queue_free()
		await process_frame
