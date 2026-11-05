class_name GoalView
extends RefCounted
## Общие элементы отображения финансовой цели (список целей, главная, детали).


## Текст прогноза срока. Формулировка подчёркивает, что это оценка.
static func eta_text(goal: FinancialGoal) -> String:
	if goal.is_completed():
		return Loc.t("Цель достигнута")
	if goal.monthly_contribution_minor <= 0:
		return Loc.t("Укажите регулярный взнос, чтобы оценить срок")
	var months := goal.months_left()
	if months < 0:
		return Loc.t("При текущем взносе срок больше 100 лет")
	return Loc.tf("Примерно %s — к %s", [Fmt.months_duration(months), Fmt.month_year_from_now(months)])


## Компактное содержимое карточки цели.
static func fill_summary(box: VBoxContainer, goal: FinancialGoal, profile: UserProfile) -> void:
	var top := UI.hbox(8)
	box.add_child(top)
	var title := UI.label(goal.title, &"ValueLabel")
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if goal.is_primary:
		top.add_child(UI.tag("Основная", AppTheme.ACCENT))
	var amounts := UI.hbox(8)
	box.add_child(amounts)
	var saved := UI.label(Fmt.money(goal.saved_minor, goal.currency), &"AccentLabel")
	amounts.add_child(saved)
	var target := UI.label(Loc.tf("из %s", [Fmt.money(goal.target_minor, goal.currency)]), &"CaptionLabel", true)
	target.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amounts.add_child(target)
	var pct := UI.label(Fmt.percent(goal.progress_percent()), &"")
	pct.add_theme_font_override("font", AppTheme.bold_font())
	amounts.add_child(pct)
	box.add_child(UI.progress_bar(goal.progress_percent()))
	if not goal.is_completed():
		var remaining_text := Loc.tf("Осталось %s", [Fmt.money(goal.remaining_minor(), goal.currency)])
		var minutes := goal.remaining_work_minutes(profile)
		if minutes > 0:
			remaining_text += " · ≈ " + Fmt.duration(minutes) + " " + Loc.t("работы")
		box.add_child(UI.label(remaining_text, &"CaptionLabel", true))
	box.add_child(UI.label(eta_text(goal), &"MutedLabel", true))
