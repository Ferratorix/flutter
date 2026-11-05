class_name UI
extends RefCounted
## Фабрика типовых элементов интерфейса на основе AppTheme.
## Тексты передаются на русском — Label и Button переводят их автоматически
## через TranslationServer, когда будут подключены переводы.


static func label(text: String, variation: StringName = &"", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, variation: StringName = &"", on_pressed: Variant = null) -> Button:
	var b := Button.new()
	b.text = text
	if variation != &"":
		b.theme_type_variation = variation
	b.custom_minimum_size.y = AppTheme.TOUCH_TARGET
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if on_pressed is Callable:
		b.pressed.connect(on_pressed)
	return b


static func icon_button(icon_name: String, on_pressed: Variant = null, tooltip: String = "") -> Button:
	var b := Button.new()
	b.theme_type_variation = &"IconButton"
	b.icon = IconLibrary.texture(icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(44, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tooltip
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if on_pressed is Callable:
		b.pressed.connect(on_pressed)
	return b


## Добавляет карточку в parent и возвращает её внутренний VBoxContainer.
static func card(parent: Control, variation: StringName = &"Card", separation: int = 12) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = variation
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	panel.add_child(box)
	return box


static func vbox(separation: int = 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


static func hbox(separation: int = 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


static func spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expander() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func separator() -> HSeparator:
	return HSeparator.new()


## Строка «название — значение».
static func kv_row(key: String, value: String, value_variation: StringName = &"") -> HBoxContainer:
	var row := hbox(12)
	var k := label(key, &"BodySecondaryLabel", true)
	row.add_child(k)
	var v := label(value, value_variation)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if value_variation == &"":
		v.add_theme_font_override("font", AppTheme.bold_font())
	row.add_child(v)
	return row


## Аккуратное пустое состояние: иконка, заголовок, пояснение.
static func empty_state(parent: Control, icon_name: String, title: String, text: String) -> VBoxContainer:
	var box := card(parent, &"Card", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var badge := icon_badge(icon_name, 52.0)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(badge)
	var t := label(title, &"ValueLabel", true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var d := label(text, &"CaptionLabel", true)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(d)
	return box


## Иконка в мягком акцентном квадрате.
static func icon_badge(icon_name: String, size: float = 44.0, color: Color = AppTheme.ACCENT) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"IconBadge"
	panel.custom_minimum_size = Vector2(size, size)
	var icon := IconLibrary.rect(icon_name, size * 0.5, color)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_child(icon)
	return panel


## Шапка экрана: [назад] Заголовок [действие].
static func top_bar(title: String, on_back: Variant = null) -> HBoxContainer:
	var bar := hbox(8)
	bar.custom_minimum_size.y = 52
	if on_back is Callable:
		bar.add_child(icon_button("back", on_back, "Назад"))
	var t := label(title, &"HeadingLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(t)
	return bar


static func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
