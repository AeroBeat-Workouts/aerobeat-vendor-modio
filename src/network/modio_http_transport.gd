class_name ModioHttpTransport
extends RefCounted

func build_request(method: String, path: String, query: Dictionary = {}, body: Dictionary = {}, extra_headers: Dictionary = {}) -> Dictionary:
	return {
		"method": method.to_upper(),
		"path": _normalize_path(path),
		"query": query.duplicate(true),
		"body": body.duplicate(true),
		"headers": extra_headers.duplicate(true)
	}

func _normalize_path(path: String) -> String:
	if path.begins_with("/"):
		return path
	return "/%s" % path
