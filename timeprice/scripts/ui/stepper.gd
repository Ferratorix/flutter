class_name Stepper
extends HBoxContainer
## Выбор целого значения кнопками «−» и «+».

signal value_changed(value: int)

var min_value: int = 0
var max_value: int = 100
var step: int = 1
var value: int = 0
## Функция форматирования int -> String.
var formatter: Callable

var _minus: Button
var _plus: Button
var _label: Label


func _init(p_min: int = 0, p_max: int = 100, p_step: int = 1, p_value: int = 0, p_formatter: Callable = Callable()) -> void:
	min_value = p_min
	max_value = p_max
	step = maxi(p_step, 1)
	formatter = p_formatter
	value = clampi(p_value, min_value, max_value)
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_minus = UI.button("", &"SecondaryButton", _on_minus)
	_minus.icon = IconLibrary.texture("minus")
	_minus.custom_minimum_size = Vector2(AppTheme.TOUCH_TARGET + 4, AppTheme.TOUCH_TARGET + 4)
	_minus.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_minus)

	_label = UI.label("", &"TitleLabel")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_label)

	_plus = UI.button("", &"SecondaryButton", _on_plus)
	_plus.icon = IconLibrary.texture("plus")
	_plus.custom_minimum_size = Vector2(AppTheme.TOUCH_TARGET + 4, AppTheme.TOUCH_TARGET + 4)
	_plus.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_plus)
	_refresh()


func set_value(new_value: int, notify: bool = true) -> void:
	var v := clampi(new_value, min_value, max_value)
	if v == value:
		_refresh()
		return
	value = v
	_refresh()
	if notify:
		value_changed.emit(value)


func _on_minus() -> void:
	set_value(value - step)


func _on_plus() -> void:
	set_value(value + step)


func _refresh() -> void:
	_label.text = formatter.call(value) if formatter.is_valid() else str(value)
	_minus.disabled = value <= min_value
	_plus.disabled = value >= max_value
