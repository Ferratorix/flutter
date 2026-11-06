extends BaseScreen
## Калькулятор покупки: название, стоимость, валюта -> часы, дни, доля дохода, накопления.
## Результат пересчитывается сразу при вводе.

var _title_field: InputField
var _price_field: InputField
var _currency_option: OptionButton
var _rate_box: VBoxContainer
var _rate_field: InputField
var _result_box: VBoxContainer
var _save_button: Button
var _wish_button: Button
var _simulate_button: Button
var _finance_row: HBoxContainer

var _currency: String = Currency.DEFAULT_CODE
var _base_price: int = -1
var _rate: int = 0
var _saved := false
var _wished := false


func _ready() -> void:
	build_scroll_layout()


func on_enter(params: Dictionary) -> void:
	var profile := DataManager.profile
	content.add_child(UI.top_bar("Калькулятор покупки"))
	if not profile.is_valid():
		add_profile_required_card(content)
		return
	_currency = profile.currency
	content.add_child(UI.label(Loc.tf("Стоимость вашего часа — %s", [Fmt.money_compact(profile.hourly_rate(), profile.currency)]), &"CaptionLabel", true))

	var form := UI.card(content, &"Card", 14)
	_title_field = InputField.new(InputField.Mode.TEXT, "Название покупки", "Например, смартфон")
	_title_field.changed.connect(_mark_unsaved)
	form.add_child(_title_field)

	var price_row := UI.hbox(10)
	form.add_child(price_row)
	_price_field = InputField.new(InputField.Mode.AMOUNT, "Стоимость", "0", "")
	_price_field.changed.connect(_recalculate)
	_price_field.submitted.connect(_recalculate)
	price_row.add_child(_price_field)

	var currency_col := UI.vbox(6)
	currency_col.size_flags_horizontal = Control.SIZE_SHRINK_END
	price_row.add_child(currency_col)
	currency_col.add_child(UI.label("Валюта", &"CaptionLabel"))
	_currency_option = OptionButton.new()
	_currency_option.custom_minimum_size = Vector2(108, AppTheme.TOUCH_TARGET)
	_currency_option.focus_mode = Control.FOCUS_NONE
	for i in Currency.ORDER.size():
		var code: String = Currency.ORDER[i]
		_currency_option.add_item("%s %s" % [Currency.symbol(code), code], i)
		if code == _currency:
			_currency_option.select(i)
	_currency_option.item_selected.connect(_on_currency_selected)
	currency_col.add_child(_currency_option)

	_rate_box = UI.vbox(6)
	form.add_child(_rate_box)
	_rate_field = InputField.new(InputField.Mode.AMOUNT, "", "Например, 500", Currency.symbol(profile.currency))
	_rate_field.fraction_digits = FinancialCalculator.RATE_DIGITS
	_rate_field.max_value = FinancialCalculator.MAX_RATE
	_rate_field.set_helper("Курс указывается вручную: приложение работает без интернета.")
	_rate_field.changed.connect(_recalculate)
	_rate_field.submitted.connect(_recalculate)
	_rate_box.add_child(_rate_field)
	_rate_box.visible = false

	_result_box = UI.vbox(16)
	content.add_child(_result_box)

	var actions := UI.vbox(10)
	content.add_child(actions)
	_save_button = UI.button("Сохранить в историю", &"PrimaryButton", _save)
	actions.add_child(_save_button)
	_wish_button = UI.button("Добавить в список желаний", &"SecondaryButton", _add_to_wishlist)
	_wish_button.icon = IconLibrary.texture("heart")
	actions.add_child(_wish_button)
	_simulate_button = UI.button("Смоделировать покупку", &"SecondaryButton",
		func() -> void: NavigationManager.push("simulator", {"price_minor": _base_price}))
	actions.add_child(_simulate_button)
	_finance_row = UI.hbox(10)
	actions.add_child(_finance_row)
	for item in [["В кредит", "loan"], ["В рассрочку", "installment"]]:
		var route: String = item[1]
		var b := UI.button(item[0], &"SecondaryButton", func() -> void: NavigationManager.push(route, {"price_minor": _base_price}))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_finance_row.add_child(b)
	actions.add_child(UI.button("Новый расчёт", &"SecondaryButton", _reset))

	var price: int = int(params.get("price_minor", -1))
	if price > 0:
		_price_field.set_amount(price)
	_recalculate()


## Профиль (например, накопления) мог измениться на экране настроек.
func on_resume() -> void:
	if _price_field != null:
		var saved := _saved
		var wished := _wished
		_recalculate()
		# Пересчёт не делает уже сохранённый расчёт «несохранённым».
		if saved and _base_price > 0:
			_saved = true
			_save_button.text = "Сохранено"
			_save_button.disabled = true
		if wished and _base_price > 0:
			_wished = true
			_wish_button.text = "В списке желаний"
			_wish_button.disabled = true


