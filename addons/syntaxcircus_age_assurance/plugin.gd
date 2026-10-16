@tool
extends EditorPlugin
const Export = preload("res://addons/syntaxcircus_age_assurance/export_plugin.gd")
var exporter: EditorExportPlugin
func _enter_tree() -> void:
	exporter = Export.new()
	add_export_plugin(exporter)
func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null
