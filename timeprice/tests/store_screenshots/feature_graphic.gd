extends Control
## Feature Graphic 1024×500 для Google Play.
## Запуск: godot --path timeprice --resolution 1024x500 res://tests/store_screenshots/feature_graphic.tscn
## Результат: user://store_screenshots/feature_graphic.png


func _ready() -> void:
	theme = AppTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var k := get_viewport_rect().size.y / 500.0  # логических пикселей на пиксель картинки
	var bg := ColorRect.new()
	bg.color = AppTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, int(64 * k))
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(48 * k))
	margin.add_child(row)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", int(10 * k))
	row.add_child(left)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(18 * k))
	left.add_child(head)
	head.add_child(UI.icon_badge("clock", 76.0 * k))
	var name_label := _label("TIMEPRICE", 52 * k, AppTheme.TEXT, true)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(name_label)
	left.add_child(_label("Узнай, сколько на самом деле\nстоят твои покупки", 30 * k, AppTheme.TEXT, true))
	left.add_child(_label("Твои деньги. Твоё время. Твой выбор.", 20 * k, AppTheme.TEXT_SECONDARY, false))

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.custom_minimum_size.x = 330 * k
	row.add_child(right)
	var card := PanelContainer.new()
	card.theme_type_variation = &"AccentCard"
	var sb := AppTheme.stylebox(Color(0.11, 0.2, 0.22), int(28 * k), Color(0.2039, 0.7765, 0.6588, 0.35), 2, 32 * k, 28 * k)
	card.add_theme_stylebox_override("panel", sb)
	right.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(6 * k))
	card.add_child(box)
	box.add_child(_label("Смартфон · 350 000 ₸", 19 * k, AppTheme.TEXT_SECONDARY, false))
	box.add_child(_label("154 ч", 64 * k, AppTheme.ACCENT, true))
	box.add_child(_label("вашего рабочего времени", 19 * k, AppTheme.TEXT_SECONDARY, false))
	box.add_child(_label("19,3 рабочего дня · 87,5 % дохода", 17 * k, AppTheme.TEXT_MUTED, false))

	for i in 40:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("user://store_screenshots")
	get_viewport().get_texture().get_image().save_png("user://store_screenshots/feature_graphic.png")
	get_tree().quit()


func _label(text: String, size: float, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(size))
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", AppTheme.bold_font())
	return l
