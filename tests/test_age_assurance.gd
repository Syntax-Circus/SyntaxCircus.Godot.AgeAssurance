extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); print("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://addons/syntaxcircus_age_assurance/age_signal.gd"
	check(ResourceLoader.exists(path), "Shared age signal exists")
	if failures.is_empty():
		var policy = load(path)
		check(policy.normalize({"status":"shared","lower":13,"upper_exclusive":16},13).eligibility == "eligible", "13 meets 13")
		check(policy.normalize({"status":"shared","lower":0,"upper_exclusive":13},13).eligibility == "below_minimum", "Exclusive upper 13 is under 13")
		check(policy.normalize({"status":"shared","lower":13,"upper_exclusive":16},15).eligibility == "unknown", "Overlapping band is unknown")
		# Both platforms return inclusive upper 15; native bridges convert it to exclusive 16.
		check(policy.normalize({"status":"shared","lower":13,"upper_exclusive":15+1},15).restriction == "", "A band including age 15 cannot be classified wholly below minimum 15")
		check(policy.normalize({"status":"shared","lower":18},18).eligibility == "eligible", "Open upper band")
		check(policy.normalize({"status":"shared"},13).eligibility == "unknown", "Missing bounds are not adult")
		for wire in [{"status":"declined"},{"status":"unavailable"},{"status":"shared","lower":-2},{"status":"shared","lower":16,"upper_exclusive":13},{"status":"shared","lower":"18"}]:
			check(policy.normalize(wire,13).eligibility == "unknown", "Unknown/malformed values cannot authorize")
		check(policy.normalize({"status":"shared","lower":18,"approval":"pending"},13).restriction == "approval_required", "Approval outranks eligible age")
		check(policy.normalize({"status":"verification_required"},13).restriction == "verification_required", "Mandatory verification is distinct")
		check(policy.normalize({"status":"declined","mandatory":true},13).restriction == "verification_required", "Mandatory sharing has no fallback")
		check(policy.normalize({"status":"shared","lower":13,"requirements":["parental_consent"]},13).restriction == "", "Regulatory obligation alone is not pending approval")
		var fake = load("res://addons/syntaxcircus_age_assurance/fake_age_provider.gd").new()
		fake.response = {"status":"shared","lower":13,"upper_exclusive":16}
		check((await fake.check(13,true)).eligibility == "eligible" and fake.calls.size()==1, "Injectable fake uses real normalizer")
		var provider = load("res://addons/syntaxcircus_age_assurance/age_provider.gd").new()
		check((await provider.check(13,false)).status == "unavailable", "Absent native plugin is supported fallback")
	print("Age assurance: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
