extends BaseScreen
## «Цена привычки»: сколько стоит регулярная трата за год и за годы,
## в рабочем времени и если бы эти деньги откладывались на депозит.

const TOOL := "habit"
const PRESETS := [
	["Кофе навынос", 150_000, 1, "day"],
	["Такси", 250_000, 3, "week"],
	["Доставка еды", 450_000, 2, "week"],
	["Подписки", 500_000, 3, "month"],
]

var _name: InputField
var _cost: InputField
var _times: InputField
var _period: String = HabitCalculator.PERIOD_DAY
var _years: int = 5
var _rate: InputField
var _period_row: Container
var _results: VBoxContainer


func _ready() -> void:
	build_scroll_layout()


func on_enter(_params: Dictionary) -> void:
	var profile := DataManager.profile
	content.add_child(UI.top_bar("Цена привычки", NavigationManager.go_back))
	if not profile.is_valid():
		add_profile_required_card(content)
		return
	content.add_child(UI.label("Мелкие регулярные траты незаметны по отдельности. Посмотрите, сколько они стоят за год — в деньгах и в часах вашей работы.", &"CaptionLabel", true))
	var saved := SettingsManager.get_tool_inputs(TOOL)
	_period = str(saved.get("period", HabitCalculator.PERIOD_DAY))
	if not HabitCalculator.TIMES_PER_YEAR.has(_period):
		_period = HabitCalculator.PERIOD_DAY
	_years = clampi(int(saved.get("years", 5)), 1, HabitCalculator.MAX_YEARS)

	var presets := HFlowContainer.new()
	presets.add_theme_constant_override("h_separation", 8)
	presets.add_theme_constant_override("v_separation", 8)
	content.add_child(presets)
	for p in PRESETS:
		var preset: Array = p
		var chip := UI.button(preset[0], &"ChipButton", func() -> void: _apply_preset(preset))
		chip.custom_minimum_size.y = 36
		presets.add_child(chip)

	var form := UI.card(content, &"Card", 14)
	_name = InputField.new(InputField.Mode.TEXT, "Привычка", "Например, кофе навынос")
	form.add_child(_name)
	_cost = FormKit.amount("Стоимость за раз", "Например, 1 500", profile.currency)
	form.add_child(_cost)
	_times = InputField.new(InputField.Mode.AMOUNT, "Сколько раз", "1", Loc.t("раз"))
	_times.fraction_digits = 0
	_times.max_value = HabitCalculator.MAX_TIMES
	form.add_child(_times)
	_period_row = UI.vbox(0)
	form.add_child(_period_row)
	_build_period()
	form.add_child(UI.label("Горизонт", &"CaptionLabel"))
	form.add_child(FormKit.segmented([["1", Loc.t("1 год")], ["5", Loc.t("5 лет")], ["10", Loc.t("10 лет")]],
		str(_years) if [1, 5, 10].has(_years) else "5", func(v: String) -> void:
			_years = v.to_int()
			_recalculate()))
	_rate = FormKit.rate("Ставка депозита, % (необязательно)", "Например, 14",
		"Чтобы посчитать, сколько накопилось бы, если откладывать эти деньги под проценты.")
	form.add_child(_rate)

	if saved.has("name"):
		_name.set_text(str(saved["name"]))
	FormKit.restore(_cost, saved, "cost")
	FormKit.restore(_times, saved, "times")
	var dep_rate: Variant = SettingsManager.get_tool_inputs("deposit").get("rate", -1)
	if typeof(saved.get("rate", -1)) == TYPE_INT and int(saved.get("rate", -1)) >= 0:
		FormKit.restore(_rate, saved, "rate")
	elif typeof(dep_rate) == TYPE_INT and int(dep_rate) > 0:
		_rate.set_amount(dep_rate)
	for f in [_cost, _times, _rate]:
		(f as InputField).changed.connect(_recalculate)
	_results = UI.vbox(16)
	content.add_child(_results)
	_recalculate()


func _build_period() -> void:
	UI.clear_children(_period_row)
	_period_row.add_child(FormKit.segmented([["day", Loc.t("в день")], ["week", Loc.t("в неделю")], ["month", Loc.t("в месяц")]],
		_period, func(v: String) -> void:
			_period = v
			_recalculate()))


