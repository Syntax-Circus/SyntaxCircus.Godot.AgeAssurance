extends RefCounted
## Explicitly invoked runtime adapter. No SDK work at construction. Serialized native requests,
## correlated by globally unique tokens; expired callbacks are discarded by the native bridge.
const SignalPolicy = preload("res://addons/syntaxcircus_age_assurance/age_signal.gd")
const SINGLETON := "SyntaxCircusAgeAssurance"
static var _sequence := 0
var _plugin: Object
var _busy := false
var _epoch := 0
var _active_request := 0
var _last_wire: Dictionary = {}
var timeout_seconds := 120.0

func _init(plugin: Object = null) -> void:
	_plugin = plugin
	if _plugin == null and Engine.has_singleton(SINGLETON): _plugin = Engine.get_singleton(SINGLETON)

func check(minimum_age: int, allow_prompt: bool) -> Dictionary:
	if _plugin == null or _busy:
		return SignalPolicy.normalize({},minimum_age)
	_busy = true
	_sequence += 1
	var request := _sequence
	_active_request = request
	var epoch := _epoch
	_plugin.request_check(request,minimum_age,allow_prompt)
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000)
	var wire: Dictionary = {}
	while Time.get_ticks_msec() < deadline:
		if epoch != _epoch: break
		var text: String = _plugin.take_result(request)
		if not text.is_empty():
			# JSON.parse_string logs malformed payloads; parse quietly to keep platform data out of logs.
			var parser := JSON.new()
			if parser.parse(text) == OK and parser.data is Dictionary: wire = parser.data
			break
		await Engine.get_main_loop().process_frame
	_plugin.cancel_check(request)
	_active_request = 0
	_busy = false
	if epoch != _epoch: return SignalPolicy.normalize({},minimum_age)
	if wire.get("reuse_session",false) == true:
		var current := _last_wire.duplicate(true)
		for key: String in ["mandatory","requirements"]:
			if wire.has(key): current[key] = wire[key]
		wire = current
	elif allow_prompt:
		_last_wire = wire.duplicate(true)
	return SignalPolicy.normalize(wire,minimum_age)

func cancel() -> void:
	_epoch += 1
	_last_wire.clear()
	if _plugin != null and _active_request != 0: _plugin.cancel_check(_active_request)
