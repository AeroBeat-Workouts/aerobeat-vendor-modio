extends GutTest

const AeroModIOManager = preload("res://addons/aerobeat-vendor-modio/src/AeroModIOManager.gd")
const ModioClientConfig = preload("res://addons/aerobeat-vendor-modio/src/models/modio_client_config.gd")
const ModioHttpTransport = preload("res://addons/aerobeat-vendor-modio/src/network/modio_http_transport.gd")
const ModioWorkoutUploadFlow = preload("res://addons/aerobeat-vendor-modio/src/modio_workout_upload_flow.gd")

const TMP_DIR := "user://workout_upload_flow_tests"

func after_each() -> void:
	var absolute_dir := ProjectSettings.globalize_path(TMP_DIR)
	if DirAccess.dir_exists_absolute(absolute_dir):
		for entry in DirAccess.get_files_at(absolute_dir):
			DirAccess.remove_absolute(absolute_dir.path_join(entry))
		DirAccess.remove_absolute(absolute_dir)

func test_submit_workout_runs_create_upload_publish_sequence() -> void:
	var logo_path := _write_file("logo.png", PackedByteArray([0x89, 0x50, 0x4E, 0x47]))
	var zip_path := _write_file("workout.zip", PackedByteArray([0x50, 0x4B, 0x03, 0x04]))
	var recorded_requests: Array[Dictionary] = []
	var transport := ModioHttpTransport.new(func(final_request: Dictionary, _options: Dictionary) -> Dictionary:
		recorded_requests.append(final_request)
		match recorded_requests.size():
			1:
				return {
					"status_code": 201,
					"headers": {"location": "/games/777/mods/901"},
					"payload": {
						"id": 901,
						"name": "Cardio Blast 30",
						"status": 0,
						"visible": 0,
						"summary": "Thirty-minute interval workout"
					}
				}
			2:
				return {
					"status_code": 201,
					"headers": {"location": "/games/777/mods/901/files/444"},
					"payload": {
						"id": 444,
						"mod_id": 901,
						"filename": "cardio-blast-30.zip",
						"version": "1.0.0"
					}
				}
			_:
				return {
					"status_code": 200,
					"headers": {},
					"payload": {
						"id": 901,
						"name": "Cardio Blast 30",
						"status": 1,
						"visible": 1,
						"summary": "Thirty-minute interval workout"
					}
				}
	)
	var config := ModioClientConfig.new("777", "demo-key", ModioClientConfig.DEFAULT_BASE_URL, "athlete-token")
	var manager := AeroModIOManager.new(config, transport)
	var flow := ModioWorkoutUploadFlow.new()

	var result := flow.submit_workout(manager, {
		"name": "Cardio Blast 30",
		"summary": "Thirty-minute interval workout",
		"description": "Disposable staged upload fixture.",
		"metadata_kvp": "difficulty=medium\ncoach=chip",
		"tags": "cardio, interval",
		"logo_path": logo_path,
		"zip_path": zip_path,
		"version": "1.0.0",
		"changelog": "Initial build",
		"publish_after_upload": true
	})

	assert_true(result.ok)
	assert_eq(result.mod_id, 901)
	assert_eq(result.file_id, 444)
	assert_eq(recorded_requests.size(), 3)
	assert_eq(recorded_requests[0].path, "/games/777/mods")
	assert_eq(recorded_requests[0].body.logo, "@%s" % logo_path)
	assert_eq(recorded_requests[0].body["metadata[]"], ["difficulty=medium", "coach=chip"])
	assert_eq(recorded_requests[1].path, "/games/777/mods/901/files")
	assert_eq(recorded_requests[1].body.filedata, "@%s" % zip_path)
	assert_eq(recorded_requests[2].path, "/games/777/mods/901")
	assert_eq(recorded_requests[2].body.status, "1")
	assert_eq(recorded_requests[2].body.visible, "1")
	assert_string_contains(result.message, "Published")

func test_submit_workout_reports_truthful_validation_errors_before_network() -> void:
	var flow := ModioWorkoutUploadFlow.new()
	var result := flow.submit_workout(null, {
		"name": "",
		"metadata_kvp": "",
		"logo_path": "/tmp/missing-logo.png",
		"zip_path": "/tmp/missing-build.zip"
	})

	assert_false(result.ok)
	assert_eq(result.stage, "validation")
	assert_true(result.errors.size() >= 4)
	assert_string_contains(result.message, "name is required")
	assert_string_contains(result.message, "metadata_kvp is required")
	assert_string_contains(result.message, "logo_path must point to an existing file")
	assert_string_contains(result.message, "zip_path must point to an existing file")

func test_submit_workout_stops_after_modfile_failure_without_publish() -> void:
	var logo_path := _write_file("logo.png", PackedByteArray([1, 2, 3]))
	var zip_path := _write_file("workout.zip", PackedByteArray([4, 5, 6]))
	var recorded_requests: Array[Dictionary] = []
	var transport := ModioHttpTransport.new(func(final_request: Dictionary, _options: Dictionary) -> Dictionary:
		recorded_requests.append(final_request)
		if recorded_requests.size() == 1:
			return {
				"status_code": 201,
				"headers": {},
				"payload": {"id": 912, "name": "Tempo Builder", "status": 0, "visible": 0}
			}
		return {
			"status_code": 422,
			"headers": {},
			"payload": {"error": {"message": "Upload rejected by fixture transport."}}
		}
	)
	var config := ModioClientConfig.new("777", "demo-key", ModioClientConfig.DEFAULT_BASE_URL, "athlete-token")
	var manager := AeroModIOManager.new(config, transport)
	var flow := ModioWorkoutUploadFlow.new()

	var result := flow.submit_workout(manager, {
		"name": "Tempo Builder",
		"metadata_kvp": ["difficulty=easy"],
		"logo_path": logo_path,
		"zip_path": zip_path,
		"publish_after_upload": true
	})

	assert_false(result.ok)
	assert_eq(result.mod_id, 912)
	assert_eq(recorded_requests.size(), 2)
	assert_eq(result.steps.size(), 2)
	assert_eq(result.steps[1].stage, "upload_modfile")
	assert_string_contains(result.message, "Upload rejected by fixture transport")

func _write_file(filename: String, bytes: PackedByteArray) -> String:
	var absolute_dir := ProjectSettings.globalize_path(TMP_DIR)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		DirAccess.make_dir_recursive_absolute(absolute_dir)
	var absolute_path := absolute_dir.path_join(filename)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_buffer(bytes)
		file.close()
	return absolute_path
