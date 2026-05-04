class_name ModioHttpTransport
extends RefCounted

const CONTENT_TYPE_FORM := "application/x-www-form-urlencoded"
const CONTENT_TYPE_MULTIPART := "multipart/form-data"
const DEFAULT_TIMEOUT_SECONDS := 30.0
const DEFAULT_RETRY_AFTER_SECONDS := 60

var _executor: Callable

func _init(executor: Callable = Callable()) -> void:
	_executor = executor

func build_request(
	method: String,
	path: String,
	query: Dictionary = {},
	body: Dictionary = {},
	extra_headers: Dictionary = {},
	meta: Dictionary = {}
) -> Dictionary:
	return {
		"method": method.to_upper(),
		"path": _normalize_path(path),
		"query": _stringify_dictionary(query),
		"body": _stringify_dictionary(body),
		"headers": extra_headers.duplicate(true),
		"content_type": meta.get("content_type", ""),
		"auth_mode": meta.get("auth_mode", "none"),
		"expects": meta.get("expects", "json"),
		"multipart_boundary": meta.get("multipart_boundary", ""),
		"raw_body": meta.get("raw_body", null),
		"validation_error": meta.get("validation_error", ""),
		"validation_errors": meta.get("validation_errors", [])
	}

func execute(request: Dictionary, config: ModioClientConfig = null, options: Dictionary = {}) -> Dictionary:
	var prepared := prepare_request(request, config, options)
	if not prepared.ok:
		return prepared

	var final_request: Dictionary = prepared.request
	var raw_result := _dispatch_request(final_request, options)
	if raw_result.get("transport_error", "") != "":
		return _build_transport_error_result(str(raw_result.transport_error), final_request, int(raw_result.get("code", ERR_CANT_CONNECT)))

	var payload = raw_result.get("payload", null)
	var raw_body := str(raw_result.get("body", ""))
	if payload == null:
		payload = _decode_payload(raw_body, str(final_request.get("expects", "json")))

	var normalized := normalize_response(int(raw_result.get("status_code", 0)), raw_result.get("headers", {}), payload)
	normalized["request"] = final_request.duplicate(true)
	normalized["raw_body"] = raw_body
	return normalized

