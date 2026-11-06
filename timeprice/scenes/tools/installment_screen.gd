extends BaseScreen
## Рассрочка: платёж, наценка, скрытая переплата относительно оплаты сразу со скидкой.

const TOOL := "installment"

var _price: InputField
var _down: InputField
var _term: InputField
var _commission: InputField
var _discount: InputField
var _results: VBoxContainer


func _ready() -> void:
	build_scroll_layout()


func on_enter(params: Dictionary) -> void:
	var profile := DataManager.profile
	content.add_child(UI.top_bar("Рассрочка", NavigationManager.go_back))
	if not profile.is_valid():
		add_profile_required_card(content)
		return
	var code := profile.currency
	var form := UI.card(content, &"Card", 14)
	_price = FormKit.amount("Цена товара", "Например, 450 000", code)
	form.add_child(_price)
	_down = FormKit.amount("Первоначальный взнос (необязательно)", "0", code)
	form.add_child(_down)
	_term = FormKit.term(form, "Срок", [3, 6, 12, 24])
	_commission = FormKit.rate("Наценка или комиссия, % от цены (необязательно)", "0",
		"Например, если за рассрочку цена выше на 8 %, укажите 8.")
	form.add_child(_commission)
	_discount = FormKit.rate("Скидка при оплате сразу, % (необязательно)", "0",
		"Если при полной оплате магазин даёт скидку, рассрочка на деле не бесплатна.")
	form.add_child(_discount)

	var saved := SettingsManager.get_tool_inputs(TOOL)
	for pair in [[_down, "down"], [_term, "term"], [_commission, "commission"], [_discount, "discount"]]:
		FormKit.restore(pair[0], saved, pair[1])
	var price: int = int(params.get("price_minor", -1))
	if price > 0:
		_price.set_amount(price)
	else:
		FormKit.restore(_price, saved, "price")
	for f in [_price, _down, _term, _commission, _discount]:
		(f as InputField).changed.connect(_recalculate)
	_results = UI.vbox(16)
	content.add_child(_results)
	_recalculate()


func _exit_tree() -> void:
	save_state()


## Сохраняет последние введённые значения (при уходе с экрана и при сворачивании).
func save_state() -> void:
	if _price == null:
		return
	SettingsManager.set_tool_inputs(TOOL, {
		"price": FormKit.stored_value(_price), "down": FormKit.stored_value(_down),
		"term": FormKit.stored_value(_term), "commission": FormKit.stored_value(_commission),
		"discount": FormKit.stored_value(_discount),
	})


func _optional(field: InputField) -> int:
	var v := field.get_amount()
	return 0 if v == InputField.EMPTY else v


func _recalculate() -> void:
	if _results == null:
		return
	UI.clear_children(_results)
	var code := DataManager.profile.currency
	var price := _price.get_amount()
	var term := _term.get_amount()
	var down := _optional(_down)
	var commission := _optional(_commission)
	var discount := _optional(_discount)
	if price == Money.INVALID or term == Money.INVALID or down < 0 or commission < 0 or discount < 0:
		FormKit.notice(_results, Loc.t("Проверьте поля: суммы и проценты вводятся цифрами."))
		return
	if price <= 0 or term <= 0:
		FormKit.notice(_results, Loc.t("Укажите цену товара и срок рассрочки."), AppTheme.ACCENT)
		return
	var r := LoanCalculator.installment(price, down, term, commission, discount)
	if not r["ok"]:
		var msg := "Не удалось выполнить расчёт."
		match r["error"]:
			LoanCalculator.ERROR_INVALID_DOWN_PAYMENT:
				msg = "Первоначальный взнос должен быть меньше цены."
			LoanCalculator.ERROR_INVALID_RATE:
				msg = "Наценка — до 200 %, скидка — меньше 100 %."
			LoanCalculator.ERROR_INVALID_TERM:
				msg = "Срок должен быть от 1 до 600 месяцев."
		FormKit.notice(_results, Loc.t(msg))
		return

	var hero := UI.card(_results, &"AccentCard", 6)
	hero.add_child(UI.label(Loc.tf("Платёж %d раз в месяц", [term]) if term > 1 else Loc.t("Платёж"), &"CaptionLabel"))
	hero.add_child(UI.label(Fmt.money(r["first_payment"], code), &"DisplayLabel", true))
	if int(r["last_payment"]) != int(r["first_payment"]):
		hero.add_child(UI.label(Loc.tf("Последний платёж — %s", [Fmt.money(r["last_payment"], code)]), &"CaptionLabel", true))
	var work := FormKit.work_time_text(r["first_payment"])
	if not work.is_empty():
		hero.add_child(UI.label(work, &"AccentLabel"))

	var box := UI.card(_results, &"Card", 10)
	if down > 0:
		box.add_child(UI.kv_row("Первоначальный взнос", Fmt.money(down, code)))
	if int(r["commission_minor"]) > 0:
		box.add_child(UI.kv_row("Наценка за рассрочку", Fmt.money(r["commission_minor"], code)))
	box.add_child(UI.kv_row("Всего заплатите", Fmt.money(r["total_paid"], code)))
	if discount > 0:
		box.add_child(UI.kv_row("Цена при оплате сразу", Fmt.money(r["cash_price"], code)))
	var over: int = r["overpayment_vs_cash"]
	box.add_child(UI.separator())
	if over <= 0:
		box.add_child(UI.label("Переплаты нет: рассрочка обходится так же, как оплата сразу.", &"AccentLabel", true))
	else:
		box.add_child(UI.kv_row("Переплата", Fmt.money(over, code)))
		var eff: float = r["effective_rate"]
		if eff > 0.0:
			box.add_child(UI.kv_row("Скрытая ставка", Fmt.percent(eff) + " " + Loc.t("годовых")))
			box.add_child(UI.label("Столько стоила бы такая рассрочка, если бы это был кредит. Сравните с условиями кредита или с доходом по депозиту.", &"MutedLabel", true))

	PaymentView.burden_card(_results, r["max_payment"], r["total_paid"], maxi(over, 0))
	ScheduleView.build(_results, r["rows"], code, false)
	_results.add_child(UI.label("Условия рассрочки бывают разными: проверьте в договоре комиссии, страховки и штрафы за просрочку.", &"MutedLabel", true))
