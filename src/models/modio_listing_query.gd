class_name ModioListingQuery
extends RefCounted

const ENDPOINT_MODS := "mods"
const ENDPOINT_MODFILES := "modfiles"
const ENDPOINT_SUBSCRIPTIONS := "subscriptions"

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

func to_query_dict(endpoint: String = ENDPOINT_MODS) -> Dictionary:
	var query := {
		"_limit": str(limit),
		"_offset": str(offset)
	}

	var capabilities := _get_capabilities(endpoint)
	if capabilities.has("search_term") and not search_term.is_empty():
		query["_q"] = search_term
	if capabilities.has("tags_all") and not tags_all.is_empty():
		query["tags"] = ",".join(tags_all)
	if capabilities.has("tags_any") and not tags_any.is_empty():
		query["tags-in"] = ",".join(tags_any)
	if capabilities.has("tags_not_in") and not tags_not_in.is_empty():
		query["tags-not-in"] = ",".join(tags_not_in)
	if capabilities.has("metadata_blob") and not metadata_blob.is_empty():
		query["metadata_blob"] = metadata_blob
	if capabilities.has("metadata_kvp") and not metadata_kvp.is_empty():
		query["metadata_kvp"] = _serialize_metadata_kvp(metadata_kvp)
	if capabilities.has("sort") and not sort.is_empty():
		query["_sort"] = sort
	if capabilities.has("id") and not id.is_empty():
		query["id"] = id
	if capabilities.has("name_id") and not name_id.is_empty():
		query["name_id"] = name_id
	if capabilities.has("status") and status >= 0:
		query["status"] = str(status)
	if capabilities.has("visible") and visible >= 0:
		query["visible"] = str(visible)
	if capabilities.has("submitted_by") and not submitted_by.is_empty():
		query["submitted_by"] = submitted_by

	return query

func _get_capabilities(endpoint: String) -> PackedStringArray:
	match endpoint:
		ENDPOINT_MODFILES:
			return PackedStringArray(["sort", "id"])
		ENDPOINT_SUBSCRIPTIONS:
			return PackedStringArray([
				"search_term",
				"tags_all",
				"tags_any",
				"tags_not_in",
				"metadata_blob",
				"metadata_kvp",
				"sort",
				"id",
				"name_id"
			])
		_:
			return PackedStringArray([
				"search_term",
				"tags_all",
				"tags_any",
				"tags_not_in",
				"metadata_blob",
				"metadata_kvp",
				"sort",
				"id",
				"name_id",
				"status",
				"visible",
				"submitted_by"
			])

func _serialize_metadata_kvp(values: Dictionary) -> String:
	var pairs: PackedStringArray = []
	var keys: Array = values.keys()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	for key in keys:
		pairs.append("%s:%s" % [str(key), str(values[key])])
	return ",".join(pairs)
