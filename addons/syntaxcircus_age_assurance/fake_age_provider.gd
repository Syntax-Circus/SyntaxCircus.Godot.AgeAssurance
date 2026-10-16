extends RefCounted
const SignalPolicy = preload("res://addons/syntaxcircus_age_assurance/age_signal.gd")
signal released
var calls: Array[Dictionary] = []
var response: Dictionary = {"status":"unavailable"}
var hold := false
func check(minimum_age: int, allow_prompt: bool) -> Dictionary:
	calls.append({"minimum_age":minimum_age,"allow_prompt":allow_prompt})
	if hold: await released
	return SignalPolicy.normalize(response,minimum_age)
func finish() -> void:
	hold = false
	released.emit()
