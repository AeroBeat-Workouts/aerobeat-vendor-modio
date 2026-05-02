class_name ModioListingQuery
extends RefCounted

var search_term: String
var tags_all: PackedStringArray
var tags_any: PackedStringArray
var tags_not_in: PackedStringArray
var metadata_blob: String
var metadata_kvp: Dictionary
var sort: String
var limit: int
var offset: int
var id: String
var name_id: String
var status: int
var visible: int
var submitted_by: String

func _init(
	p_search_term: String = "",
	p_tags_all: PackedStringArray = PackedStringArray(),
	p_limit: int = 25,
	p_offset: int = 0,
	p_sort: String = "",
	p_tags_any: PackedStringArray = PackedStringArray(),
	p_tags_not_in: PackedStringArray = PackedStringArray(),
	p_metadata_blob: String = "",
	p_metadata_kvp: Dictionary = {},
	p_id: String = "",
	p_name_id: String = "",
	p_status: int = -1,
	p_visible: int = -1,
	p_submitted_by: String = ""
) -> void:
	search_term = p_search_term.strip_edges()
	tags_all = p_tags_all
	tags_any = p_tags_any
	tags_not_in = p_tags_not_in
	metadata_blob = p_metadata_blob.strip_edges()
	metadata_kvp = p_metadata_kvp.duplicate(true)
	sort = p_sort.strip_edges()
	limit = clampi(p_limit, 1, 100)
	offset = maxi(0, p_offset)
	id = p_id.strip_edges()
	name_id = p_name_id.strip_edges()
	status = p_status
	visible = p_visible
	submitted_by = p_submitted_by.strip_edges()

func to_query_dict() -> Dictionary:
	var query := {
		"_limit": str(limit),
		"_offset": str(offset)
	}

	if not search_term.is_empty():
		query["_q"] = search_term
	if not tags_all.is_empty():
		query["tags"] = ",".join(tags_all)
	if not tags_any.is_empty():
		query["tags-in"] = ",".join(tags_any)
	if not tags_not_in.is_empty():
		query["tags-not-in"] = ",".join(tags_not_in)
	if not metadata_blob.is_empty():
		query["metadata_blob"] = metadata_blob
	if not metadata_kvp.is_empty():
		query["metadata_kvp"] = _serialize_metadata_kvp(metadata_kvp)
	if not sort.is_empty():
		query["_sort"] = sort
	if not id.is_empty():
		query["id"] = id
	if not name_id.is_empty():
		query["name_id"] = name_id
	if status >= 0:
		query["status"] = str(status)
	if visible >= 0:
		query["visible"] = str(visible)
	if not submitted_by.is_empty():
		query["submitted_by"] = submitted_by

	return query

func _serialize_metadata_kvp(values: Dictionary) -> String:
	var pairs: PackedStringArray = []
	for key in values.keys():
		pairs.append("%s:%s" % [str(key), str(values[key])])
	return ",".join(pairs)