func _on_currency_selected(index: int) -> void:
	_currency = Currency.ORDER[clampi(index, 0, Currency.ORDER.size() - 1)]
	var profile := DataManager.profile
	var foreign := _currency != profile.currency
	_rate_box.visible = foreign
	if foreign:
		_rate_field.set_title(Loc.tf("Курс: 1 %s в %s", [_currency, profile.currency]))
		var stored := SettingsManager.get_rate(_currency, profile.currency)
		_rate_field.set_amount(stored if stored > 0 else -1)
	_recalculate()


func _recalculate() -> void:
	_mark_unsaved()
	UI.clear_children(_result_box)
	_base_price = -1
	_rate = 0
	var profile := DataManager.profile
	_price_field.set_suffix(Currency.symbol(_currency))
	var price := _price_field.get_amount()
	if price == InputField.EMPTY:
		_show_hint("Введите стоимость покупки, чтобы увидеть, сколько рабочего времени она занимает.")
		return
	if price == Money.INVALID:
		_price_field.set_error("Введите сумму цифрами, например 350 000")
		_show_hint("")
		return
	if price == 0:
		_price_field.set_error("Стоимость должна быть больше нуля")
		_show_hint("")
		return
	var base_price := price
	var note := ""
	if _currency != profile.currency:
		var rate := _rate_field.get_amount()
		if rate == InputField.EMPTY:
			_show_hint(Loc.tf("Укажите курс %s, чтобы пересчитать сумму в валюту дохода.", [_currency]))
			return
		if rate == Money.INVALID or rate == 0:
			_rate_field.set_error("Введите курс числом больше нуля, например 512,5")
			_show_hint("")
			return
		base_price = FinancialCalculator.convert_amount(price, rate)
		if base_price <= 0:
			_price_field.set_error("Слишком большая сумма для расчёта")
			_show_hint("")
			return
		_rate = rate
		note = Loc.tf("В пересчёте: %s по курсу %s", [Fmt.money(base_price, profile.currency),
			Fmt.decimal(rate / float(Money.pow10(FinancialCalculator.RATE_DIGITS)), FinancialCalculator.RATE_DIGITS)])
	var r := profile.calculate(base_price)
	if not r["ok"]:
		_show_hint("Не удалось выполнить расчёт. Проверьте данные профиля в настройках.")
		return
	_base_price = base_price
	PurchaseResultView.build(_result_box, r, profile, note)
	_result_box.add_child(UI.label("Расчёт — информация для решения, а не оценка вашей покупки.", &"MutedLabel", true))
	_save_button.disabled = false
	_wish_button.disabled = _wished
	_simulate_button.disabled = false
	_set_finance_enabled(true)


func _show_hint(text: String) -> void:
	_save_button.disabled = true
	_wish_button.disabled = true
	_simulate_button.disabled = true
	_set_finance_enabled(false)
	if text.is_empty():
		return
	var box := UI.card(_result_box, &"Card", 10)
	var row := UI.hbox(12)
	box.add_child(row)
	row.add_child(UI.icon_badge("info", 36.0))
	row.add_child(UI.label(text, &"CaptionLabel", true))


func _set_finance_enabled(enabled: bool) -> void:
	if _finance_row == null:
		return
	for b in _finance_row.get_children():
		(b as Button).disabled = not enabled


func _mark_unsaved() -> void:
	if _wished and _wish_button != null:
		_wished = false
		_wish_button.text = "Добавить в список желаний"
		_wish_button.disabled = _base_price <= 0
	if _saved and _save_button != null:
		_saved = false
		_save_button.text = "Сохранить в историю"
		_save_button.disabled = _base_price <= 0


func _save() -> void:
	if _base_price <= 0 or _saved:
		return
	var profile := DataManager.profile
	var price := _price_field.get_amount()
	var item := Purchase.create(_title_field.get_text(), price, _currency, _rate, _base_price, profile)
	if _rate > 0:
		SettingsManager.set_rate(_currency, profile.currency, _rate)
	if DataManager.add_purchase(item):
		_saved = true
		_save_button.text = "Сохранено"
		_save_button.disabled = true
		NavigationManager.show_toast(Loc.t("Расчёт сохранён в историю"))


func _add_to_wishlist() -> void:
	if _base_price <= 0 or _wished:
		return
	var profile := DataManager.profile
	var title := _title_field.get_text()
	if title.is_empty():
		title = Loc.t("Покупка без названия")
	var item := WishlistItem.create(title, _base_price, profile.currency)
	if _currency != profile.currency:
		item.original_price_minor = _price_field.get_amount()
		item.original_currency = _currency
		SettingsManager.set_rate(_currency, profile.currency, _rate)
	if DataManager.add_wishlist_item(item):
		_wished = true
		_wish_button.text = "В списке желаний"
		_wish_button.disabled = true
		NavigationManager.show_toast(Loc.t("Добавлено в список желаний"))
	elif not DataManager.can_add_wishlist_item():
		NavigationManager.show_toast(Loc.t("Список желаний заполнен"))


func _reset() -> void:
	_title_field.set_text("")
	_title_field.clear_error()
	_price_field.set_text("")
	_price_field.clear_error()
	_saved = false
	_wished = false
	_save_button.text = "Сохранить в историю"
	_wish_button.text = "Добавить в список желаний"
	_recalculate()
