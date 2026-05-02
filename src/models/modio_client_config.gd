class_name ModioClientConfig
extends RefCounted

const DEFAULT_BASE_URL := "https://api.mod.io/v1"

var game_id: String
var api_key: String
var base_url: String

func _init(p_game_id: String = "", p_api_key: String = "", p_base_url: String = DEFAULT_BASE_URL) -> void:
	game_id = p_game_id.strip_edges()
	api_key = p_api_key.strip_edges()
	base_url = p_base_url.strip_edges()

func has_credentials() -> bool:
	return not game_id.is_empty() and not api_key.is_empty()
