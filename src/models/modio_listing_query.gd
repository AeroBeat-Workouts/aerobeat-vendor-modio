class_name ModioListingQuery
extends RefCounted

const ENDPOINT_MODS := "mods"
const ENDPOINT_MODFILES := "modfiles"
const ENDPOINT_SUBSCRIPTIONS := "subscriptions"
const ENDPOINT_GAMES := "games"
const ENDPOINT_GAME_MOD_STATS := "game_mod_stats"
const ENDPOINT_USER_GAMES := "user_games"
const ENDPOINT_USER_MODS := "user_mods"
const ENDPOINT_USER_MODFILES := "user_modfiles"
const ENDPOINT_MOD_DEPENDANTS := "mod_dependants"
const ENDPOINT_MOD_EVENTS := "mod_events"
const ENDPOINT_MODS_EVENTS := "mods_events"
const ENDPOINT_MOD_TAGS := "mod_tags"
const ENDPOINT_MOD_TEAM := "mod_team"
const ENDPOINT_USER_RATINGS := "user_ratings"
const ENDPOINT_MOD_COMMENTS := "mod_comments"
const ENDPOINT_GUIDES := "guides"
const ENDPOINT_GUIDE_COMMENTS := "guide_comments"
const ENDPOINT_COLLECTIONS := "collections"
const ENDPOINT_COLLECTION_MODS := "collection_mods"
const ENDPOINT_COLLECTION_COMMENTS := "collection_comments"
const ENDPOINT_USER_SOCIAL := "user_social"
const ENDPOINT_USER_COLLECTIONS := "user_collections"
const ENDPOINT_USER_PURCHASED := "user_purchased"

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
var user_id: String
var username: String
var submitted_by_display_name: String
var category: String
var maturity_option: int
var name: String
var game_id: String
var mod_id: String
var event_type: String = ""
var latest = null
var subscribed = null
var modfile: String
var rating: int
var resource_type: String
var date_added: int
var date_updated: int
var date_live: int
var date_scanned: int
var resource_id: String
var tag: String
var level: int
var pending: int
var virus_status: int
var virus_positive: int
var filesize: int
var reply_id: int
var thread_position: String
var karma: int
var content: String
var filehash: String = ""
var filename: String = ""
var version: String = ""
var changelog: String = ""
var platform_status: String = ""
var platforms: String = ""
var show_hidden_mods: bool
var summary: String = ""
var instructions_url: String = ""
var ugc_name: String = ""
var presentation_option: int = -1
var submission_option: int = -1
var curation_option: int = -1
var profanity_option: int = -1
var community_options: int = -1
var monetization_options: int = -1
var api_access_options: int = -1
var dependency_option: int = -1

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
	p_date_live: int = 0,
	p_category: String = "",
	p_maturity_option: int = -1,
	p_name: String = "",
	p_show_hidden_mods: bool = false,
	p_user_id: String = "",
	p_username: String = "",
	p_tag: String = "",
	p_level: int = -1,
	p_pending: int = -1,
	p_modfile: String = "",
	p_date_scanned: int = 0,
	p_virus_status: int = -1,
	p_virus_positive: int = -1,
	p_filesize: int = -1,
	p_filehash: String = "",
	p_filename: String = "",
	p_version: String = "",
	p_changelog: String = "",
	p_platform_status: String = "",
	p_platforms: String = ""
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
	user_id = p_user_id.strip_edges()
	username = p_username.strip_edges()
	submitted_by_display_name = p_submitted_by_display_name.strip_edges()
	category = p_category.strip_edges()
	maturity_option = p_maturity_option
	name = p_name.strip_edges()
	game_id = p_game_id.strip_edges()
	mod_id = p_mod_id.strip_edges()
	event_type = ""
	latest = null
	subscribed = null
	modfile = p_modfile.strip_edges()
	rating = p_rating
	resource_type = p_resource_type.strip_edges().to_lower()
	date_added = maxi(0, p_date_added)
	date_updated = maxi(0, p_date_updated)
	date_live = maxi(0, p_date_live)
	date_scanned = maxi(0, p_date_scanned)
	resource_id = p_resource_id.strip_edges()
	tag = p_tag.strip_edges()
	level = p_level
	pending = p_pending
	virus_status = p_virus_status
	virus_positive = p_virus_positive
	filesize = p_filesize
	reply_id = p_reply_id
	thread_position = p_thread_position.strip_edges()
	karma = p_karma
	content = p_content.strip_edges()
	filehash = p_filehash.strip_edges()
	filename = p_filename.strip_edges()
	version = p_version.strip_edges()
	changelog = p_changelog.strip_edges()
	platform_status = p_platform_status.strip_edges()
	platforms = p_platforms.strip_edges()
	show_hidden_mods = p_show_hidden_mods

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
	if capabilities.has("sort"):
		var sanitized_sort := _sanitize_sort(endpoint, sort)
		if not sanitized_sort.is_empty():
			query["_sort"] = sanitized_sort
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
	if capabilities.has("user_id") and not user_id.is_empty():
		query["user_id"] = user_id
	if capabilities.has("username") and not username.is_empty():
		query["username"] = username
	if capabilities.has("submitted_by_display_name") and not submitted_by_display_name.is_empty():
		query["submitted_by_display_name"] = submitted_by_display_name
	if capabilities.has("category") and not category.is_empty():
		query["category"] = category
	if capabilities.has("maturity_option") and maturity_option >= 0:
		if endpoint == ENDPOINT_GAMES or endpoint == ENDPOINT_USER_GAMES:
			query["maturity_options"] = str(maturity_option)
		else:
			query["maturity_option"] = str(maturity_option)
	if capabilities.has("presentation_option") and presentation_option >= 0:
		query["presentation_option"] = str(presentation_option)
	if capabilities.has("submission_option") and submission_option >= 0:
		query["submission_option"] = str(submission_option)
	if capabilities.has("curation_option") and curation_option >= 0:
		query["curation_option"] = str(curation_option)
	if capabilities.has("profanity_option") and profanity_option >= 0:
		query["profanity_option"] = str(profanity_option)
	if capabilities.has("community_options") and community_options >= 0:
		query["community_options"] = str(community_options)
	if capabilities.has("monetization_options") and monetization_options >= 0:
		query["monetization_options"] = str(monetization_options)
	if capabilities.has("api_access_options") and api_access_options >= 0:
		query["api_access_options"] = str(api_access_options)
	if capabilities.has("dependency_option") and dependency_option >= 0:
		query["dependency_option"] = str(dependency_option)
	if capabilities.has("name") and not name.is_empty():
		query["name"] = name
	if capabilities.has("summary") and not summary.is_empty():
		query["summary"] = summary
	if capabilities.has("instructions_url") and not instructions_url.is_empty():
		query["instructions_url"] = instructions_url
	if capabilities.has("ugc_name") and not ugc_name.is_empty():
		query["ugc_name"] = ugc_name
	if capabilities.has("game_id") and not game_id.is_empty():
		query["game_id"] = game_id
	if capabilities.has("mod_id") and not mod_id.is_empty():
		query["mod_id"] = mod_id
	if capabilities.has("event_type") and not event_type.is_empty():
		query["event_type"] = event_type
	if capabilities.has("latest") and typeof(latest) == TYPE_BOOL:
		query["latest"] = latest
	if capabilities.has("subscribed") and typeof(subscribed) == TYPE_BOOL:
		query["subscribed"] = subscribed
	if capabilities.has("modfile") and not modfile.is_empty():
		query["modfile"] = modfile
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
	if capabilities.has("date_scanned") and date_scanned > 0:
		query["date_scanned"] = str(date_scanned)
	if capabilities.has("resource_id") and not resource_id.is_empty():
		query["resource_id"] = resource_id
	if capabilities.has("tag") and not tag.is_empty():
		query["tag"] = tag
	if capabilities.has("level") and level >= 0:
		query["level"] = str(level)
	if capabilities.has("pending") and pending >= 0:
		query["pending"] = str(pending)
	if capabilities.has("virus_status") and virus_status >= 0:
		query["virus_status"] = str(virus_status)
	if capabilities.has("virus_positive") and virus_positive >= 0:
		query["virus_positive"] = str(virus_positive)
	if capabilities.has("filesize") and filesize >= 0:
		query["filesize"] = str(filesize)
	if capabilities.has("reply_id") and reply_id >= 0:
		query["reply_id"] = str(reply_id)
	if capabilities.has("thread_position") and not thread_position.is_empty():
		query["thread_position"] = thread_position
	if capabilities.has("karma") and karma != 0:
		query["karma"] = str(karma)
	if capabilities.has("content") and not content.is_empty():
		query["content"] = content
	if capabilities.has("filehash") and not filehash.is_empty():
		query["filehash"] = filehash
	if capabilities.has("filename") and not filename.is_empty():
		query["filename"] = filename
	if capabilities.has("version") and not version.is_empty():
		query["version"] = version
	if capabilities.has("changelog") and not changelog.is_empty():
		query["changelog"] = changelog
	if capabilities.has("platform_status") and not platform_status.is_empty():
		query["platform_status"] = platform_status
	if capabilities.has("platforms") and not platforms.is_empty():
		query["platforms"] = platforms
	if capabilities.has("show_hidden_mods") and show_hidden_mods:
		if endpoint == ENDPOINT_GAMES or endpoint == ENDPOINT_USER_GAMES:
			query["show_hidden_tags"] = true
		else:
			query["show_hidden_mods"] = true

	return query

