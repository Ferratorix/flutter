extends BaseScreen
## Депозит: доход по вкладу, проценты в рабочем времени, срок до цели, инфляция.

const TOOL := "deposit"

var _initial: InputField
var _monthly: InputField
var _rate: InputField
var _term: InputField
var _target: InputField
var _inflation: InputField
var _capitalization: String = DepositCalculator.CAPITALIZATION_MONTHLY
var _results: VBoxContainer


func _ready() -> void:
	build_scroll_layout()


func on_enter(_params: Dictionary) -> void:
	var profile := DataManager.profile
	content.add_child(UI.top_bar("Депозит", NavigationManager.go_back))
	if not profile.is_valid():
		add_profile_required_card(content)
		return
	var code := profile.currency
	var saved := SettingsManager.get_tool_inputs(TOOL)
	if saved.get("capitalization", "") == DepositCalculator.CAPITALIZATION_END:
		_capitalization = DepositCalculator.CAPITALIZATION_END
	var form := UI.card(content, &"Card", 14)
	_initial = FormKit.amount("Начальная сумма", "Например, 500 000", code)
	form.add_child(_initial)
	_monthly = FormKit.amount("Пополнение каждый месяц", "Необязательно", code,
		"Вносится в начале каждого месяца.")
	form.add_child(_monthly)
	_rate = FormKit.rate("Ставка, % годовых", "Например, 14,5", "Номинальная ставка из условий банка.")
	form.add_child(_rate)
	_term = FormKit.term(form, "Срок", [3, 6, 12, 24, 36])
	form.add_child(UI.label("Капитализация процентов", &"CaptionLabel"))
	form.add_child(FormKit.segmented([
		[DepositCalculator.CAPITALIZATION_MONTHLY, Loc.t("Ежемесячно")],
		[DepositCalculator.CAPITALIZATION_END, Loc.t("В конце срока")]],
		_capitalization, func(v: String) -> void:
			_capitalization = v
			_recalculate()))
	_target = FormKit.amount("Хочу накопить (необязательно)", "Например, 1 500 000", code,
		"Покажем, через сколько месяцев на депозите накопится эта сумма.")
	form.add_child(_target)
	_inflation = FormKit.rate("Ожидаемая инфляция, % (необязательно)", "Например, 8",
		"Чтобы оценить, сколько будет стоить итоговая сумма в сегодняшних деньгах.")
	form.add_child(_inflation)

	for pair in [[_initial, "initial"], [_monthly, "monthly"], [_rate, "rate"], [_term, "term"], [_inflation, "inflation"]]:
		FormKit.restore(pair[0], saved, pair[1])
	var goal := DataManager.get_primary_goal()
	if goal != null and goal.currency == code and not goal.is_completed():
		_target.set_amount(goal.target_minor)
		_target.set_helper(Loc.tf("Подставлена сумма цели «%s».", [goal.title]))

	for f in [_initial, _monthly, _rate, _term, _target, _inflation]:
		(f as InputField).changed.connect(_recalculate)
	_results = UI.vbox(16)
	content.add_child(_results)
	_recalculate()


func _exit_tree() -> void:
	save_state()


## Сохраняет последние введённые значения (при уходе с экрана и при сворачивании).
func save_state() -> void:
	if _initial == null:
		return
	SettingsManager.set_tool_inputs(TOOL, {
		"initial": FormKit.stored_value(_initial), "monthly": FormKit.stored_value(_monthly),
		"rate": FormKit.stored_value(_rate), "term": FormKit.stored_value(_term),
		"inflation": FormKit.stored_value(_inflation), "capitalization": _capitalization,
	})


