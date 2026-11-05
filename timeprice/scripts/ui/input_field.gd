class_name InputField
extends VBoxContainer
## Поле ввода с подписью, суффиксом (валюта), подсказкой и сообщением об ошибке.
## Режим AMOUNT разбирает ввод в минимальные денежные единицы (см. Money).

signal changed
signal submitted

enum Mode { TEXT, AMOUNT }

## Возвращается get_amount() для пустого поля.
const EMPTY := -2

var mode: Mode = Mode.TEXT
var fraction_digits: int = Money.MINOR_DIGITS
var max_value: int = Money.MAX_MINOR

var line_edit: LineEdit
var _title: Label
var _panel: PanelContainer
var _suffix: Label
var _helper: Label
var _error: Label
var _has_error := false


func _init(p_mode: Mode = Mode.TEXT, title: String = "", placeholder: String = "", suffix: String = "") -> void:
	mode = p_mode
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_title = UI.label(title, &"CaptionLabel")
	_title.visible = not title.is_empty()
	add_child(_title)

	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"InputPanel"
	_panel.custom_minimum_size.y = AppTheme.TOUCH_TARGET
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_panel.add_child(row)

	line_edit = LineEdit.new()
	line_edit.theme_type_variation = &"BareLineEdit"
	line_edit.placeholder_text = placeholder
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.max_length = 80 if mode == Mode.TEXT else 24
	line_edit.context_menu_enabled = false
	if mode == Mode.AMOUNT:
		line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	row.add_child(line_edit)

	_suffix = UI.label(suffix, &"BodySecondaryLabel")
	_suffix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_suffix.visible = not suffix.is_empty()
	row.add_child(_suffix)

	_error = UI.label("", &"ErrorLabel", true)
	_error.visible = false
	add_child(_error)

	_helper = UI.label("", &"MutedLabel", true)
	_helper.visible = false
	add_child(_helper)

	line_edit.text_changed.connect(_on_text_changed)
	line_edit.text_submitted.connect(_on_text_submitted)
	line_edit.focus_entered.connect(_update_panel_style)
	line_edit.focus_exited.connect(_on_focus_exited)


func set_suffix(text: String) -> void:
	_suffix.text = text
	_suffix.visible = not text.is_empty()


func set_title(text: String) -> void:
	_title.text = text
	_title.visible = not text.is_empty()


func set_helper(text: String) -> void:
	_helper.text = text
	_helper.visible = not text.is_empty() and not _has_error


func set_error(text: String) -> void:
	_has_error = not text.is_empty()
	_error.text = text
	_error.visible = _has_error
	_helper.visible = not _has_error and not _helper.text.is_empty()
	_update_panel_style()


func clear_error() -> void:
	set_error("")


func get_text() -> String:
	return line_edit.text.strip_edges()


func set_text(value: String) -> void:
	line_edit.text = value


## Сумма в минимальных единицах; EMPTY — поле пустое; Money.INVALID — ошибка ввода.
func get_amount() -> int:
	if Money.normalize_input(line_edit.text).is_empty():
		return EMPTY
	return Money.parse(line_edit.text, fraction_digits, max_value)


func set_amount(minor: int) -> void:
	if minor < 0:
		line_edit.text = ""
	else:
		line_edit.text = Money.to_input_text(minor, fraction_digits)


func focus() -> void:
	line_edit.grab_focus()


func _on_text_changed(new_text: String) -> void:
	if mode == Mode.AMOUNT:
		var filtered := _filter_amount(new_text)
		if filtered != new_text:
			var caret := line_edit.caret_column
			line_edit.text = filtered
			line_edit.caret_column = mini(caret, filtered.length())
	if _has_error:
		clear_error()
	changed.emit()


func _on_text_submitted(_text: String) -> void:
	line_edit.release_focus()
	submitted.emit()


func _on_focus_exited() -> void:
	_update_panel_style()
	if mode == Mode.AMOUNT:
		var value := get_amount()
		if value >= 0:
			set_amount(value)


func _update_panel_style() -> void:
	if _has_error:
		_panel.theme_type_variation = &"InputPanelError"
	elif line_edit.has_focus():
		_panel.theme_type_variation = &"InputPanelFocus"
	else:
		_panel.theme_type_variation = &"InputPanel"


## Оставляет только цифры, пробелы и десятичный разделитель.
static func _filter_amount(text: String) -> String:
	var out := ""
	for i in text.length():
		var ch := text[i]
		var c := text.unicode_at(i)
		if (c >= 48 and c <= 57) or ch == " " or ch == "," or ch == "." or ch == " ":
			out += ch
	return out
