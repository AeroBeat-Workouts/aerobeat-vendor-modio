class_name ModioDownloadRequest
extends RefCounted

var mod_id: String
var file_id: String
var binary_url: String
var date_expires: int
var md5: String
var filename: String

func _init(
	p_mod_id: String = "",
	p_file_id: String = "",
	p_binary_url: String = "",
	p_date_expires: int = 0,
	p_md5: String = "",
	p_filename: String = ""
) -> void:
	mod_id = p_mod_id.strip_edges()
	file_id = p_file_id.strip_edges()
	binary_url = p_binary_url.strip_edges()
	date_expires = maxi(0, p_date_expires)
	md5 = p_md5.strip_edges()
	filename = p_filename.strip_edges()

func is_valid() -> bool:
	return not mod_id.is_empty() and not file_id.is_empty() and not binary_url.is_empty()

func to_dictionary() -> Dictionary:
	return {
		"mod_id": mod_id,
		"file_id": file_id,
		"binary_url": binary_url,
		"date_expires": date_expires,
		"md5": md5,
		"filename": filename,
		"is_expiring": date_expires > 0,
		"is_canonical_url": false
	}
