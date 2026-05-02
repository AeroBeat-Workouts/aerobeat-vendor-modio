class_name ModioHttpTransport
extends RefCounted

const CONTENT_TYPE_FORM := "application/x-www-form-urlencoded"

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
		"expects": meta.get("expects", "json")
	}

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
		"category": category
	}
	return result

func _normalize_path(path: String) -> String:
	if path.begins_with("/"):
		return path
	return "/%s" % path

func _normalize_headers(headers: Dictionary) -> Dictionary:
	var normalized := {}
	for key in headers.keys():
		normalized[str(key).to_lower()] = headers[key]
	return normalized

func _parse_retry_after(headers: Dictionary) -> int:
	if not headers.has("retry-after"):
		return -1
	var raw_value := str(headers["retry-after"]).strip_edges()
	if raw_value.is_empty():
		return -1
	var parsed := int(raw_value)
	if parsed == 0:
		return 60
	return parsed

func _categorize_error(status_code: int, error_ref: int) -> String:
	if status_code == 429 or error_ref == 11008 or error_ref == 11009:
		return "rate_limited"
	if error_ref == 11074:
		return "terms_required"
	if status_code == 401 or error_ref in [11000, 11001, 11002, 11003, 11004, 11005, 11006, 11007]:
		return "auth"
	if status_code == 403:
		return "forbidden"
	if status_code == 404 or error_ref in [14000, 14001, 15010, 15022, 15023]:
		return "not_found"
	if status_code == 409:
		return "conflict"
	if status_code == 422 or error_ref == 13009:
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
