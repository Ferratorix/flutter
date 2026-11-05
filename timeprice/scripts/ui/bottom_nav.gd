class_name BottomNav
extends PanelContainer
## Нижняя панель навигации по основным разделам.

signal tab_selected(route: String)

const ITEMS := [
	{"route": "home", "label": "Главная", "icon": "home"},
	{"route": "calculator", "label": "Калькулятор", "icon": "calculator"},
	{"route": "history", "label": "История", "icon": "history"},
]

var _items: Dictionary = {}


func _init() -> void:
	theme_type_variation = &"NavPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for item in ITEMS:
		var route: String = item["route"]
		var button := Button.new()
		button.theme_type_variation = &"NavButton"
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 58
		button.pressed.connect(func() -> void: tab_selected.emit(route))
		row.add_child(button)
		var column := VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 3)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(column)
		var icon := IconLibrary.rect(item["icon"], 24.0, AppTheme.TEXT_MUTED)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		var text := UI.label(item["label"])
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", AppTheme.FONT_SMALL)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(text)
		_items[route] = {"icon": icon, "label": text}


func set_selected(route: String) -> void:
	for key in _items:
		var selected: bool = key == route
		var color := AppTheme.ACCENT if selected else AppTheme.TEXT_MUTED
		var entry: Dictionary = _items[key]
		(entry["icon"] as TextureRect).self_modulate = color
		var l := entry["label"] as Label
		l.add_theme_color_override("font_color", color)
		l.add_theme_font_override("font", AppTheme.bold_font() if selected else AppTheme.regular_font())