func _apply_preset(preset: Array) -> void:
	_name.set_text(Loc.t(preset[0]))
	_cost.set_amount(preset[1])
	_times.set_amount(preset[2])
	_period = preset[3]
	_build_period()
	_recalculate()


func _exit_tree() -> void:
	if _cost == null:
		return
	SettingsManager.set_tool_inputs(TOOL, {
		"name": _name.get_text(), "cost": FormKit.stored_value(_cost), "times": FormKit.stored_value(_times),
		"rate": FormKit.stored_value(_rate), "period": _period, "years": _years,
	})


func _recalculate() -> void:
	if _results == null:
		return
	UI.clear_children(_results)
	var profile := DataManager.profile
	var code := profile.currency
	var cost := _cost.get_amount()
	var times := _times.get_amount()
	if times == InputField.EMPTY:
		times = 1
	var rate := _rate.get_amount()
	if rate == InputField.EMPTY:
		rate = 0
	if cost == Money.INVALID or times == Money.INVALID or rate == Money.INVALID:
		FormKit.notice(_results, Loc.t("Проверьте поля: суммы вводятся цифрами."))
		return
	if cost <= 0:
		FormKit.notice(_results, Loc.t("Выберите пример выше или укажите стоимость привычки."), AppTheme.ACCENT)
		return
	var r := HabitCalculator.calculate(cost, times, _period, _years, rate)
	if not r["ok"]:
		FormKit.notice(_results, Loc.t("Не удалось выполнить расчёт: проверьте количество (до 50 раз) и ставку."))
		return
	var habit := _name.get_text() if not _name.get_text().is_empty() else Loc.t("Эта привычка")
	var hero := UI.card(_results, &"AccentCard", 6)
	hero.add_child(UI.label(Loc.tf("%s стоит в год", [habit]), &"CaptionLabel", true))
	hero.add_child(UI.label(Fmt.money(r["yearly_minor"], code), &"DisplayLabel", true))
	var y := profile.calculate(r["yearly_minor"])
	if y["ok"]:
		hero.add_child(UI.label(Loc.tf("%s работы — %s", [Fmt.duration(y["total_minutes"]), Fmt.work_days(y["days"])]), &"AccentLabel", true))

	var box := UI.card(_results, &"Card", 10)
	box.add_child(UI.kv_row("В среднем в месяц", Fmt.money(r["monthly_minor"], code)))
	box.add_child(UI.kv_row(Loc.tf("За %s", [Fmt.months_duration(_years * 12)]), Fmt.money(r["total_minor"], code)))
	if rate > 0:
		box.add_child(UI.separator())
		box.add_child(UI.kv_row("Если откладывать на депозит", Fmt.money(r["invested_minor"], code)))
		box.add_child(UI.label(Loc.tf("Из них %s — проценты при ставке %s.", [Fmt.money(r["interest_minor"], code), FormKit.rate_text(rate)]), &"MutedLabel", true))
	box.add_child(UI.separator())
	var half := Money.round_div(int(r["yearly_minor"]), 2)
	var h := profile.calculate(half)
	box.add_child(UI.label(Loc.tf("Если сократить привычку вдвое, за год останется %s%s.", [Fmt.money(half, code),
		(" — " + Fmt.duration(h["total_minutes"]) + " " + Loc.t("работы")) if h["ok"] else ""]), &"", true))

	var goal := DataManager.get_primary_goal()
	if goal != null and goal.currency == code and not goal.is_completed() and int(r["monthly_minor"]) > 0:
		var months := FinancialCalculator.months_to_goal(goal.remaining_minor(), goal.monthly_contribution_minor + int(r["monthly_minor"]))
		var base := goal.months_left()
		if months > 0 and base > months:
			var g := UI.card(_results, &"Card", 6)
			g.add_child(UI.label(Loc.tf("Цель «%s»", [goal.title]), &"HeadingLabel", true))
			g.add_child(UI.label(Loc.tf("Если направлять эти деньги на цель, она станет ближе на %s.", [Fmt.months_duration(base - months)]), &"AccentLabel", true))
	_results.add_child(UI.label("Это не призыв отказаться от удовольствий — просто цена в понятных единицах. Решать вам.", &"MutedLabel", true))
