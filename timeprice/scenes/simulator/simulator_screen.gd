extends BaseScreen
## Моделирование покупки: три сценария, прогноз накоплений, восстановление,
## влияние на финансовую цель. Пересчёт происходит сразу при вводе.

const SCENARIO_TITLES := {0: "Купить сейчас", 3: "Купить через 3 месяца", 6: "Купить через 6 месяцев"}
const BASELINE_COLOR := Color(0.4314, 0.4784, 0.5569)
const SCENARIO_COLORS := {0: Color(0.2039, 0.7765, 0.6588), 3: Color(0.49, 0.64, 0.95), 6: Color(0.898, 0.698, 0.3216)}

var _price_field: InputField
var _savings_field: InputField
var _income_field: InputField
var _expenses_field: InputField
var _monthly_field: InputField
var _goal_option: OptionButton
var _goal_ids: Array[String] = []
var _results: VBoxContainer


func _ready() -> void:
	build_scroll_layout()


func on_enter(params: Dictionary) -> void:
	var profile := DataManager.profile
	content.add_child(UI.top_bar("Моделирование покупки", NavigationManager.go_back))
	if not profile.is_valid():
		add_profile_required_card(content)
		return
	content.add_child(UI.label("Сравните три сценария: купить сейчас, через 3 или через 6 месяцев. Расчёт строится только на введённых вами данных.", &"CaptionLabel", true))
	var symbol := Currency.symbol(profile.currency)

	var form := UI.card(content, &"Card", 14)
	_price_field = InputField.new(InputField.Mode.AMOUNT, "Стоимость покупки", "Например, 350 000", symbol)
	form.add_child(_price_field)
	_savings_field = InputField.new(InputField.Mode.AMOUNT, "Текущие накопления", "Например, 500 000", symbol)
	form.add_child(_savings_field)
	_income_field = InputField.new(InputField.Mode.AMOUNT, "Ежемесячный доход", "", symbol)
	form.add_child(_income_field)
	_expenses_field = InputField.new(InputField.Mode.AMOUNT, "Обязательные расходы в месяц", "Аренда, кредиты, еда, связь", symbol)
	_expenses_field.set_helper("Нужны, чтобы оценить запас средств после покупки.")
	form.add_child(_expenses_field)
	_monthly_field = InputField.new(InputField.Mode.AMOUNT, "Откладываете в месяц", "Например, 60 000", symbol)
	_monthly_field.set_helper("Сумма, которую вы регулярно направляете в накопления.")
	form.add_child(_monthly_field)

	_build_goal_selector(form)

	# Начальные значения: параметр, профиль, последние введённые значения.
	var price: int = int(params.get("price_minor", -1))
	if price > 0:
		_price_field.set_amount(price)
	if profile.has_savings():
		_savings_field.set_amount(profile.savings_minor)
	_income_field.set_amount(profile.monthly_income_minor)
	if SettingsManager.simulator_expenses_minor >= 0:
		_expenses_field.set_amount(SettingsManager.simulator_expenses_minor)
	if SettingsManager.simulator_monthly_savings_minor >= 0:
		_monthly_field.set_amount(SettingsManager.simulator_monthly_savings_minor)

	for field in [_price_field, _savings_field, _income_field, _expenses_field, _monthly_field]:
		(field as InputField).changed.connect(_recalculate)

	_results = UI.vbox(16)
	content.add_child(_results)
	_recalculate()


func _exit_tree() -> void:
	save_state()


## Сохраняет последние введённые значения (при уходе с экрана и при сворачивании).
func save_state() -> void:
	if _expenses_field == null:
		return
	SettingsManager.set_simulator_inputs(_optional_amount(_expenses_field), _optional_amount(_monthly_field))


func _build_goal_selector(form: Control) -> void:
	_goal_ids.clear()
	var goals := DataManager.goals
	if goals.is_empty():
		return
	form.add_child(UI.label("Финансовая цель", &"CaptionLabel"))
	_goal_option = OptionButton.new()
	_goal_option.focus_mode = Control.FOCUS_NONE
	_goal_option.custom_minimum_size.y = AppTheme.TOUCH_TARGET
	_goal_option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_goal_option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_goal_option.add_item(Loc.t("Не учитывать цель"), 0)
	_goal_ids.append("")
	var selected := 0
	for g in goals:
		_goal_option.add_item(g.title, _goal_ids.size())
		if g.is_primary:
			selected = _goal_ids.size()
		_goal_ids.append(g.id)
	_goal_option.select(selected)
	_goal_option.item_selected.connect(func(_i: int) -> void: _recalculate())
	form.add_child(_goal_option)


## Пустое поле — -1 (не указано), ошибка ввода — Money.INVALID.
func _optional_amount(field: InputField) -> int:
	var v := field.get_amount()
	return -1 if v == InputField.EMPTY else v


