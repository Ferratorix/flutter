class_name Toast
extends MarginContainer
## Короткое уведомление внизу экрана.

var _panel: PanelContainer
var _label: Label
var _tween: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("margin_left", 16)
	add_theme_constant_override("margin_right", 16)
	add_theme_constant_override("margin_bottom", 96)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(UI.expander())
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"ToastPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_panel)
	_label = UI.label("", &"", true)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)
	_panel.modulate.a = 0.0
	_panel.visible = false


func show_message(message: String) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_label.text = message
	_panel.visible = true
	var hold := clampf(1.8 + message.length() * 0.035, 2.2, 6.0)
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	_tween.tween_interval(hold)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func() -> void: _panel.visible = false)
