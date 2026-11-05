extends BaseScreen
## Детали цели: прогресс, прогноз, пополнение, журнал, изменение и удаление.

const LOG_LIMIT := 15

var _goal_id: String = ""
var _amount_field: InputField


func _ready() -> void:
	build_scroll_layout()


func on_enter(params: Dictionary) -> void:
	_goal_id = str(params.get("id", ""))
	_build()
	DataManager.goals_changed.connect(_build)


func _build() -> void:
	UI.clear_children(content)
	_amount_field = null
	var goal := DataManager.find_goal(_goal_id)
	if goal == null:
		content.add_child(UI.top_bar("Цель", NavigationManager.go_back))
		UI.empty_state(content, "target", "Цель не найдена", "Возможно, она была удалена.")
		return
	var profile := DataManager.profile
	content.add_child(UI.top_bar(goal.title, NavigationManager.go_back))

	# Прогресс.
	var hero := UI.card(content, &"AccentCard", 6)
	hero.add_child(UI.label("Накоплено", &"CaptionLabel"))
	hero.add_child(UI.label(Fmt.money(goal.saved_minor, goal.currency), &"DisplayLabel", true))
	hero.add_child(UI.label(Loc.tf("из %s · %s", [Fmt.money(goal.target_minor, goal.currency), Fmt.percent(goal.progress_percent())]), &"CaptionLabel", true))
	hero.add_child(UI.progress_bar(goal.progress_percent(), 100.0, 10.0))

	# Показатели.
	var stats := UI.card(content, &"Card", 10)
	stats.add_child(UI.kv_row("Осталось накопить", Fmt.money(goal.remaining_minor(), goal.currency)))
	var minutes := goal.remaining_work_minutes(profile)
	if minutes > 0:
		stats.add_child(UI.kv_row("В рабочем времени", Fmt.duration(minutes)))
		var days := FinancialCalculator.purchase_days(goal.remaining_minor(), profile.monthly_income_minor, profile.working_days)
		stats.add_child(UI.label(Loc.tf("Это %s по вашему графику.", [Fmt.work_days(days)]), &"MutedLabel", true))
	elif minutes < 0 and not goal.is_completed():
		stats.add_child(UI.label("Рабочее время не рассчитать: валюта цели отличается от валюты дохода.", &"MutedLabel", true))
	stats.add_child(UI.separator())
	var monthly := "не указан" if goal.monthly_contribution_minor <= 0 else Fmt.money(goal.monthly_contribution_minor, goal.currency)
	stats.add_child(UI.kv_row("Регулярный взнос в месяц", monthly))
	stats.add_child(UI.label(GoalView.eta_text(goal), &"AccentLabel", true))
	if not goal.is_completed() and goal.monthly_contribution_minor > 0:
		stats.add_child(UI.label("Прогноз приблизительный: он предполагает одинаковый взнос каждый месяц и не гарантирует результат.", &"MutedLabel", true))

	# Пополнение.
	if not goal.is_completed():
		var deposit := UI.card(content, &"Card", 12)
		deposit.add_child(UI.label("Пополнить", &"HeadingLabel"))
		_amount_field = InputField.new(InputField.Mode.AMOUNT, "", "Сумма пополнения", Currency.symbol(goal.currency))
		_amount_field.submitted.connect(_deposit)
		deposit.add_child(_amount_field)
		var row := UI.hbox(10)
		deposit.add_child(row)
		if goal.monthly_contribution_minor > 0:
			var regular := UI.button(Loc.tf("+ %s", [Fmt.money(goal.monthly_contribution_minor, goal.currency)]), &"SecondaryButton",
				func() -> void: _apply_deposit(goal.monthly_contribution_minor))
			regular.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(regular)
		var add := UI.button("Внести", &"PrimaryButton", _deposit)
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(add)

	# Действия.
	var actions := UI.vbox(10)
	content.add_child(actions)
	if not goal.is_primary:
		actions.add_child(UI.button("Сделать основной целью", &"SecondaryButton",
			func() -> void: DataManager.set_primary_goal(_goal_id)))
	actions.add_child(UI.button("Изменить цель", &"SecondaryButton",
		func() -> void: NavigationManager.push("goal_edit", {"id": _goal_id})))
	actions.add_child(UI.button("Удалить цель", &"DangerButton", _confirm_delete))

	_build_log(goal)


func _build_log(goal: FinancialGoal) -> void:
	if goal.entries.is_empty():
		return
	content.add_child(UI.label("ИСТОРИЯ ИЗМЕНЕНИЙ", &"SectionLabel"))
	var box := UI.card(content, &"Card", 8)
	var shown := 0
	for i in range(goal.entries.size() - 1, -1, -1):
		if shown >= LOG_LIMIT:
			break
		var e: Dictionary = goal.entries[i]
		if shown > 0:
			box.add_child(UI.separator())
		shown += 1
		var row := UI.hbox(8)
		box.add_child(row)
		var left := UI.vbox(2)
		row.add_child(left)
		var delta: int = e["delta_minor"]
		var kind: String = e["kind"]
		var title := "Пополнение"
		if kind == FinancialGoal.KIND_INITIAL:
			title = "Цель создана"
		elif kind == FinancialGoal.KIND_EDIT:
			title = "Сумма изменена"
		left.add_child(UI.label(title, &""))
		left.add_child(UI.label(Fmt.date_time(int(e["at"])), &"MutedLabel"))
		var sign_text := "+" if delta >= 0 else "−"
		var value := UI.label(sign_text + Fmt.money(absi(delta), goal.currency), &"AccentLabel" if delta >= 0 else &"BodySecondaryLabel")
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(value)


func _deposit() -> void:
	if _amount_field == null:
		return
	var amount := _amount_field.get_amount()
	if amount == InputField.EMPTY:
		_amount_field.set_error("Введите сумму пополнения")
		return
	if amount == Money.INVALID or amount == 0:
		_amount_field.set_error("Введите сумму цифрами больше нуля")
		return
	_apply_deposit(amount)


func _apply_deposit(amount: int) -> void:
	var goal := DataManager.find_goal(_goal_id)
	if goal == null:
		return
	var updated := goal.copy()
	if not updated.add_contribution(amount):
		return
	var was_completed := goal.is_completed()
	if DataManager.update_goal(updated):
		if updated.is_completed() and not was_completed:
			NavigationManager.show_toast(Loc.t("Цель достигнута!"))
		else:
			NavigationManager.show_toast(Loc.tf("Внесено %s", [Fmt.money(amount, updated.currency)]))


func _confirm_delete() -> void:
	var goal := DataManager.find_goal(_goal_id)
	if goal == null:
		return
	NavigationManager.confirm("Удалить цель?",
		Loc.tf("Цель «%s» и история её пополнений будут удалены.", [goal.title]),
		"Удалить", _delete, true)


func _delete() -> void:
	var id := _goal_id
	NavigationManager.go_back()
	if DataManager.remove_goal(id):
		NavigationManager.show_toast(Loc.t("Цель удалена"))
