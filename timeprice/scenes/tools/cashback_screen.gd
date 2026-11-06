extends BaseScreen
## Калькулятор кэшбэка: реальный возврат с учётом лимита и стоимости карты.

const TOOL := "cashback"
const CATEGORIES := [
	["groceries", "Продукты и супермаркеты"],
	["cafe", "Кафе и рестораны"],
	["transport", "Транспорт и такси"],
	["other", "Остальные покупки"],
]

var _spend: Dictionary = {}
var _rates: Dictionary = {}
var _cap: InputField
var _fee: InputField
var _results: VBoxContainer


func _ready() -> void:
	build_scroll_layout()


func on_enter(_params: Dictionary) -> void:
	var profile := DataManager.profile
	content.add_child(UI.top_bar("Кэшбэк", NavigationManager.go_back))
	if not profile.is_valid():
		add_profile_required_card(content)
		return
	content.add_child(UI.label("Укажите траты в месяц по категориям и процент кэшбэка из условий вашей карты.", &"CaptionLabel", true))
	var code := profile.currency
	var saved := SettingsManager.get_tool_inputs(TOOL)
	for c in CATEGORIES:
		var key: String = c[0]
		var box := UI.card(content, &"Card", 10)
		box.add_child(UI.label(c[1], &"ValueLabel", true))
		var row := UI.hbox(10)
		box.add_child(row)
		var spend := FormKit.amount("Траты в месяц", "0", code)
		spend.size_flags_stretch_ratio = 2.0
		row.add_child(spend)
		var rate := FormKit.rate("Кэшбэк", "0")
		rate.size_flags_stretch_ratio = 1.0
		row.add_child(rate)
		FormKit.restore(spend, saved, key + "_spend")
		FormKit.restore(rate, saved, key + "_rate")
		spend.changed.connect(_recalculate)
		rate.changed.connect(_recalculate)
		_spend[key] = spend
		_rates[key] = rate
	var extra := UI.card(content, &"Card", 14)
	_cap = FormKit.amount("Лимит кэшбэка в месяц (необязательно)", "Без лимита", code)
	extra.add_child(_cap)
	_fee = FormKit.amount("Обслуживание карты в год (необязательно)", "0", code)
	extra.add_child(_fee)
	FormKit.restore(_cap, saved, "cap")
	FormKit.restore(_fee, saved, "fee")
	_cap.changed.connect(_recalculate)
	_fee.changed.connect(_recalculate)
	_results = UI.vbox(16)
	content.add_child(_results)
	_recalculate()


func _exit_tree() -> void:
	save_state()


## Сохраняет последние введённые значения (при уходе с экрана и при сворачивании).
func save_state() -> void:
	if _cap == null:
		return
	var values := {"cap": FormKit.stored_value(_cap), "fee": FormKit.stored_value(_fee)}
	for key in _spend:
		values[key + "_spend"] = FormKit.stored_value(_spend[key])
		values[key + "_rate"] = FormKit.stored_value(_rates[key])
	SettingsManager.set_tool_inputs(TOOL, values)


func _value(field: InputField) -> int:
	var v := field.get_amount()
	return 0 if v == InputField.EMPTY else v


func _recalculate() -> void:
	if _results == null:
		return
	UI.clear_children(_results)
	var profile := DataManager.profile
	var code := profile.currency
	var rows: Array = []
	for key in _spend:
		var s := _value(_spend[key])
		var r := _value(_rates[key])
		if s < 0 or r < 0:
			FormKit.notice(_results, Loc.t("Проверьте поля: суммы и проценты вводятся цифрами."))
			return
		if r > 10_000:
			FormKit.notice(_results, Loc.t("Кэшбэк не может быть больше 100 %."))
			return
		rows.append({"spend_minor": s, "rate_h": r})
	var cap := _value(_cap)
	var fee := _value(_fee)
	if cap < 0 or fee < 0:
		FormKit.notice(_results, Loc.t("Проверьте лимит и стоимость обслуживания."))
		return
	var res := CashbackCalculator.calculate(rows, cap, fee)
	if not res["ok"]:
		FormKit.notice(_results, Loc.t("Укажите траты хотя бы в одной категории."), AppTheme.ACCENT)
		return
	var hero := UI.card(_results, &"AccentCard", 6)
	hero.add_child(UI.label("Чистая выгода за год", &"CaptionLabel"))
	hero.add_child(UI.label(Fmt.money(res["yearly_net"], code), &"DisplayLabel", true))
	var work := FormKit.work_time_text(maxi(int(res["yearly_net"]), 0))
	if not work.is_empty():
		hero.add_child(UI.label(Loc.tf("Это %s", [work.trim_prefix("≈ ")]), &"AccentLabel", true))
	var box := UI.card(_results, &"Card", 10)
	box.add_child(UI.kv_row("Траты в месяц", Fmt.money(res["monthly_spend"], code)))
	box.add_child(UI.kv_row("Кэшбэк в месяц", Fmt.money(res["monthly_cashback"], code)))
	if res["capped"]:
		box.add_child(UI.label(Loc.tf("Без лимита было бы %s — часть кэшбэка «сгорает». Возможно, выгоднее перенести часть трат на другую карту.", [Fmt.money(res["monthly_raw"], code)]), &"ErrorLabel", true))
	box.add_child(UI.kv_row("Кэшбэк за год", Fmt.money(res["yearly_cashback"], code)))
	if fee > 0:
		box.add_child(UI.kv_row("Обслуживание", "−" + Fmt.money(fee, code)))
	box.add_child(UI.kv_row("Реальный возврат", Fmt.percent(maxf(float(res["effective_rate"]), 0.0)) + " " + Loc.t("от трат")))
	if int(res["yearly_net"]) < 0:
		FormKit.notice(_results, Loc.t("Обслуживание карты стоит дороже, чем возвращается кэшбэком. Сравните с картой без платы за обслуживание."), AppTheme.DANGER)
	FormKit.notice(_results, Loc.t("Кэшбэк выгоден только на покупки, которые вы сделали бы и без него. Потратить 100 000 ради 5 000 возврата — это всё равно минус 95 000."), AppTheme.ACCENT, "info")
