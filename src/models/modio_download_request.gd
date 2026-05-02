class_name ModioDownloadRequest
extends RefCounted

var mod_id: String
var file_id: String

func _init(p_mod_id: String = "", p_file_id: String = "") -> void:
	mod_id = p_mod_id.strip_edges()
	file_id = p_file_id.strip_edges()

func is_valid() -> bool:
	return not mod_id.is_empty() and not file_id.is_empty()
