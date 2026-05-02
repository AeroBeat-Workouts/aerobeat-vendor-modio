class_name ModioListingQuery
extends RefCounted

var search_term: String
var tags: PackedStringArray
var limit: int
var offset: int

func _init(p_search_term: String = "", p_tags: PackedStringArray = PackedStringArray(), p_limit: int = 25, p_offset: int = 0) -> void:
	search_term = p_search_term.strip_edges()
	tags = p_tags
	limit = maxi(1, p_limit)
	offset = maxi(0, p_offset)

func to_query_dict() -> Dictionary:
	var query := {
		"_limit": str(limit),
		"_offset": str(offset)
	}

	if not search_term.is_empty():
		query["_q"] = search_term
	if not tags.is_empty():
		query["tags"] = ",".join(tags)

	return query