func _recalculate() -> void:
	if _results == null:
		return
	UI.clear_children(_results)
	var price := _price_field.get_amount()
	var savings := _savings_field.get_amount()
	var income := _income_field.get_amount()
	var expenses := _optional_amount(_expenses_field)
	var monthly := _optional_amount(_monthly_field)

	# Недостаточно данных.
	var missing: Array[String] = []
	if price == InputField.EMPTY:
		missing.append(Loc.t("стоимость покупки"))
	if savings == InputField.EMPTY:
		missing.append(Loc.t("текущие накопления (можно 0)"))
	if income == InputField.EMPTY:
		missing.append(Loc.t("ежемесячный доход"))
	if not missing.is_empty():
		_notice("info", Loc.tf("Для моделирования укажите: %s.", [", ".join(PackedStringArray(missing))]))
		return
	var bad := false
	for pair in [[_price_field, price], [_savings_field, savings], [_income_field, income], [_expenses_field, expenses], [_monthly_field, monthly]]:
		if int(pair[1]) == Money.INVALID:
			(pair[0] as InputField).set_error("Введите сумму цифрами")
			bad = true
	if price == 0:
		_price_field.set_error("Стоимость должна быть больше нуля")
		bad = true
	if income == 0:
		_income_field.set_error("Доход должен быть больше нуля")
		bad = true
	if bad:
		return

	var monthly_value := maxi(monthly, 0)
	var sim := PurchaseSimulator.simulate(price, savings, income, expenses, monthly_value)
	if not sim["ok"]:
		_notice("info", Loc.t("Не удалось выполнить моделирование. Проверьте введённые данные."))
		return
	var profile := DataManager.profile
	_build_warnings(sim["warnings"], sim["free_cash_minor"], profile.currency)
	_build_chart(sim)
	for scenario in sim["scenarios"]:
		_build_scenario(scenario, expenses, profile.currency)
	_build_recovery(sim, price, monthly_value, profile)
	_build_goal_impact(price)
	_results.add_child(UI.label("Это модель на основе введённых данных, а не гарантия будущего результата. Не учитываются проценты по вкладам, инфляция, изменение цены и непредвиденные расходы. Без процентов отложенная покупка не меняет итоговые накопления — меняется запас средств в момент покупки.", &"MutedLabel", true))


func _notice(icon_name: String, text: String, color: Color = AppTheme.ACCENT) -> void:
	var box := UI.card(_results, &"Card", 10)
	var row := UI.hbox(12)
	box.add_child(row)
	row.add_child(UI.icon_badge(icon_name, 36.0, color))
	row.add_child(UI.label(text, &"CaptionLabel", true))


func _build_warnings(warnings: Array, free_cash: int, currency: String) -> void:
	for w in warnings:
		match w:
			PurchaseSimulator.WARNING_NO_REGULAR_SAVINGS:
				_notice("info", Loc.t("Регулярные накопления не указаны: срок восстановления и срок, когда хватит средств, рассчитать нельзя."), AppTheme.WARNING)
			PurchaseSimulator.WARNING_EXPENSES_EXCEED_INCOME:
				_notice("info", Loc.t("Обязательные расходы больше дохода. Проверьте введённые суммы — прогноз может быть неточным."), AppTheme.WARNING)
			PurchaseSimulator.WARNING_SAVINGS_EXCEED_FREE_CASH:
				_notice("info", Loc.tf("Регулярные накопления больше, чем остаётся после обязательных расходов (%s). Прогноз может быть завышен.", [Fmt.money(free_cash, currency)]), AppTheme.WARNING)
			PurchaseSimulator.WARNING_NO_EXPENSES:
				_notice("info", Loc.t("Обязательные расходы не указаны — запас средств после покупки не оценивается."), AppTheme.TEXT_SECONDARY)


func _build_chart(sim: Dictionary) -> void:
	var box := UI.card(_results, &"Card", 12)
	box.add_child(UI.label("Прогноз накоплений на 12 месяцев", &"HeadingLabel", true))
	var series: Array[Dictionary] = [{"values": sim["baseline"], "color": BASELINE_COLOR, "width": 2.0}]
	for scenario in sim["scenarios"]:
		var s := scenario as PurchaseScenario
		series.append({"values": s.projection, "color": SCENARIO_COLORS.get(s.delay_months, AppTheme.ACCENT), "width": 2.5})
	var chart := LineChart.new()
	chart.set_data(series, {0: Loc.t("Сейчас"), 6: Loc.t("6 мес."), 12: Loc.t("12 мес.")})
	box.add_child(chart)
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 14)
	legend.add_theme_constant_override("v_separation", 6)
	box.add_child(legend)
	_legend_item(legend, BASELINE_COLOR, Loc.t("Без покупки"))
	for d in PurchaseSimulator.DELAYS:
		_legend_item(legend, SCENARIO_COLORS[d], Loc.t(SCENARIO_TITLES[d]))