func _get_capabilities(endpoint: String) -> PackedStringArray:
	match endpoint:
		ENDPOINT_GAMES, ENDPOINT_USER_GAMES:
			return PackedStringArray([
				"id",
				"status",
				"submitted_by",
				"date_added",
				"date_updated",
				"date_live",
				"name",
				"name_id",
				"summary",
				"instructions_url",
				"ugc_name",
				"presentation_option",
				"submission_option",
				"curation_option",
				"profanity_option",
				"dependency_option",
				"community_options",
				"monetization_options",
				"api_access_options",
				"maturity_option",
				"show_hidden_mods",
				"sort"
			])
		ENDPOINT_GAME_MOD_STATS:
			return PackedStringArray(["mod_id"])
		ENDPOINT_USER_MODS:
			return PackedStringArray([
				"tags_all",
				"metadata_blob",
				"metadata_kvp",
				"sort",
				"id",
				"name_id",
				"status",
				"visible",
				"submitted_by",
				"game_id",
				"date_added",
				"date_updated",
				"date_live",
				"name",
				"modfile",
				"maturity_option",
				"monetization_options",
				"platform_status"
			])
		ENDPOINT_USER_MODFILES:
			return PackedStringArray([
				"id",
				"mod_id",
				"date_added",
				"date_scanned",
				"virus_status",
				"virus_positive",
				"filesize",
				"filehash",
				"filename",
				"version",
				"changelog",
				"metadata_blob",
				"platform_status"
			])
		ENDPOINT_MOD_DEPENDANTS:
			return PackedStringArray([])
		ENDPOINT_MOD_EVENTS:
			return PackedStringArray([])
		ENDPOINT_MODS_EVENTS:
			return PackedStringArray(["id", "mod_id", "user_id", "date_added", "event_type", "latest", "subscribed"])
		ENDPOINT_MOD_TAGS:
			return PackedStringArray(["date_added", "tag"])
		ENDPOINT_MOD_TEAM:
			return PackedStringArray(["id", "user_id", "username", "level", "date_added", "pending"])
		ENDPOINT_USER_SOCIAL:
			return PackedStringArray([])
		ENDPOINT_USER_COLLECTIONS:
			return PackedStringArray([])
		ENDPOINT_COLLECTIONS:
			return PackedStringArray([
				"id",
				"status",
				"mod_id",
				"category",
				"submitted_by",
				"submitted_by_display_name",
				"date_added",
				"date_updated",
				"date_live",
				"name",
				"name_id",
				"maturity_option",
				"tags_all",
				"tags_any",
				"tags_not_in",
				"sort"
			])
		ENDPOINT_COLLECTION_MODS:
			return PackedStringArray([
				"sort",
				"maturity_option",
				"show_hidden_mods"
			])
		ENDPOINT_COLLECTION_COMMENTS:
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
		ENDPOINT_USER_PURCHASED:
			return PackedStringArray([
				"id",
				"game_id",
				"status",
				"visible",
				"submitted_by",
				"date_added",
				"date_updated",
				"date_live",
				"name",
				"name_id",
				"modfile",
				"metadata_kvp",
				"metadata_blob",
				"tags_all",
				"maturity_option",
				"monetization_options",
				"platform_status",
				"platforms",
				"sort"
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

func _get_allowed_sorts(endpoint: String) -> PackedStringArray:
	match endpoint:
		ENDPOINT_GAMES, ENDPOINT_USER_GAMES:
			return PackedStringArray([
				"name",
				"date_live",
				"date_updated",
				"downloads_today",
				"downloads_total",
				"subscribers_total",
				"mods_count_total"
			])
		ENDPOINT_GAME_MOD_STATS:
			return PackedStringArray([])
		ENDPOINT_USER_MODS:
			return PackedStringArray([
				"name",
				"date_live",
				"date_updated",
				"submitted_by",
				"downloads_today",
				"downloads_total",
				"subscribers_total",
				"ratings_weighted_aggregate"
			])
		ENDPOINT_USER_MODFILES:
			return PackedStringArray([])
		ENDPOINT_USER_SOCIAL:
			return PackedStringArray([])
		ENDPOINT_USER_COLLECTIONS:
			return PackedStringArray([])
		ENDPOINT_COLLECTIONS:
			return PackedStringArray([
				"name",
				"date_live",
				"date_updated"
			])
		ENDPOINT_COLLECTION_MODS:
			return PackedStringArray([
				"name",
				"date_live",
				"date_updated",
				"downloads_today",
				"downloads_total",
				"subscribers_total",
				"mods_count_total"
			])
		ENDPOINT_MODS:
			return PackedStringArray([
				"name",
				"date_live",
				"date_updated",
				"submitted_by",
				"downloads_today",
				"downloads_total",
				"subscribers_total",
				"ratings_weighted_aggregate"
			])
		ENDPOINT_SUBSCRIPTIONS:
			return PackedStringArray([
				"name",
				"date_live",
				"date_updated",
				"submitted_by",
				"downloads_today",
				"downloads_total",
				"subscribers_total"
			])
		ENDPOINT_USER_PURCHASED:
			return PackedStringArray([
				"name",
				"date_live",
				"date_updated",
				"submitted_by",
				"downloads_today",
				"downloads_total",
				"subscribers_total",
				"ratings_weighted_aggregate"
			])
		ENDPOINT_GUIDES:
			return PackedStringArray([
				"name",
				"date_live",
				"date_updated",
				"submitted_by",
				"visits_today",
				"visits_total",
				"comments_total"
			])
		_:
			return PackedStringArray()

func _sanitize_sort(endpoint: String, raw_sort: String) -> String:
	var candidate := raw_sort.strip_edges()
	if candidate.is_empty():
		return ""
	var sort_key := candidate.substr(1) if candidate.begins_with("-") else candidate
	var allowed_sorts := _get_allowed_sorts(endpoint)
	if allowed_sorts.has(sort_key):
		return candidate
	return ""

func _serialize_metadata_kvp(values: Dictionary) -> String:
	var pairs: PackedStringArray = []
	var keys: Array = values.keys()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	for key in keys:
		pairs.append("%s:%s" % [str(key), str(values[key])])
	return ",".join(pairs)
