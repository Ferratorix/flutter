extends BaseScreen
## Создание и изменение финансовой цели.

var _goal: FinancialGoal  # null — новая цель
var _title_field: InputField
var _target_field: InputField
var _saved_field: InputField
var _monthly_field: InputField
var _preview: VBoxContainer
var _currency: String = Currency.DEFAULT_CODE


func _ready() -> void:
	build_scroll_layout()


func on_enter(params: Dictionary) -> void:
	var id := str(params.get("id", ""))
	if not id.is_empty():
		var existing := DataManager.find_goal(id)
		if existing != null:
			_goal = existing.copy()
	_currency = _goal.currency if _goal != null else DataManager.profile.currency
	var symbol := Currency.symbol(_currency)

	content.add_child(UI.top_bar("Новая цель" if _goal == null else "Изменить цель", _request_back))
	var form := UI.card(content, &"Card", 16)
	_title_field = InputField.new(InputField.Mode.TEXT, "Название цели", "Например, отпуск")
	_title_field.line_edit.max_length = FinancialGoal.MAX_TITLE_LENGTH
	form.add_child(_title_field)
	_target_field = InputField.new(InputField.Mode.AMOUNT, "Целевая сумма", "Например, 1 500 000", symbol)
	form.add_child(_target_field)
	_saved_field = InputField.new(InputField.Mode.AMOUNT, "Уже накоплено", "0", symbol)
	_saved_field.set_helper("Необязательно. Оставьте пустым, если копите с нуля.")
	form.add_child(_saved_field)
	_monthly_field = InputField.new(InputField.Mode.AMOUNT, "Регулярный взнос в месяц", "Не указан", symbol)
	_monthly_field.set_helper("Необязательно. Нужен для оценки срока достижения цели.")
	form.add_child(_monthly_field)

	if _goal != null:
		_title_field.set_text(_goal.title)
		_target_field.set_amount(_goal.target_minor)
		_saved_field.set_amount(_goal.saved_minor)
		if _goal.monthly_contribution_minor > 0:
			_monthly_field.set_amount(_goal.monthly_contribution_minor)

	for field in [_title_field, _target_field, _saved_field, _monthly_field]:
		(field as InputField).changed.connect(_update_preview)

	_preview = UI.vbox(8)
	content.add_child(_preview)
	content.add_child(UI.button("Сохранить цель" if _goal == null else "Сохранить изменения", &"PrimaryButton", _save))
	_update_preview()
	if _goal == null:
		_title_field.focus.call_deferred()


func handle_back() -> bool:
	_request_back()
	return true


func _request_back() -> void:
	if _is_dirty():
		NavigationManager.confirm("Выйти без сохранения?", "Изменения цели не будут сохранены.", "Выйти",
			func() -> void: NavigationManager.go_back(), true)
	else:
		NavigationManager.go_back()


func _is_dirty() -> bool:
	if _goal == null:
		return not _title_field.get_text().is_empty() or _target_field.get_amount() != InputField.EMPTY \
			or _saved_field.get_amount() != InputField.EMPTY or _monthly_field.get_amount() != InputField.EMPTY
	return _title_field.get_text() != _goal.title or _target_field.get_amount() != _goal.target_minor \
		or _optional(_saved_field) != _goal.saved_minor or _optional(_monthly_field) != _goal.monthly_contribution_minor


## Необязательная сумма: пустое поле = 0.
func _optional(field: InputField) -> int:
	var v := field.get_amount()
	return 0 if v == InputField.EMPTY else v


func _update_preview() -> void:
	UI.clear_children(_preview)
	var target := _target_field.get_amount()
	var saved := _optional(_saved_field)
	var monthly := _optional(_monthly_field)
	if target <= 0 or saved < 0 or monthly < 0:
		return
	var box := UI.card(_preview, &"Card", 8)
	box.add_child(UI.label("Предварительный расчёт", &"CaptionLabel"))
	var remaining := FinancialCalculator.goal_remaining(saved, target)
	box.add_child(UI.kv_row("Выполнено", Fmt.percent(FinancialCalculator.goal_progress(saved, target))))
	box.add_child(UI.kv_row("Осталось", Fmt.money(remaining, _currency)))
	var profile := DataManager.profile
	if remaining > 0 and profile.is_valid() and profile.currency == _currency:
		box.add_child(UI.kv_row("В рабочем времени", Fmt.duration(FinancialCalculator.purchase_minutes(
			remaining, profile.monthly_income_minor, profile.working_days, profile.work_minutes_per_day))))
	var months := FinancialCalculator.months_to_goal(remaining, monthly)
	var eta := ""
	if remaining <= 0:
		eta = Loc.t("Цель уже достигнута")
	elif monthly <= 0:
		eta = Loc.t("Укажите регулярный взнос, чтобы оценить срок")
	elif months < 0:
		eta = Loc.t("При таком взносе срок больше 100 лет")
	else:
		eta = Loc.tf("Примерно %s — к %s", [Fmt.months_duration(months), Fmt.month_year_from_now(months)])
	box.add_child(UI.label(eta, &"AccentLabel", true))


func _save() -> void:
	var ok := true
	var title := _title_field.get_text()
	if title.is_empty():
		_title_field.set_error("Введите название цели")
		ok = false
	var target := _target_field.get_amount()
	if target == InputField.EMPTY:
		_target_field.set_error("Введите целевую сумму")
		ok = false
	elif target <= 0:
		_target_field.set_error("Введите сумму цифрами больше нуля")
		ok = false
	var saved := _optional(_saved_field)
	if saved < 0:
		_saved_field.set_error("Введите сумму цифрами или оставьте поле пустым")
		ok = false
	var monthly := _optional(_monthly_field)
	if monthly < 0:
		_monthly_field.set_error("Введите сумму цифрами или оставьте поле пустым")
		ok = false
	if not ok:
		return

	if _goal == null:
		var goal := FinancialGoal.create(title, target, saved, monthly, _currency)
		if DataManager.add_goal(goal):
			NavigationManager.go_back()
			NavigationManager.show_toast(Loc.t("Цель создана"))
		elif not DataManager.can_add_goal():
			NavigationManager.show_toast(Loc.t("Достигнуто максимальное количество целей"))
		return
	_goal.title = title.substr(0, FinancialGoal.MAX_TITLE_LENGTH)
	_goal.target_minor = target
	_goal.monthly_contribution_minor = monthly
	_goal.set_saved(saved)
	_goal.updated_at = DataUtil.now()
	if DataManager.update_goal(_goal):
		NavigationManager.go_back()
		NavigationManager.show_toast(Loc.t("Изменения сохранены"))
