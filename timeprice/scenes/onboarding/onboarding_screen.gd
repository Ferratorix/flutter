extends BaseScreen
## Первоначальная настройка: приветствие, доход, рабочие дни, часы, валюта, подтверждение.

enum Step { WELCOME, INCOME, DAYS, HOURS, CURRENCY, SUMMARY }
const STEP_COUNT := 6

var _step: int = Step.WELCOME
var _income_minor: int = -1
var _days: int = UserProfile.DEFAULT_WORKING_DAYS
var _minutes: int = UserProfile.DEFAULT_WORK_MINUTES
var _currency: String = Currency.DEFAULT_CODE

var _back_button: Button
var _dots: HBoxContainer
var _body: VBoxContainer
var _next_button: Button
var _income_field: InputField
var _days_stepper: Stepper
var _hours_stepper: Stepper


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Шапка: «назад» и индикатор шагов.
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 12)
	header_margin.add_theme_constant_override("margin_right", AppTheme.SCREEN_PADDING)
	header_margin.add_theme_constant_override("margin_top", 8)
	root.add_child(header_margin)
	var header := UI.hbox(8)
	header.custom_minimum_size.y = 48
	header_margin.add_child(header)
	_back_button = UI.icon_button("back", _go_previous, "Назад")
	header.add_child(_back_button)
	header.add_child(UI.expander())
	_dots = UI.hbox(6)
	_dots.size_flags_horizontal = Control.SIZE_SHRINK_END
	_dots.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(_dots)

	_body = build_scroll_layout(root, 18)

	var footer := MarginContainer.new()
	footer.add_theme_constant_override("margin_left", AppTheme.SCREEN_PADDING)
	footer.add_theme_constant_override("margin_right", AppTheme.SCREEN_PADDING)
	footer.add_theme_constant_override("margin_bottom", 16)
	footer.add_theme_constant_override("margin_top", 8)
	root.add_child(footer)
	_next_button = UI.button("", &"PrimaryButton", _go_next)
	footer.add_child(_next_button)

	# Если профиль уже был (повторная настройка), подставляем его значения.
	var existing := DataManager.profile
	if existing.monthly_income_minor > 0:
		_income_minor = existing.monthly_income_minor
		_days = existing.working_days
		_minutes = existing.work_minutes_per_day
		_currency = existing.currency
	_show_step(Step.WELCOME)


func handle_back() -> bool:
	if _step > Step.WELCOME:
		_go_previous()
		return true
	return false


func _go_previous() -> void:
	if _step > Step.WELCOME:
		_show_step(_step - 1)


func _go_next() -> void:
	match _step:
		Step.INCOME:
			if not _validate_income():
				return
		Step.SUMMARY:
			_finish()
			return
	_show_step(_step + 1)


func _show_step(step: int) -> void:
	_step = clampi(step, 0, STEP_COUNT - 1)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	UI.clear_children(_body)
	_income_field = null
	_back_button.modulate.a = 1.0 if _step > Step.WELCOME else 0.0
	_back_button.disabled = _step == Step.WELCOME
	_update_dots()
	match _step:
		Step.WELCOME:
			_build_welcome()
			_next_button.text = "Начать настройку"
		Step.INCOME:
			_build_income()
			_next_button.text = "Далее"
		Step.DAYS:
			_build_days()
			_next_button.text = "Далее"
		Step.HOURS:
			_build_hours()
			_next_button.text = "Далее"
		Step.CURRENCY:
			_build_currency()
			_next_button.text = "Далее"
		Step.SUMMARY:
			_build_summary()
			_next_button.text = "Перейти на главную"
	if scroll != null:
		scroll.scroll_vertical = 0
	if not SettingsManager.reduce_motion:
		_body.modulate.a = 0.0
		create_tween().tween_property(_body, "modulate:a", 1.0, 0.2)


func _update_dots() -> void:
	UI.clear_children(_dots)
	if _step == Step.WELCOME:
		return
	for i in range(1, STEP_COUNT):
		var dot := ColorRect.new()
		var active := i <= _step
		dot.custom_minimum_size = Vector2(18 if i == _step else 8, 6)
		dot.color = AppTheme.ACCENT if active else AppTheme.SURFACE_3
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(dot)