func _recalculate() -> void:
	if _results == null:
		return
	UI.clear_children(_results)
	var code := DataManager.profile.currency
	var initial := _optional(_initial)
	var monthly := _optional(_monthly)
	var rate := _rate.get_amount()
	var term := _term.get_amount()
	var target := _optional(_target)
	var inflation := _optional(_inflation)
	if initial < 0 or monthly < 0 or target < 0 or inflation < 0 or rate == Money.INVALID or term == Money.INVALID:
		FormKit.notice(_results, Loc.t("Проверьте поля: суммы и ставки вводятся цифрами, например 500 000 или 14,5."))
		return
	if initial == 0 and monthly == 0 or rate == InputField.EMPTY or term == InputField.EMPTY or term == 0:
		FormKit.notice(_results, Loc.t("Укажите начальную сумму или пополнение, ставку и срок."), AppTheme.ACCENT)
		return
	var r := DepositCalculator.calculate(initial, monthly, rate, term, _capitalization)
	if not r["ok"]:
		FormKit.notice(_results, Loc.t("Не удалось выполнить расчёт: проверьте ставку (до 200 %) и срок (до 600 месяцев)."))
		return

	var hero := UI.card(_results, &"AccentCard", 6)
	hero.add_child(UI.label(Loc.tf("Через %s на счёте", [Fmt.months_duration(term)]), &"CaptionLabel"))
	hero.add_child(UI.label(Fmt.money(r["final_minor"], code), &"DisplayLabel", true))
	hero.add_child(UI.label(Loc.tf("Доход по процентам: %s", [Fmt.money(r["interest_minor"], code)]), &"AccentLabel", true))
	var work := FormKit.work_time_text(r["interest_minor"])
	if not work.is_empty():
		hero.add_child(UI.label(Loc.tf("Проценты заменят %s", [work.trim_prefix("≈ ")]), &"CaptionLabel", true))

	var box := UI.card(_results, &"Card", 10)
	box.add_child(UI.kv_row("Внесено всего", Fmt.money(r["contributed_minor"], code)))
	box.add_child(UI.kv_row("Начислено процентов", Fmt.money(r["interest_minor"], code)))
	box.add_child(UI.kv_row("Эффективная доходность", FormKit.rate_text(roundi(float(r["effective_rate"]) * 100.0)) + " " + Loc.t("годовых")))
	if inflation > 0:
		var real := DepositCalculator.real_value(r["final_minor"], inflation, term)
		box.add_child(UI.separator())
		box.add_child(UI.kv_row("В сегодняшних деньгах", Fmt.money(real, code)))
		var real_gain := real - int(r["contributed_minor"])
		var text := Loc.tf("С учётом инфляции %s реальный доход составит %s.", [FormKit.rate_text(inflation), Fmt.money(real_gain, code)]) if real_gain >= 0 \
			else Loc.tf("При инфляции %s проценты её не покрывают: покупательная способность снизится на %s.", [FormKit.rate_text(inflation), Fmt.money(-real_gain, code)])
		box.add_child(UI.label(text, &"MutedLabel", true))

	var chart_box := UI.card(_results, &"Card", 10)
	chart_box.add_child(UI.label("Рост вклада", &"HeadingLabel"))
	var chart := LineChart.new()
	var labels := {0: Loc.t("Сейчас"), term: Fmt.months_duration(term)}
	if term >= 4:
		labels[term / 2] = Fmt.months_duration(term / 2)
	var series: Array[Dictionary] = [
		{"values": r["contributions"], "color": AppTheme.TEXT_MUTED, "width": 2.0},
		{"values": r["balances"], "color": AppTheme.ACCENT, "width": 2.5}]
	chart.set_data(series, labels)
	chart_box.add_child(chart)
	var legend := UI.hbox(14)
	chart_box.add_child(legend)
	_legend(legend, AppTheme.TEXT_MUTED, Loc.t("Внесено"))
	_legend(legend, AppTheme.ACCENT, Loc.t("С процентами"))

	if target > 0:
		var tbox := UI.card(_results, &"Card", 8)
		tbox.add_child(UI.label(Loc.tf("Накопить %s", [Fmt.money(target, code)]), &"HeadingLabel", true))
		var with_rate := DepositCalculator.months_to_target(initial, monthly, rate, target)
		var without := DepositCalculator.months_to_target(initial, monthly, 0, target)
		if with_rate == 0:
			tbox.add_child(UI.label("Эта сумма уже есть.", &"CaptionLabel", true))
		elif with_rate < 0:
			tbox.add_child(UI.label("При этих условиях сумма не накопится за 50 лет. Добавьте ежемесячное пополнение.", &"CaptionLabel", true))
		else:
			tbox.add_child(UI.kv_row("На депозите", Fmt.months_duration(with_rate)))
			tbox.add_child(UI.kv_row("Без процентов", Fmt.months_duration(without) if without > 0 else Loc.t("не накопится")))
			if without > with_rate:
				tbox.add_child(UI.label(Loc.tf("Проценты сократят путь на %s — к %s.", [Fmt.months_duration(without - with_rate), Fmt.month_year_from_now(with_rate)]), &"AccentLabel", true))

	_results.add_child(UI.label("Расчёт приблизительный: банки начисляют проценты по дням и могут менять ставку. Налоги и условия досрочного снятия не учитываются.", &"MutedLabel", true))


func _legend(parent: Control, color: Color, text: String) -> void:
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(dot)
	parent.add_child(UI.label(text, &"MutedLabel"))


## Пустое поле = 0; ошибка ввода = -1.
func _optional(field: InputField) -> int:
	var v := field.get_amount()
	return 0 if v == InputField.EMPTY else v
