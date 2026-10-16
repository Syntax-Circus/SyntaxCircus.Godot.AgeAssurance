@tool
extends EditorExportPlugin
const DEPENDENCY := "com.google.android.play:age-signals:0.0.4"
func _get_name() -> String: return "SyntaxCircusAgeAssurance"
func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid
func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	var flavor := "debug" if debug else "release"
	return PackedStringArray(["syntaxcircus_age_assurance/bin/%s/SyntaxCircusAgeAssurance-%s.aar" % [flavor,flavor]])
func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray([DEPENDENCY])