func prepare_request(request: Dictionary, config: ModioClientConfig = null, options: Dictionary = {}) -> Dictionary:
	var effective_config: ModioClientConfig = config if config != null else ModioClientConfig.new()
	var final_request := request.duplicate(true)
	var path := _normalize_path(str(final_request.get("path", "/")))
	var method := str(final_request.get("method", "GET")).to_upper()
	var auth_mode := str(final_request.get("auth_mode", "none"))
	var query: Dictionary = _stringify_dictionary(final_request.get("query", {}))
	var headers: Dictionary = _normalize_outbound_headers(final_request.get("headers", {}))
	var body: Dictionary = _stringify_dictionary(final_request.get("body", {}))
	var raw_body = final_request.get("raw_body", null)
	var content_type := str(final_request.get("content_type", ""))
	var expects := str(final_request.get("expects", "json"))
	var explicit_base_url := str(options.get("base_url", ""))
	var base_url := effective_config.resolve_base_url(explicit_base_url)
	var validation_errors: Array = final_request.get("validation_errors", [])
	var validation_error := str(final_request.get("validation_error", ""))

	if validation_errors.size() > 0 or not validation_error.is_empty():
		if validation_error.is_empty():
			validation_error = "Invalid mod.io request: %s" % "; ".join(PackedStringArray(validation_errors))
		return _build_transport_error_result(validation_error, {
			"method": method,
			"path": path,
			"query": query,
			"body": body,
			"headers": headers,
			"content_type": content_type,
			"auth_mode": auth_mode,
			"expects": expects,
			"validation_errors": validation_errors
		}, ERR_INVALID_PARAMETER)

	var auth_error := _apply_auth_mode(method, auth_mode, query, headers, effective_config)
	if not auth_error.is_empty():
		return _build_transport_error_result(auth_error, {"method": method, "path": path}, ERR_INVALID_PARAMETER)

	var encoded_query := _encode_parameters(query)
	var requested_multipart_boundary := str(final_request.get("multipart_boundary", "")).strip_edges()
	if requested_multipart_boundary.is_empty():
		requested_multipart_boundary = str(options.get("multipart_boundary", "")).strip_edges()
	var encoded_body := ""
	var encoded_body_bytes := PackedByteArray()
	var final_content_type := content_type
	var multipart_boundary := ""
	var has_raw_body := raw_body != null
	if has_raw_body:
		var raw_body_result := _normalize_raw_request_body(raw_body, content_type)
		if not bool(raw_body_result.get("ok", false)):
			return _build_transport_error_result(str(raw_body_result.get("error", "Failed to encode raw request body.")), {"method": method, "path": path}, ERR_INVALID_PARAMETER)
		encoded_body = str(raw_body_result.get("body_string", ""))
		encoded_body_bytes = raw_body_result.get("body_bytes", PackedByteArray())
		final_content_type = str(raw_body_result.get("content_type", content_type))
	else:
		var encoded_body_result := _encode_request_body(body, content_type, requested_multipart_boundary)
		if not bool(encoded_body_result.get("ok", false)):
			return _build_transport_error_result(str(encoded_body_result.get("error", "Failed to encode request body.")), {"method": method, "path": path}, ERR_INVALID_PARAMETER)
		encoded_body = str(encoded_body_result.get("body_string", ""))
		encoded_body_bytes = encoded_body.to_utf8_buffer()
		final_content_type = str(encoded_body_result.get("content_type", content_type))
		multipart_boundary = str(encoded_body_result.get("boundary", ""))
	if final_content_type != "" and not headers.has("Content-Type"):
		headers["Content-Type"] = final_content_type
	if encoded_body_bytes.size() > 0 and not headers.has("Content-Length"):
		headers["Content-Length"] = str(encoded_body_bytes.size())

	final_request = {
		"method": method,
		"path": path,
		"url": _join_url(base_url, path, encoded_query),
		"query": query,
		"query_string": encoded_query,
		"headers": headers,
		"body": body,
		"raw_body": raw_body,
		"body_string": encoded_body,
		"body_bytes": encoded_body_bytes,
		"has_raw_body": has_raw_body,
		"content_type": final_content_type,
		"multipart_boundary": multipart_boundary,
		"auth_mode": auth_mode,
		"expects": expects,
		"base_url": base_url
	}
	return {"ok": true, "request": final_request}

func normalize_response(status_code: int, headers: Dictionary = {}, payload: Variant = null) -> Dictionary:
	var normalized_headers := _normalize_headers(headers)
	var retry_after_seconds := _parse_retry_after(normalized_headers)
	var result := {
		"ok": status_code >= 200 and status_code < 300,
		"status_code": status_code,
		"headers": normalized_headers,
		"payload": payload,
		"retry_after_seconds": retry_after_seconds,
		"rate_limit_scope": "none"
	}

	if result.ok:
		return result

	var error_payload: Dictionary = {}
	if payload is Dictionary and payload.has("error") and payload.error is Dictionary:
		error_payload = payload.error

	var error_ref := int(error_payload.get("error_ref", 0))
	var category := _categorize_error(status_code, error_ref)
	if error_ref == 11008:
		result.rate_limit_scope = "global"
	elif error_ref == 11009:
		result.rate_limit_scope = "endpoint"

	result["error"] = {
		"code": int(error_payload.get("code", status_code)),
		"error_ref": error_ref,
		"message": str(error_payload.get("message", "HTTP %s" % status_code)),
		"details": error_payload.get("errors", {}),
		"category": category,
		"should_clear_session": error_ref in [11005],
		"should_retry_with_terms": error_ref == 11074,
		"is_key_issue": error_ref in [11016, 11017],
		"is_account_locked": error_ref == 17053
	}
	return result

func _dispatch_request(final_request: Dictionary, options: Dictionary) -> Dictionary:
	if _executor.is_valid():
		return _executor.call(final_request, options)
	return _execute_with_http_client(final_request, options)

