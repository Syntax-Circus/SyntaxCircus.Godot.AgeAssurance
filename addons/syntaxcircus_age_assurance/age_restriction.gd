extends RefCounted
## Consumers persist only this category, never a platform range. Ordinary failures cannot erase
## known restrictions; age eligibility alone cannot resolve a separately pending approval.
static func next(previous: String, result: Dictionary) -> String:
	if previous == "approval_required" and result.get("approval") != "approved": return previous
	var restriction := str(result.get("restriction",""))
	if restriction == "recheck_required" and not previous.is_empty(): return previous
	if restriction in ["below_minimum","verification_required","approval_required","recheck_required"]: return restriction
	if previous == "recheck_required" and result.get("status") == "declined": return ""
	if result.get("eligibility") == "eligible":
		if previous != "approval_required" or result.get("approval") == "approved": return ""
	return previous