func _legend_item(parent: Control, color: Color, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	row.add_child(UI.label(text, &"MutedLabel"))


func _build_scenario(s: PurchaseScenario, expenses: int, currency: String) -> void:
	var box := UI.card(_results, &"Card", 8)
	var head := UI.hbox(10)
	box.add_child(head)
	var dot := ColorRect.new()
	dot.color = SCENARIO_COLORS.get(s.delay_months, AppTheme.ACCENT)
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(dot)
	var title := UI.label(SCENARIO_TITLES.get(s.delay_months, ""), &"ValueLabel", true)
	head.add_child(title)
	box.add_child(UI.kv_row("Накопления к моменту покупки", Fmt.money(s.savings_before_minor, currency)))
	if s.is_affordable():
		box.add_child(UI.kv_row("Останется после покупки", Fmt.money(s.savings_after_minor, currency)))
		if s.cushion_months >= 0.0 and expenses > 0:
			box.add_child(UI.label(Loc.tf("Остатка хватит примерно на %s мес. обязательных расходов.", [Fmt.decimal(s.cushion_months, 1)]), &"MutedLabel", true))
	else:
		box.add_child(UI.kv_row("Не хватает", Fmt.money(s.shortfall_minor, currency), &"ErrorLabel"))
		if s.months_until_affordable > 0:
			box.add_child(UI.label(Loc.tf("При текущих накоплениях нужная сумма наберётся примерно через %s.", [Fmt.months_duration(s.months_until_affordable)]), &"MutedLabel", true))
		else:
			box.add_child(UI.label("Без регулярных накоплений нужную сумму не набрать.", &"MutedLabel", true))
	box.add_child(UI.kv_row("Через 12 месяцев", Fmt.money(s.savings_at_horizon(), currency)))


func _build_recovery(sim: Dictionary, price: int, monthly: int, profile: UserProfile) -> void:
	var box := UI.card(_results, &"Card", 8)
	box.add_child(UI.label("Восстановление накоплений", &"HeadingLabel"))
	var months: int = sim["recovery_months"]
	if months > 0:
		box.add_child(UI.label(Loc.tf("Чтобы вернуть потраченную сумму, при накоплениях %s в месяц понадобится примерно %s.", [Fmt.money(monthly, profile.currency), Fmt.months_duration(months)]), &"", true))
	else:
		box.add_child(UI.label("Укажите, сколько вы откладываете в месяц, чтобы оценить срок восстановления.", &"CaptionLabel", true))
	var r := profile.calculate(price)
	if r["ok"]:
		box.add_child(UI.label(Loc.tf("В рабочем времени покупка стоит %s (%s).", [Fmt.duration(r["total_minutes"]), Fmt.work_days(r["days"])]), &"MutedLabel", true))


func _build_goal_impact(price: int) -> void:
	if _goal_option == null:
		return
	var id: String = _goal_ids[clampi(_goal_option.selected, 0, _goal_ids.size() - 1)]
	if id.is_empty():
		return
	var goal := DataManager.find_goal(id)
	if goal == null:
		return
	var box := UI.card(_results, &"Card", 8)
	box.add_child(UI.label(Loc.tf("Влияние на цель «%s»", [goal.title]), &"HeadingLabel", true))
	if goal.currency != DataManager.profile.currency:
		box.add_child(UI.label("Валюта цели отличается от валюты дохода — влияние не рассчитать.", &"CaptionLabel", true))
		return
	if goal.is_completed():
		box.add_child(UI.label("Цель уже достигнута.", &"CaptionLabel", true))
		return
	var impact := PurchaseSimulator.goal_impact(goal, price)
	if not impact["ok"]:
		if goal.monthly_contribution_minor <= 0:
			box.add_child(UI.label("Для цели не указан регулярный взнос. Укажите его в настройках цели, чтобы оценить влияние покупки.", &"CaptionLabel", true))
		else:
			box.add_child(UI.label("Срок слишком большой для оценки.", &"CaptionLabel", true))
		return
	var before: int = impact["months_before"]
	var after: int = impact["months_after"]
	var delay: int = impact["delay_months"]
	box.add_child(UI.kv_row("Сейчас до цели", Fmt.months_duration(before)))
	box.add_child(UI.kv_row("Если оплатить из средств цели", Fmt.months_duration(after)))
	if delay > 0:
		box.add_child(UI.label(Loc.tf("Цель сдвинется примерно на %s — к %s.", [Fmt.months_duration(delay), Fmt.month_year_from_now(after)]), &"AccentLabel", true))
	else:
		box.add_child(UI.label("Срок достижения цели почти не изменится.", &"AccentLabel", true))
	box.add_child(UI.label("Оценка предполагает, что покупка оплачивается из денег, которые иначе пошли бы на цель.", &"MutedLabel", true))