func _step_header(step_title: String, text: String) -> void:
	_body.add_child(UI.label(Loc.tf("Шаг %d из %d", [_step, STEP_COUNT - 1]), &"SectionLabel"))
	_body.add_child(UI.label(step_title, &"TitleLabel", true))
	if not text.is_empty():
		_body.add_child(UI.label(text, &"BodySecondaryLabel", true))
	_body.add_child(UI.spacer(4))


# --- Шаги -------------------------------------------------------------------

func _build_welcome() -> void:
	_body.add_child(UI.spacer(16))
	var badge := UI.icon_badge("clock", 88.0)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(badge)
	_body.add_child(UI.spacer(12))
	var brand := UI.label("TIMEPRICE", &"SectionLabel")
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_color_override("font_color", AppTheme.ACCENT)
	_body.add_child(brand)
	var title := UI.label("Добро пожаловать в TIMEPRICE", &"TitleLabel", true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(title)
	var subtitle := UI.label("Узнай, сколько на самом деле стоят твои покупки", &"BodySecondaryLabel", true)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(subtitle)
	_body.add_child(UI.spacer(8))
	var box := UI.card(_body, &"Card", 14)
	_feature_row(box, "clock", "Стоимость покупок в рабочих часах и днях")
	_feature_row(box, "calculator", "Быстрый расчёт без регистрации")
	_feature_row(box, "shield", "Данные хранятся только на вашем устройстве")
	_body.add_child(UI.spacer(8))
	var slogan := UI.label("Твои деньги. Твоё время. Твой выбор.", &"MutedLabel", true)
	slogan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(slogan)
	var privacy := UI.button("Политика конфиденциальности", &"GhostButton", func() -> void: NavigationManager.push("about"))
	privacy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	privacy.custom_minimum_size.y = 44
	_body.add_child(privacy)


func _feature_row(parent: Control, icon_name: String, text: String) -> void:
	var row := UI.hbox(14)
	parent.add_child(row)
	row.add_child(UI.icon_badge(icon_name, 36.0))
	var l := UI.label(text, &"", true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)


func _build_income() -> void:
	_step_header("Ваш месячный доход",
		"Сумма, которую вы получаете на руки за месяц. Точная зарплата не нужна — подойдёт примерное значение.")
	_income_field = InputField.new(InputField.Mode.AMOUNT, "Доход в месяц", "Например, 400 000", Currency.symbol(_currency))
	_income_field.set_helper("Значение можно изменить в любой момент в настройках.")
	if _income_minor > 0:
		_income_field.set_amount(_income_minor)
	_income_field.submitted.connect(_go_next)
	_body.add_child(_income_field)
	var note := UI.hbox(10)
	note.add_child(IconLibrary.rect("shield", 18.0, AppTheme.TEXT_MUTED))
	note.add_child(UI.label("Данные не покидают устройство: без регистрации, интернета и банковских подключений.", &"MutedLabel", true))
	_body.add_child(note)
	_income_field.focus.call_deferred()


func _validate_income() -> bool:
	if _income_field == null:
		return _income_minor > 0
	var value := _income_field.get_amount()
	if value == InputField.EMPTY:
		_income_field.set_error("Введите сумму дохода")
		return false
	if value == Money.INVALID:
		_income_field.set_error("Введите сумму цифрами, например 400 000")
		return false
	if value == 0:
		_income_field.set_error("Доход должен быть больше нуля")
		return false
	_income_minor = value
	return true


func _build_days() -> void:
	_step_header("Рабочих дней в месяц",
		"При пятидневной рабочей неделе обычно 21–22 дня, при шестидневной — около 26.")
	var box := UI.card(_body, &"Card", 16)
	_days_stepper = Stepper.new(FinancialCalculator.MIN_WORKING_DAYS, FinancialCalculator.MAX_WORKING_DAYS,
		1, _days, func(v: int) -> String: return Fmt.days_count(v))
	_days_stepper.value_changed.connect(func(v: int) -> void:
		_days = v
		_refresh_day_chips())
	box.add_child(_days_stepper)
	var chips := UI.hbox(8)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.name = "DayChips"
	box.add_child(chips)
	for preset in [20, 22, 26]:
		var chip := UI.button(str(preset), &"ChipButton")
		chip.toggle_mode = true
		chip.custom_minimum_size = Vector2(64, 44)
		chip.set_meta("value", preset)
		chip.pressed.connect(func() -> void: _days_stepper.set_value(preset))
		chips.add_child(chip)
	_refresh_day_chips()


func _refresh_day_chips() -> void:
	var chips := _body.find_child("DayChips", true, false)
	if chips == null:
		return
	for chip in chips.get_children():
		(chip as Button).set_pressed_no_signal(int(chip.get_meta("value")) == _days)


func _build_hours() -> void:
	_step_header("Продолжительность рабочего дня",
		"Сколько часов вы обычно работаете в день. Можно указать с шагом в полчаса.")
	var box := UI.card(_body, &"Card", 16)
	_hours_stepper = Stepper.new(FinancialCalculator.MIN_WORK_MINUTES, FinancialCalculator.MAX_WORK_MINUTES,
		30, _minutes, func(v: int) -> String: return Fmt.hours_from_minutes(v))
	_hours_stepper.value_changed.connect(func(v: int) -> void: _minutes = v)
	box.add_child(_hours_stepper)
	var hint := UI.label(Loc.tf("В месяц: %s рабочих часов", [Fmt.decimal(FinancialCalculator.monthly_work_hours(_days, _minutes), 1)]), &"CaptionLabel", true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_hours_stepper.value_changed.connect(func(v: int) -> void:
		hint.text = Loc.tf("В месяц: %s рабочих часов", [Fmt.decimal(FinancialCalculator.monthly_work_hours(_days, v), 1)]))


func _build_currency() -> void:
	_step_header("Валюта", "В этой валюте вы указали доход. По умолчанию — казахстанский тенге.")
	var group := ButtonGroup.new()
	for code in Currency.ORDER:
		var row := UI.button(Currency.long_label(code), &"OptionRowButton")
		row.toggle_mode = true
		row.button_group = group
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.custom_minimum_size.y = 56
		row.button_pressed = code == _currency
		row.icon = IconLibrary.texture("check") if code == _currency else null
		row.toggled.connect(func(on: bool) -> void:
			row.icon = IconLibrary.texture("check") if on else null
			if on:
				_currency = code)
		_body.add_child(row)


func _build_summary() -> void:
	_step_header("Всё готово", "Проверьте данные. Их можно изменить позже в настройках.")
	var rate := FinancialCalculator.hourly_rate(_income_minor, _days, _minutes)
	var hero := UI.card(_body, &"AccentCard", 6)
	hero.add_child(UI.label("Стоимость вашего рабочего часа", &"CaptionLabel"))
	hero.add_child(UI.label(Fmt.money_compact(rate, _currency), &"DisplayLabel"))
	hero.add_child(UI.label(Loc.tf("%s рабочих часов в месяц", [Fmt.decimal(FinancialCalculator.monthly_work_hours(_days, _minutes), 1)]), &"CaptionLabel"))
	var box := UI.card(_body, &"Card", 4)
	_summary_row(box, "Месячный доход", Fmt.money(_income_minor, _currency), Step.INCOME)
	box.add_child(UI.separator())
	_summary_row(box, "Рабочих дней в месяц", str(_days), Step.DAYS)
	box.add_child(UI.separator())
	_summary_row(box, "Часов в рабочем дне", Fmt.hours_from_minutes(_minutes), Step.HOURS)
	box.add_child(UI.separator())
	_summary_row(box, "Валюта", "%s %s" % [Currency.symbol(_currency), _currency], Step.CURRENCY)


func _summary_row(parent: Control, key: String, value: String, target_step: int) -> void:
	var button := Button.new()
	button.theme_type_variation = &"NavButton"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 52
	button.pressed.connect(func() -> void: _show_step(target_step))
	parent.add_child(button)
	var row := UI.kv_row(key, value)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in row.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(IconLibrary.rect("chevron_right", 16.0, AppTheme.TEXT_MUTED))
	button.add_child(row)


func _finish() -> void:
	var p := DataManager.profile.copy()
	p.monthly_income_minor = _income_minor
	p.working_days = _days
	p.work_minutes_per_day = _minutes
	p.currency = _currency
	p.onboarding_completed = true
	if not p.is_valid():
		NavigationManager.show_toast(Loc.t("Проверьте введённые данные"))
		_show_step(Step.INCOME)
		return
	if DataManager.update_profile(p):
		NavigationManager.reset_to("home")
	# При ошибке записи DataManager уже сообщил об этом пользователю.
