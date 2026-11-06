extends BaseScreen
## Кредит: платёж, график, переплата, эффективная ставка, нагрузка на доход.

const TOOL := "loan"

var _amount: InputField
var _rate: InputField
var _term: InputField
var _fee: InputField
var _type: String = LoanCalculator.TYPE_ANNUITY
var _results: VBoxContainer


func _ready() -> void:
	build_scroll_layout()


func on_enter(params: Dictionary) -> void:
	var profile := DataManager.profile
	content.add_child(UI.top_bar("Кредит", NavigationManager.go_back))
	if not profile.is_valid():
		add_profile_required_card(content)
		return
	var code := profile.currency
	var saved := SettingsManager.get_tool_inputs(TOOL)
	if saved.get("type", "") == LoanCalculator.TYPE_DIFFERENTIATED:
		_type = LoanCalculator.TYPE_DIFFERENTIATED
	var form := UI.card(content, &"Card", 14)
	_amount = FormKit.amount("Сумма кредита", "Например, 2 000 000", code)
	form.add_child(_amount)
	_rate = FormKit.rate("Ставка, % годовых", "Например, 21", "Номинальная ставка из договора, без комиссий.")
	form.add_child(_rate)
	_term = FormKit.term(form, "Срок", [6, 12, 24, 36, 60])
	_fee = FormKit.amount("Разовые комиссии (необязательно)", "0", code,
		"Комиссия за выдачу, страховка и другие платежи при оформлении.")
	form.add_child(_fee)
	form.add_child(UI.label("Способ погашения", &"CaptionLabel"))
	form.add_child(FormKit.segmented([
		[LoanCalculator.TYPE_ANNUITY, Loc.t("Равными платежами")],
		[LoanCalculator.TYPE_DIFFERENTIATED, Loc.t("Убывающими")]],
		_type, func(v: String) -> void:
			_type = v
			_recalculate()))
	form.add_child(UI.label("Равные (аннуитетные) платежи одинаковы весь срок. Убывающие (дифференцированные) в начале больше, но переплата меньше.", &"MutedLabel", true))

	for pair in [[_amount, "amount"], [_rate, "rate"], [_term, "term"], [_fee, "fee"]]:
		FormKit.restore(pair[0], saved, pair[1])
	var price: int = int(params.get("price_minor", -1))
	if price > 0:
		_amount.set_amount(price)
	for f in [_amount, _rate, _term, _fee]:
		(f as InputField).changed.connect(_recalculate)
	_results = UI.vbox(16)
	content.add_child(_results)
	_recalculate()


func _exit_tree() -> void:
	save_state()


## Сохраняет последние введённые значения (при уходе с экрана и при сворачивании).
func save_state() -> void:
	if _amount == null:
		return
	SettingsManager.set_tool_inputs(TOOL, {
		"amount": FormKit.stored_value(_amount), "rate": FormKit.stored_value(_rate),
		"term": FormKit.stored_value(_term), "fee": FormKit.stored_value(_fee), "type": _type,
	})


func _recalculate() -> void:
	if _results == null:
		return
	UI.clear_children(_results)
	var code := DataManager.profile.currency
	var amount := _amount.get_amount()
	var rate := _rate.get_amount()
	var term := _term.get_amount()
	var fee := _fee.get_amount()
	if fee == InputField.EMPTY:
		fee = 0
	if amount == Money.INVALID or rate == Money.INVALID or term == Money.INVALID or fee == Money.INVALID:
		FormKit.notice(_results, Loc.t("Проверьте поля: суммы и ставки вводятся цифрами, например 2 000 000 или 21,5."))
		return
	if amount <= 0 or rate == InputField.EMPTY or term <= 0:
		FormKit.notice(_results, Loc.t("Укажите сумму, ставку и срок кредита."), AppTheme.ACCENT)
		return
	var r := LoanCalculator.calculate(amount, rate, term, _type, fee)
	if not r["ok"]:
		var msg := "Не удалось выполнить расчёт."
		match r["error"]:
			LoanCalculator.ERROR_INVALID_FEE:
				msg = "Комиссии не могут быть больше суммы кредита."
			LoanCalculator.ERROR_INVALID_RATE:
				msg = "Ставка должна быть от 0 до 200 %."
			LoanCalculator.ERROR_INVALID_TERM:
				msg = "Срок должен быть от 1 до 600 месяцев."
		FormKit.notice(_results, Loc.t(msg))
		return

	var hero := UI.card(_results, &"AccentCard", 6)
	hero.add_child(UI.label("Ежемесячный платёж", &"CaptionLabel"))
	if _type == LoanCalculator.TYPE_ANNUITY:
		hero.add_child(UI.label(Fmt.money(r["first_payment"], code), &"DisplayLabel", true))
	else:
		hero.add_child(UI.label(Fmt.money(r["first_payment"], code), &"DisplayLabel", true))
		hero.add_child(UI.label(Loc.tf("Первый платёж; последний — %s", [Fmt.money(r["last_payment"], code)]), &"CaptionLabel", true))
	var work := FormKit.work_time_text(r["first_payment"])
	if not work.is_empty():
		hero.add_child(UI.label(work, &"AccentLabel"))

	var box := UI.card(_results, &"Card", 10)
	box.add_child(UI.kv_row("Сумма кредита", Fmt.money(amount, code)))
	box.add_child(UI.kv_row("Проценты за весь срок", Fmt.money(r["total_interest"], code)))
	if fee > 0:
		box.add_child(UI.kv_row("Комиссии", Fmt.money(fee, code)))
	box.add_child(UI.kv_row("Переплата", Fmt.money(r["overpayment"], code)))
	box.add_child(UI.kv_row("Выплаты по графику", Fmt.money(r["total_payments"], code)))
	box.add_child(UI.separator())
	var eff: float = r["effective_rate"]
	if eff >= 0.0:
		box.add_child(UI.kv_row("Эффективная ставка", Fmt.percent(eff) + " " + Loc.t("годовых")))
		box.add_child(UI.label(Loc.tf("Реальная стоимость кредита с учётом ежемесячных начислений%s. Сравнивайте её с ГЭСВ в договоре.", [Loc.t(" и комиссий") if fee > 0 else ""]), &"MutedLabel", true))

	PaymentView.burden_card(_results, r["max_payment"], int(r["total_payments"]) + fee, r["overpayment"])

	var chart_box := UI.card(_results, &"Card", 10)
	chart_box.add_child(UI.label("Остаток долга", &"HeadingLabel"))
	var chart := LineChart.new()
	var series: Array[Dictionary] = [{"values": r["balances"], "color": AppTheme.ACCENT, "width": 2.5}]
	chart.set_data(series, {0: Loc.t("Сейчас"), term: Fmt.months_duration(term)})
	chart_box.add_child(chart)

	ScheduleView.build(_results, r["rows"], code)
	_results.add_child(UI.label("Расчёт приблизительный: банк начисляет проценты по фактическим дням, а ГЭСВ рассчитывается по точным датам платежей. Окончательные условия — в договоре.", &"MutedLabel", true))
