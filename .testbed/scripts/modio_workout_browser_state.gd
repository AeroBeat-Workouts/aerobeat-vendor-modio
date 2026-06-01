class_name ModioWorkoutBrowserState
extends RefCounted

const DEFAULT_PAGE_LIMIT := 9
const TAB_PUBLIC := "public"
const TAB_PROFILE := "profile"
const TAB_WORKOUT := "workout"
const TAB_SUBSCRIBED := "subscribed"
const TAB_UPLOAD := "upload"

var environment: String = "test"
var game_id: String = ""
var api_key: String = ""
var access_token: String = ""
var access_token_expires_at: int = 0
var user_id: String = ""
var email: String = ""
var last_requested_email: String = ""
var last_security_code: String = ""
var status_text: String = ""
var busy: bool = false
var active_tab: String = TAB_PUBLIC
var selected_mod_id: int = 0
var selected_mod_context: String = TAB_PUBLIC
var public_listing: Dictionary = _empty_listing()
var workout_listing: Dictionary = _empty_listing()
var subscribed_listing: Dictionary = _empty_listing()
var profile: Dictionary = {}
var wallet: Dictionary = {}
var purchased: Dictionary = _empty_listing()
var upload_draft: Dictionary = _default_upload_draft()
var upload_result: Dictionary = {}
var upload_status_text: String = ""
var raw_debug_sections: Dictionary = {}
var public_query: Dictionary = _default_query()
var workout_query: Dictionary = _default_query()
var subscribed_query: Dictionary = _default_query(true)

func can_browse_public() -> bool:
	return not game_id.is_empty() and not api_key.is_empty()

func is_authenticated() -> bool:
	return not access_token.is_empty()

func has_access_token_expiry() -> bool:
	return access_token_expires_at > 0

func is_access_token_expired(reference_time: int = 0) -> bool:
	var resolved_reference_time := reference_time if reference_time > 0 else int(Time.get_unix_time_from_system())
	return access_token_expires_at > 0 and access_token_expires_at <= resolved_reference_time

func clear_session() -> void:
	access_token = ""
	access_token_expires_at = 0
	user_id = ""
	profile = {}
	wallet = {}
	purchased = _empty_listing()
	subscribed_listing = _empty_listing()
	raw_debug_sections.erase("auth_exchange")
	raw_debug_sections.erase("profile")
	raw_debug_sections.erase("wallet")
	raw_debug_sections.erase("purchased")
	raw_debug_sections.erase("subscribed")
	selected_mod_id = 0
	selected_mod_context = TAB_PUBLIC

func query_for_context(context: String) -> Dictionary:
	match context:
		TAB_WORKOUT:
			return workout_query
		TAB_SUBSCRIBED:
			return subscribed_query
		_:
			return public_query

func listing_for_context(context: String) -> Dictionary:
	match context:
		TAB_WORKOUT:
			return workout_listing
		TAB_SUBSCRIBED:
			return subscribed_listing
		_:
			return public_listing

func set_listing_for_context(context: String, listing: Dictionary) -> void:
	match context:
		TAB_WORKOUT:
			workout_listing = listing
		TAB_SUBSCRIBED:
			subscribed_listing = listing
		_:
			public_listing = listing

func selected_mod() -> Dictionary:
	if selected_mod_id <= 0:
		return {}
	for entry in listing_for_context(selected_mod_context).get("data", []):
		if entry is Dictionary and int(entry.get("id", 0)) == selected_mod_id:
			return entry
	return {}

func remove_subscribed_mod(mod_id: int) -> void:
	if mod_id <= 0:
		return
	var current: Dictionary = subscribed_listing.duplicate(true)
	var next_data: Array = []
	for entry in current.get("data", []):
		if entry is Dictionary and int(entry.get("id", 0)) == mod_id:
			continue
		next_data.append(entry)
	current["data"] = next_data
	current["result_count"] = next_data.size()
	current["result_total"] = maxi(0, int(current.get("result_total", next_data.size())) - 1)
	var page: Dictionary = current.get("page", {}).duplicate(true)
	page["count"] = next_data.size()
	page["total"] = int(current.get("result_total", next_data.size()))
	page["has_next"] = int(page.get("next_offset", -1)) >= 0 and int(page.get("next_offset", -1)) < int(page.get("total", 0))
	page["has_previous"] = int(page.get("offset", 0)) > 0
	current["page"] = page
	subscribed_listing = current
	if selected_mod_id == mod_id and selected_mod_context == TAB_SUBSCRIBED:
		selected_mod_id = 0

static func _default_query(subscribed: bool = false) -> Dictionary:
	return {
		"search": "",
		"sort": "",
		"tags_all": PackedStringArray(),
		"tags_any": PackedStringArray(),
		"tags_not": PackedStringArray(),
		"offset": 0,
		"limit": DEFAULT_PAGE_LIMIT,
		"subscribed": subscribed
	}

static func _default_upload_draft() -> Dictionary:
	return {
		"name": "",
		"name_id": "",
		"summary": "",
		"description": "",
		"metadata_kvp": "",
		"tags": "boxing, easy, edm",
		"logo_path": "",
		"zip_path": "",
		"version": "",
		"changelog": "",
		"publish_after_upload": false
	}

static func _empty_listing() -> Dictionary:
	return {
		"data": [],
		"result_count": 0,
		"result_offset": 0,
		"result_limit": DEFAULT_PAGE_LIMIT,
		"result_total": 0,
		"page": {
			"count": 0,
			"offset": 0,
			"limit": DEFAULT_PAGE_LIMIT,
			"total": 0,
			"has_next": false,
			"has_previous": false,
			"next_offset": -1,
			"previous_offset": -1,
			"page_index": 0,
			"page_count": 0
		}
	}