func _execute_with_http_client(final_request: Dictionary, options: Dictionary) -> Dictionary:
	var parsed := _parse_url(final_request.url)
	if not parsed.ok:
		return parsed

	var client := HTTPClient.new()
	var connect_error := client.connect_to_host(parsed.host, parsed.port, parsed.tls)
	if connect_error != OK:
		return {"transport_error": error_string(connect_error), "code": connect_error}

	var timeout_seconds := float(options.get("timeout_seconds", DEFAULT_TIMEOUT_SECONDS))
	if not _wait_for_client(client, timeout_seconds, [HTTPClient.STATUS_CONNECTED]):
		return {"transport_error": "Timed out connecting to mod.io host.", "code": ERR_TIMEOUT}

	var request_headers := _headers_to_lines(final_request.headers)
	var request_error := OK
	if bool(final_request.get("has_raw_body", false)):
		request_error = client.request_raw(_http_method_to_constant(final_request.method), parsed.request_path, request_headers, final_request.get("body_bytes", PackedByteArray()))
	else:
		request_error = client.request(_http_method_to_constant(final_request.method), parsed.request_path, request_headers, final_request.body_string)
	if request_error != OK:
		return {"transport_error": error_string(request_error), "code": request_error}

	if not _wait_for_client(client, timeout_seconds, [HTTPClient.STATUS_BODY, HTTPClient.STATUS_CONNECTED]):
		return {"transport_error": "Timed out waiting for mod.io response.", "code": ERR_TIMEOUT}

	var response_code := client.get_response_code()
	var response_headers := _response_headers_to_dictionary(client.get_response_headers())
	var body_chunks := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(10)
			continue
		body_chunks.append_array(chunk)

	return {
		"status_code": response_code,
		"headers": response_headers,
		"body": body_chunks.get_string_from_utf8()
	}

func _wait_for_client(client: HTTPClient, timeout_seconds: float, terminal_statuses: Array) -> bool:
	var started_at := Time.get_ticks_msec()
	while true:
		client.poll()
		var status := client.get_status()
		if terminal_statuses.has(status):
			return true
		if status == HTTPClient.STATUS_DISCONNECTED:
			return false
		var elapsed_seconds := float(Time.get_ticks_msec() - started_at) / 1000.0
		if elapsed_seconds >= timeout_seconds:
			return false
		OS.delay_msec(10)
	return false

func _build_transport_error_result(message: String, request: Dictionary, code: int = ERR_INVALID_PARAMETER) -> Dictionary:
	return {
		"ok": false,
		"status_code": -1,
		"headers": {},
		"payload": null,
		"retry_after_seconds": -1,
		"rate_limit_scope": "none",
		"request": request.duplicate(true),
		"error": {
			"code": code,
			"error_ref": 0,
			"message": message,
			"details": {},
			"category": "transport",
			"should_clear_session": false,
			"should_retry_with_terms": false,
			"is_key_issue": false,
			"is_account_locked": false
		}
	}

func _normalize_path(path: String) -> String:
	var sanitized := path.strip_edges()
	if sanitized.is_empty():
		return "/"
	sanitized = sanitized.trim_prefix("/")
	return "/%s" % sanitized

func _normalize_headers(headers: Dictionary) -> Dictionary:
	var normalized := {}
	for key in headers.keys():
		normalized[str(key).to_lower()] = headers[key]
	return normalized

func _normalize_outbound_headers(headers: Dictionary) -> Dictionary:
	var normalized := {}
	for key in headers.keys():
		normalized[str(key)] = str(headers[key])
	return normalized

func _apply_auth_mode(method: String, auth_mode: String, query: Dictionary, headers: Dictionary, config: ModioClientConfig) -> String:
	match auth_mode:
		"bearer":
			if not _has_bearer_authorization(headers):
				return "Bearer-authenticated mod.io requests require an Authorization header."
			query.erase("api_key")
		"api_key_query":
			if not config.api_key.is_empty() and not query.has("api_key"):
				query["api_key"] = config.api_key
		"api_key_fallback":
			if _has_bearer_authorization(headers):
				query.erase("api_key")
			elif method == "GET" and not config.api_key.is_empty():
				query["api_key"] = config.api_key
			else:
				return "Authenticated mod.io fallback requests can only fall back to api_key on GET endpoints."
		_:
			pass
	return ""

