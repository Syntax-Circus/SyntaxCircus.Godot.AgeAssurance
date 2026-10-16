extends RefCounted
## Versioned wire contract. lower is inclusive, upper_exclusive exclusive, omitted means unbounded.
## Bounds stay in memory only. Never infer adult status from missing bounds or sharing status.
static func normalize(wire: Dictionary, minimum_age: int) -> Dictionary:
	var status := str(wire.get("status","unavailable"))
	if status not in ["shared","declined","unavailable","verification_required","recheck_required"]: status = "unavailable"
	var result := {"status":status,"eligibility":"unknown","restriction":"","approval":"unknown","requirements":[]}
	if wire.get("approval","") in ["approved","pending","declined"]: result.approval = wire.approval
	for requirement: Variant in wire.get("requirements",[]) if wire.get("requirements") is Array else []:
		if requirement in ["parental_consent","adult_notification"]: result.requirements.append(requirement)
	if wire.get("approval","") in ["pending","declined"]:
		result.restriction = "approval_required"
	elif status == "verification_required":
		result.restriction = "verification_required"
	elif status == "recheck_required":
		result.restriction = "recheck_required"
	if status == "shared" and minimum_age > 0:
		var lower: Variant = wire.get("lower")
		var upper: Variant = wire.get("upper_exclusive")
		# JSON numeric values are floats. Accept only whole, nonnegative ages in a plausible range.
		var valid_lower := _bound(lower)
		var valid_upper := _bound(upper)
		if valid_lower and (upper == null or (valid_upper and int(upper) > int(lower))):
			if int(lower) >= minimum_age: result.eligibility = "eligible"
			elif valid_upper and int(upper) <= minimum_age: result.eligibility = "below_minimum"
		elif lower == null and valid_upper and int(upper) <= minimum_age:
			result.eligibility = "below_minimum"
	if result.eligibility == "below_minimum" and result.restriction.is_empty():
		result.restriction = "below_minimum"
	if wire.get("mandatory",false) == true and result.eligibility == "unknown" and result.restriction.is_empty():
		result.restriction = "verification_required"
	return result

static func _bound(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= 121
