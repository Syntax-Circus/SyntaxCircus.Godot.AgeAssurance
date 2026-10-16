extends SceneTree
var failures: Array[String] = []
var checks := 0
class Bridge:
	extends RefCounted
	var active := 0
	var requests := 0
	var last_request := 0
	var cancels := 0
	var hold := false
	var answer := '{"status":"shared","lower":18}'
	func request_check(request: int, _minimum: int, _prompt: bool) -> void:
		active=request; last_request=request; requests+=1
	func take_result(request: int) -> String:
		return answer if request==active and not hold else ""
	func cancel_check(request: int) -> void:
		if active==request: active=0; cancels+=1
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message); print("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var bridge:=Bridge.new()
	var provider=load("res://addons/syntaxcircus_age_assurance/age_provider.gd").new(bridge)
	check(bridge.requests==0,"Construction never starts native SDK")
	check((await provider.check(13,true)).eligibility=="eligible" and bridge.cancels==1,"Native JSON is normalized and mailbox retired")
	bridge.answer='{"status":"unavailable","reuse_session":true}'
	check((await provider.check(16,false)).eligibility=="eligible","Silent Apple result reevaluates only the last completed range")
	bridge.hold=true
	provider.check(13,true)
	provider.cancel()
	await process_frame
	bridge.hold=false
	check((await provider.check(13,false)).eligibility=="unknown","Cancelled requests cannot repopulate the session cache")
	bridge.answer="malformed"
	check((await provider.check(13,true)).eligibility=="unknown","Malformed native JSON cannot authorize")
	bridge.hold=true; provider.timeout_seconds=0.001
	var previous: int=bridge.last_request
	check((await provider.check(13,true)).status=="unavailable" and bridge.active==0,"Expired check cancels native mailbox")
	bridge.hold=false; bridge.answer='{"status":"verification_required"}'
	check((await provider.check(13,true)).restriction=="verification_required" and previous!=bridge.last_request,"Subsequent request cannot receive previous answer")
	print("Native adapter: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
