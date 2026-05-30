class_name AeroModIOManager
extends RefCounted

const ModioClientConfig = preload("models/modio_client_config.gd")
const ModioVendorAdapter = preload("modio_vendor_adapter.gd")
const ModioHttpTransport = preload("network/modio_http_transport.gd")

const PROVIDER_NAME := "modio"

var _config: ModioClientConfig
var _transport
var _adapter: ModioVendorAdapter

func _init(config = null, transport = null) -> void:
	configure(config, transport)

func configure(config = null, transport = null):
	_config = config if config != null else ModioClientConfig.new()
	_transport = transport if transport != null else ModioHttpTransport.new()
	_adapter = ModioVendorAdapter.new(_config, _transport)
	return self

func get_provider_name() -> String:
	return PROVIDER_NAME

func get_config() -> ModioClientConfig:
	return _config

func get_transport():
	return _transport

func get_adapter() -> ModioVendorAdapter:
	return _adapter

func has_public_credentials() -> bool:
	return _config != null and _config.has_public_credentials()

func has_access_token() -> bool:
	return _config != null and _config.has_access_token()

func has_service_token() -> bool:
	return _config != null and _config.has_service_token()

func resolve_base_url(base_url_override: String = "") -> String:
	if _config == null:
		return ModioClientConfig.DEFAULT_BASE_URL
	return _config.resolve_base_url(base_url_override)

func build_request(builder_method: StringName, builder_args: Array = []) -> Dictionary:
	if _adapter == null:
		return _invalid_manager_request("Adapter is not configured")
	if not _adapter.has_method(builder_method):
		return _invalid_manager_request("Unknown adapter build method: %s" % String(builder_method))
	var built = _adapter.callv(builder_method, builder_args)
	if built is Dictionary:
		return built
	return _invalid_manager_request("Adapter build method did not return a Dictionary: %s" % String(builder_method))

func execute_request(request: Dictionary) -> Dictionary:
	if _transport == null:
		return {
			"ok": false,
			"status_code": 0,
			"error": {
				"message": "Transport is not configured",
				"category": "client"
			}
		}
	return _transport.execute(request, _config)

func execute_adapter_request(builder_method: StringName, builder_args: Array = []) -> Dictionary:
	var request := build_request(builder_method, builder_args)
	return execute_request(request)

func normalize_with_adapter(normalizer_method: StringName, normalizer_args: Array = []):
	if _adapter == null:
		return null
	if not _adapter.has_method(normalizer_method):
		return null
	return _adapter.callv(normalizer_method, normalizer_args)

func describe_runtime() -> Dictionary:
	return {
		"provider": get_provider_name(),
		"base_url": resolve_base_url(),
		"game_id": "" if _config == null else _config.game_id,
		"host_kind": "" if _config == null else _config.host_kind,
		"has_public_credentials": has_public_credentials(),
		"has_access_token": has_access_token(),
		"has_service_token": has_service_token(),
		"use_test_environment": false if _config == null else _config.use_test_environment
	}

func _invalid_manager_request(message: String) -> Dictionary:
	return {
		"method": "GET",
		"path": "",
		"query": {},
		"body": {},
		"headers": {},
		"meta": {
			"validation_errors": [message],
			"validation_error": message,
			"auth_mode": "none"
		}
	}