func _has_bearer_authorization(headers: Dictionary) -> bool:
	if not headers.has("Authorization"):
		return false
	return str(headers.Authorization).begins_with("Bearer ") and str(headers.Authorization).length() > 7

func _encode_parameters(values: Dictionary) -> String:
	var keys: Array = values.keys()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	var parts: PackedStringArray = []
	for key in keys:
		parts.append("%s=%s" % [str(key).uri_encode(), _parameter_to_string(values[key]).uri_encode()])
	return "&".join(parts)

func _normalize_raw_request_body(raw_body: Variant, content_type: String) -> Dictionary:
	var body_bytes := PackedByteArray()
	if raw_body is PackedByteArray:
		body_bytes = raw_body
	elif raw_body is String:
		body_bytes = str(raw_body).to_utf8_buffer()
	else:
		return {"ok": false, "error": "Raw request bodies must be a PackedByteArray or String."}
	return {
		"ok": true,
		"body_string": body_bytes.get_string_from_utf8(),
		"body_bytes": body_bytes,
		"content_type": content_type
	}

func _encode_request_body(values: Dictionary, content_type: String, multipart_boundary: String = "") -> Dictionary:
	if values.is_empty():
		if _is_multipart_content_type(content_type):
			var empty_boundary := multipart_boundary.strip_edges()
			if empty_boundary.is_empty():
				empty_boundary = _generate_multipart_boundary()
			return {
				"ok": true,
				"body_string": "",
				"content_type": "%s; boundary=%s" % [CONTENT_TYPE_MULTIPART, empty_boundary],
				"boundary": empty_boundary
			}
		return {"ok": true, "body_string": "", "content_type": content_type, "boundary": ""}
	if _is_multipart_content_type(content_type):
		var boundary := multipart_boundary.strip_edges()
		if boundary.is_empty():
			boundary = _generate_multipart_boundary()
		return {
			"ok": true,
			"body_string": _encode_multipart_body(values, boundary),
			"content_type": "%s; boundary=%s" % [CONTENT_TYPE_MULTIPART, boundary],
			"boundary": boundary
		}
	if content_type == "" or content_type == CONTENT_TYPE_FORM:
		return {"ok": true, "body_string": _encode_parameters(values), "content_type": content_type, "boundary": ""}
	return {"ok": true, "body_string": JSON.stringify(values), "content_type": content_type, "boundary": ""}

func _is_multipart_content_type(content_type: String) -> bool:
	return content_type.strip_edges().begins_with(CONTENT_TYPE_MULTIPART)

func _generate_multipart_boundary() -> String:
	return "OpenClawModioBoundary%s" % str(Time.get_ticks_usec())

func _encode_multipart_body(values: Dictionary, boundary: String) -> String:
	var keys: Array = values.keys()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	var parts: PackedStringArray = []
	for key in keys:
		_append_multipart_field(parts, boundary, str(key), values[key])
	parts.append("--%s--" % boundary)
	parts.append("")
	return "\r\n".join(parts)

func _append_multipart_field(parts: PackedStringArray, boundary: String, key: String, value: Variant) -> void:
	if value is Array:
		var array_field_name := key if key.ends_with("[]") else "%s[]" % key
		if value.is_empty():
			_append_single_multipart_part(parts, boundary, array_field_name, "")
			return
		for item in value:
			_append_single_multipart_part(parts, boundary, array_field_name, _parameter_to_string(item))
		return
	_append_single_multipart_part(parts, boundary, key, _parameter_to_string(value))

func _append_single_multipart_part(parts: PackedStringArray, boundary: String, key: String, value: String) -> void:
	parts.append("--%s" % boundary)
	parts.append('Content-Disposition: form-data; name="%s"' % key.replace('"', '\"'))
	parts.append("")
	parts.append(value)

func _decode_payload(raw_body: String, expects: String) -> Variant:
	var body := raw_body.strip_edges()
	if body.is_empty():
		return {}
	if expects == "json":
		var parsed = JSON.parse_string(body)
		if parsed != null:
			return parsed
	return raw_body

