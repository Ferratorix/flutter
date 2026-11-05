class_name FormKit
extends RefCounted
## Поля форм для финансовых калькуляторов: суммы, ставки, сроки, переключатели.


static func amount(title: String, placeholder: String, currency_code: String, helper: String = "") -> InputField:
	var f := InputField.new(InputField.Mode.AMOUNT, title, placeholder, Currency.symbol(currency_code))
	if not helper.is_empty():
		f.set_helper(helper)
	return f


## Ставка в процентах годовых; get_amount() возвращает сотые доли процента (16,5 -> 1650).
static func rate(title: String, placeholder: String, helper: String = "") -> InputField:
	var f := InputField.new(InputField.Mode.AMOUNT, title, placeholder, "%")
	f.fraction_digits = FinanceMath.RATE_DIGITS
	f.max_value = FinanceMath.MAX_RATE
	if not helper.is_empty():
		f.set_helper(helper)
	return f


## Срок в месяцах с быстрыми вариантами.
static func term(parent: Control, title: String, presets: Array) -> InputField:
	var f := InputField.new(InputField.Mode.AMOUNT, title, "Например, 12", Loc.t("мес."))
	f.fraction_digits = 0
	f.max_value = FinanceMath.MAX_TERM_MONTHS
	parent.add_child(f)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	parent.add_child(chips)
	for months in presets:
		var m: int = months
		var label := Fmt.months_duration(m) if m % 12 == 0 else Loc.tf("%d мес.", [m])
		var chip := UI.button(label, &"ChipButton", func() -> void:
			f.set_amount(m)
			f.changed.emit())
		chip.custom_minimum_size = Vector2(0, 36)
		chips.add_child(chip)
	return f


## Переключатель из нескольких вариантов: options = [[значение, подпись], ...].
static func segmented(options: Array, selected: String, on_change: Callable) -> HBoxContainer:
	var row := UI.hbox(8)
	var group := ButtonGroup.new()
	for option in options:
		var value: String = option[0]
		var chip := UI.button(option[1], &"ChipButton")
		chip.toggle_mode = true
		chip.button_group = group
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size.y = 44
		chip.button_pressed = value == selected
		chip.toggled.connect(func(on: bool) -> void:
			if on:
				on_change.call(value))
		row.add_child(chip)
	return row


## Ставка для отображения: 1650 -> "16,5 %".
static func rate_text(rate_h: int) -> String:
	return Fmt.percent(rate_h / 100.0)


## Сумма в рабочем времени по профилю: "≈ 26 ч 24 мин работы"; "" — нельзя посчитать.
static func work_time_text(amount_minor: int) -> String:
	var profile := DataManager.profile
	if amount_minor <= 0 or not profile.is_valid():
		return ""
	var minutes := FinancialCalculator.purchase_minutes(amount_minor, profile.monthly_income_minor,
		profile.working_days, profile.work_minutes_per_day)
	return Loc.tf("≈ %s работы", [Fmt.duration(minutes)])


## Блок-предупреждение.
static func notice(parent: Control, text: String, color: Color = AppTheme.WARNING, icon_name: String = "info") -> void:
	var box := UI.card(parent, &"Card", 10)
	var row := UI.hbox(12)
	box.add_child(row)
	row.add_child(UI.icon_badge(icon_name, 36.0, color))
	row.add_child(UI.label(text, &"CaptionLabel", true))


## Значение поля для сохранения: -1 — пусто или ошибка.
static func stored_value(field: InputField) -> int:
	var v := field.get_amount()
	return v if v >= 0 else -1


static func restore(field: InputField, values: Dictionary, key: String) -> void:
	var v: Variant = values.get(key, -1)
	if typeof(v) == TYPE_INT and v >= 0:
		field.set_amount(v)
