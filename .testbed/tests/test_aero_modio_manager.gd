extends GutTest

const AeroModIOManager = preload("res://addons/aerobeat-vendor-modio/src/AeroModIOManager.gd")
const ModioClientConfig = preload("res://addons/aerobeat-vendor-modio/src/models/modio_client_config.gd")
const ModioHttpTransport = preload("res://addons/aerobeat-vendor-modio/src/network/modio_http_transport.gd")

func test_manager_exposes_repo_owned_facade_over_provider_adapter() -> void:
	var executed_requests: Array[Dictionary] = []
	var transport := ModioHttpTransport.new(func(final_request: Dictionary, _options: Dictionary) -> Dictionary:
		executed_requests.append(final_request)
		return {
			"status_code": 200,
			"headers": {},
			"payload": {"message": "pong"},
			"body": ""
		}
	)
	var config := ModioClientConfig.new("777", "demo-key", ModioClientConfig.DEFAULT_BASE_URL, "session-token", "en-US", "steam", "WINDOWS")
	var manager := AeroModIOManager.new(config, transport)

	assert_eq(manager.get_provider_name(), "modio")
	assert_true(manager.has_public_credentials())
	assert_true(manager.has_access_token())
	assert_eq(manager.get_adapter().build_ping_request().path, "/ping")

	var request := manager.build_request("build_game_request")
	assert_eq(request.path, "/games/777")
	assert_eq(request.query.api_key, "demo-key")

	var response := manager.execute_adapter_request("build_ping_request")
	assert_true(response.ok)
	assert_eq(executed_requests.size(), 1)
	assert_eq(executed_requests[0].path, "/ping")
	assert_eq(executed_requests[0].headers["Accept-Language"], "en-US")

func test_manager_reports_unknown_adapter_methods_as_validation_requests() -> void:
	var manager := AeroModIOManager.new()
	var request := manager.build_request("build_nonexistent_request")

	assert_true(request.has("meta"))
	assert_true(request.meta.has("validation_error"))
	assert_string_contains(str(request.meta.validation_error), "Unknown adapter build method")

func test_manager_summarizes_provider_errors_with_nested_details_and_error_ref() -> void:
	var manager := AeroModIOManager.new()
	var summary := manager.summarize_provider_error({
		"error": {
			"message": "Validation Failed. Please see below to fix invalid input:",
			"error_ref": 13009,
			"details": {
				"summary": ["The \"summary\" field is required."],
				"metadata_blob": "The \"metadata_blob\" must be a string."
			}
		}
	}, "fallback")

	assert_string_contains(summary, "Validation Failed. Please see below to fix invalid input:")
	assert_string_contains(summary, "summary: The \"summary\" field is required.")
	assert_string_contains(summary, "metadata_blob: The \"metadata_blob\" must be a string.")
	assert_string_contains(summary, "error_ref=13009")

func test_manager_summarizes_provider_errors_from_errors_payload_shape() -> void:
	var manager := AeroModIOManager.new()
	var summary := manager.summarize_provider_error({
		"error": {
			"message": "Upload rejected.",
			"errors": {
				"filedata": ["ZIP payload was invalid."],
				"virus_status": {
					"scan": "Pending"
				}
			}
		}
	}, "fallback")

	assert_string_contains(summary, "Upload rejected.")
	assert_string_contains(summary, "filedata: ZIP payload was invalid.")
	assert_string_contains(summary, "virus_status.scan: Pending")