func _parameter_to_string(value: Variant) -> String:
	if value is bool:
		return "true" if value else "false"
	return str(value)

func _join_url(base_url: String, path: String, query_string: String) -> String:
	var sanitized_base := base_url.rstrip("/")
	var full_url := "%s%s" % [sanitized_base, _normalize_path(path)]
	if not query_string.is_empty():
		full_url += "?%s" % query_string
	return full_url

func _parse_url(url: String) -> Dictionary:
	var trimmed := url.strip_edges()
	var parts := trimmed.split("://", false, 1)
	if parts.size() != 2:
		return {"ok": false, "transport_error": "Unsupported URL: %s" % url, "code": ERR_INVALID_PARAMETER}
	var scheme := parts[0].to_lower()
	var remainder := parts[1]
	var slash_index := remainder.find("/")
	var host_port := remainder
	var request_path := "/"
	if slash_index >= 0:
		host_port = remainder.substr(0, slash_index)
		request_path = remainder.substr(slash_index)
	var host := host_port
	var port := 443 if scheme == "https" else 80
	if host_port.contains(":"):
		var host_parts := host_port.rsplit(":", true, 1)
		host = host_parts[0]
		port = int(host_parts[1])
	return {
		"ok": true,
		"scheme": scheme,
		"tls": scheme == "https",
		"host": host,
		"port": port,
		"request_path": request_path
	}

func _headers_to_lines(headers: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var keys: Array = headers.keys()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	for key in keys:
		lines.append("%s: %s" % [str(key), str(headers[key])])
	return lines

func _response_headers_to_dictionary(header_lines: PackedStringArray) -> Dictionary:
	var headers := {}
	for line in header_lines:
		var separator_index := line.find(":")
		if separator_index < 0:
			continue
		var key := line.substr(0, separator_index).strip_edges()
		var value := line.substr(separator_index + 1).strip_edges()
		headers[key] = value
	return headers

func _http_method_to_constant(method: String) -> HTTPClient.Method:
	match method:
		"POST":
			return HTTPClient.METHOD_POST
		"PUT":
			return HTTPClient.METHOD_PUT
		"DELETE":
			return HTTPClient.METHOD_DELETE
		_:
			return HTTPClient.METHOD_GET

func _parse_retry_after(headers: Dictionary) -> int:
	if not headers.has("retry-after"):
		return -1
	var raw_value := str(headers["retry-after"]).strip_edges()
	if raw_value.is_empty():
		return -1
	var parsed := int(raw_value)
	if parsed == 0:
		return DEFAULT_RETRY_AFTER_SECONDS
	return parsed

func _categorize_error(status_code: int, error_ref: int) -> String:
	if status_code == 429 or error_ref == 11008 or error_ref == 11009:
		return "rate_limited"
	if error_ref == 11074:
		return "terms_required"
	if error_ref in [11016, 11017]:
		return "key_restricted"
	if error_ref == 17053:
		return "account_locked"
	if error_ref == 15025:
		return "admin_filter"
	if error_ref == 40004 or (error_ref == 13009 and status_code == 403):
		return "comments_restricted"
	if error_ref in [11005, 11011, 11012, 11013, 11014, 11032, 11091]:
		return "auth"
	if status_code == 401 or error_ref in [11000, 11001, 11002, 11003, 11004, 11006, 11007]:
		return "auth"
	if error_ref in [15090, 15028, 15043, 15059]:
		return "conflict"
	if status_code == 403 or error_ref in [15042, 15055, 15095, 19045, 29611]:
		return "forbidden"
	if status_code == 404 or error_ref in [14000, 14001, 15010, 15022, 15023]:
		return "not_found"
	if status_code == 409:
		return "conflict"
	if status_code == 422:
		return "validation"
	if status_code >= 500:
		return "server"
	return "unknown"

func _stringify_dictionary(values: Dictionary) -> Dictionary:
	var copy := {}
	for key in values.keys():
		var value = values[key]
		if value is bool:
			copy[key] = value
		elif value is int or value is float:
			copy[key] = str(value)
		else:
			copy[key] = value
	return copy
