class_name ModioListingQuery
extends RefCounted

const ENDPOINT_MODS := "mods"
const ENDPOINT_MODFILES := "modfiles"
const ENDPOINT_SUBSCRIPTIONS := "subscriptions"
const ENDPOINT_USER_RATINGS := "user_ratings"
const ENDPOINT_MOD_COMMENTS := "mod_comments"
const ENDPOINT_GUIDES := "guides"
const ENDPOINT_GUIDE_COMMENTS := "guide_comments"

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
var submitted_by_display_name: String
var game_id: String
var mod_id: String
var rating: int
var resource_type: String
var date_added: int
var date_updated: int
var date_live: int
var resource_id: String
var reply_id: int
var thread_position: String
var karma: int
var content: String

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
	p_submitted_by: String = "",
	p_game_id: String = "",
	p_mod_id: String = "",
	p_rating: int = 0,
	p_resource_type: String = "",
	p_date_added: int = 0,
	p_resource_id: String = "",
	p_reply_id: int = -1,
	p_thread_position: String = "",
	p_karma: int = 0,
	p_content: String = "",
	p_submitted_by_display_name: String = "",
	p_date_updated: int = 0,
	p_date_live: int = 0
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
	submitted_by_display_name = p_submitted_by_display_name.strip_edges()
	game_id = p_game_id.strip_edges()
	mod_id = p_mod_id.strip_edges()
	rating = p_rating
	resource_type = p_resource_type.strip_edges().to_lower()
	date_added = maxi(0, p_date_added)
	date_updated = maxi(0, p_date_updated)
	date_live = maxi(0, p_date_live)
	resource_id = p_resource_id.strip_edges()
	reply_id = p_reply_id
	thread_position = p_thread_position.strip_edges()
	karma = p_karma
	content = p_content.strip_edges()

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
	if capabilities.has("submitted_by_display_name") and not submitted_by_display_name.is_empty():
		query["submitted_by_display_name"] = submitted_by_display_name
	if capabilities.has("game_id") and not game_id.is_empty():
		query["game_id"] = game_id
	if capabilities.has("mod_id") and not mod_id.is_empty():
		query["mod_id"] = mod_id
	if capabilities.has("rating") and rating != 0:
		query["rating"] = str(rating)
	if capabilities.has("resource_type") and not resource_type.is_empty():
		query["resource_type"] = resource_type
	if capabilities.has("date_added") and date_added > 0:
		query["date_added"] = str(date_added)
	if capabilities.has("date_updated") and date_updated > 0:
		query["date_updated"] = str(date_updated)
	if capabilities.has("date_live") and date_live > 0:
		query["date_live"] = str(date_live)
	if capabilities.has("resource_id") and not resource_id.is_empty():
		query["resource_id"] = resource_id
	if capabilities.has("reply_id") and reply_id >= 0:
		query["reply_id"] = str(reply_id)
	if capabilities.has("thread_position") and not thread_position.is_empty():
		query["thread_position"] = thread_position
	if capabilities.has("karma") and karma != 0:
		query["karma"] = str(karma)
	if capabilities.has("content") and not content.is_empty():
		query["content"] = content

	return query

func _get_capabilities(endpoint: String) -> PackedStringArray:
	match endpoint:
		ENDPOINT_MODFILES:
			return PackedStringArray(["id"])
		ENDPOINT_USER_RATINGS:
			return PackedStringArray(["game_id", "mod_id", "rating", "resource_type", "date_added"])
		ENDPOINT_MOD_COMMENTS:
			return PackedStringArray([
				"id",
				"mod_id",
				"resource_id",
				"submitted_by",
				"date_added",
				"reply_id",
				"thread_position",
				"karma",
				"content"
			])
		ENDPOINT_GUIDE_COMMENTS:
			return PackedStringArray([
				"id",
				"resource_id",
				"submitted_by",
				"date_added",
				"reply_id",
				"thread_position",
				"karma",
				"content"
			])
		ENDPOINT_GUIDES:
			return PackedStringArray([
				"id",
				"game_id",
				"status",
				"submitted_by",
				"submitted_by_display_name",
				"date_added",
				"date_updated",
				"date_live",
				"name_id",
				"tags_all",
				"tags_any",
				"tags_not_in",
				"sort"
			])
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
				"name_id",
				"status",
				"visible",
				"submitted_by"
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
