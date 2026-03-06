extends Node

var send: bool = false # if we want to turn it off somewhere in code (like tutorial)

const SERVER_URL := "https://save.temp.olio.ovh"
const LEADERBOARD_URL := "https://save.temp.olio.ovh/leaderboard"
const SECRET := "underwater_"

var _is_web_build: bool = OS.has_feature("web")

## Submit score silently (fire and forget, no waiting, no UI)
func submit_score(name: String, time: float) -> void:
	if !send: return
	print("Leaderboard: submit_score called with name: ", name, ", time: ", time)
	var score_data := {
		"name": name,
		"time": time,
		"date": Time.get_datetime_string_from_system()
	}
	var json_str := JSON.stringify(score_data)
	var obscured := _obscure(json_str)

	var body := JSON.stringify({"data": obscured})
	print("Leaderboard: request body prepared: ", body)

	var http := HTTPRequest.new()
	add_child(http)
	print("Leaderboard: HTTPRequest node added to tree.")

	if _is_web_build:
		http.timeout = 10.0

	http.request_completed.connect(_cleanup_http.bind(http), CONNECT_ONE_SHOT)

	var headers := [
		"Content-Type: application/json",
		"Accept: application/json",
		"X-Requested-With: XMLHttpRequest"
	]

	print("Leaderboard: Sending POST request to: ", SERVER_URL + "/submit")
	var err = http.request(SERVER_URL + "/submit", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("Leaderboard ERROR: http.request returned error code: ", err)
	else:
		print("Leaderboard: Request dispatched successfully (waiting for response).")

## Open the leaderboard in the user's browser
func open_leaderboard() -> void:
	if _is_web_build:
		JavaScriptBridge.eval("window.open('%s', '_blank')" % LEADERBOARD_URL)
	else:
		OS.shell_open(LEADERBOARD_URL)

func _obscure(data: String) -> String:
	var combined := SECRET + data
	var bytes := combined.to_utf8_buffer()
	return Marshalls.raw_to_base64(bytes)

func _cleanup_http(http: HTTPRequest, result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray) -> void:
	print("Leaderboard: HTTP Request Completed! Result: ", result, ", Response Code: ", response_code)
	if response_body.size() > 0:
		print("Leaderboard: Response Body: ", response_body.get_string_from_utf8())
	else:
		print("Leaderboard: Response Body is empty.")
	http.queue_free()
	print("Leaderboard: HTTPRequest node freed.")
