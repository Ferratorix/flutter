class_name Advisor
extends RefCounted
## Персональные рекомендации на основе данных пользователя.
##
## Только правила по введённым данным — без внешних источников и обещаний
## доходности. Каждая рекомендация: {"id", "icon", "title", "text",
## "action", "route", "params", "priority"} — чем меньше priority, тем выше.

## Минимальная подушка безопасности в месяцах обязательных расходов.
const CUSHION_MONTHS := 3
## Рекомендуемая минимальная доля накоплений от дохода.
const MIN_SAVINGS_RATE := 10.0
## Порог долговой нагрузки для предупреждения.
const LOAN_BURDEN_WARNING := 40.0
## Желание дороже этой доли месячного дохода считается крупным.
const BIG_PURCHASE_PERCENT := 30.0


## inputs: {"expenses_minor": int (-1 — неизвестно), "monthly_savings_minor": int (-1),
##          "loan": Dictionary (сохранённые поля кредита), "deposit_used": bool, "now": int}
static func build(profile: UserProfile, goals: Array, wishlist: Array, inputs: Dictionary) -> Array:
	var out: Array = []
	if profile == null or not profile.is_valid():
		return out
	var code := profile.currency
	var income := profile.monthly_income_minor
	var expenses: int = inputs.get("expenses_minor", -1)
	var monthly: int = inputs.get("monthly_savings_minor", -1)
	var now: int = inputs.get("now", DataUtil.now())

	# Решения по желаниям после паузы.
	var due := 0
	for item in wishlist:
		var w := item as WishlistItem
		if w != null and w.is_decision_due(now):
			due += 1
	if due > 0:
		out.append(_rec("decisions", "heart", Loc.tf("Пауза закончилась: %d %s", [due, Loc.plural(due, ["желание", "желания", "желаний"])]),
			Loc.t("Решите, нужны ли эти покупки. Если передумаете, сумма попадёт в копилку решений."),
			Loc.t("Открыть желания"), "wishlist", {}, 0))

	# Подушка безопасности.
	var has_cushion_goal := false
	for g in goals:
		if (g as FinancialGoal).title.to_lower().contains("подушк"):
			has_cushion_goal = true
	if expenses > 0:
		var cushion := expenses * CUSHION_MONTHS
		if profile.has_savings() and profile.savings_minor < cushion and not has_cushion_goal:
			var months := float(profile.savings_minor) / float(expenses)
			out.append(_rec("cushion", "shield", Loc.t("Создайте подушку безопасности"),
				Loc.tf("Накоплений хватит примерно на %s мес. обязательных расходов. Минимальный запас — %d месяца: %s.",
					[Fmt.decimal(months, 1), CUSHION_MONTHS, Fmt.money(cushion, code)]),
				Loc.t("Создать цель"), "goal_edit", {"title": Loc.t("Подушка безопасности"), "target_minor": cushion}, 1))
	else:
		out.append(_rec("expenses", "calculator", Loc.t("Посчитайте обязательные расходы"),
			Loc.t("Зная расходы, TIMEPRICE оценит размер подушки безопасности и запас после покупок. Укажите их в моделировании покупки."),
			Loc.t("Указать расходы"), "simulator", {}, 4))

	# Накопления не указаны.
	if not profile.has_savings():
		out.append(_rec("savings", "percent", Loc.t("Укажите текущие накопления"),
			Loc.t("Тогда калькулятор сравнит покупки с накоплениями, а советы станут точнее."),
			Loc.t("Открыть настройки"), "settings", {}, 3))

	# Цели.
	if goals.is_empty():
		out.append(_rec("goal", "target", Loc.t("Поставьте финансовую цель"),
			Loc.t("С целью проще копить: приложение покажет прогресс, срок и сколько рабочего времени осталось."),
			Loc.t("Создать цель"), "goal_edit", {}, 2))
	else:
		for g in goals:
			var goal := g as FinancialGoal
			if goal.is_primary and not goal.is_completed() and goal.monthly_contribution_minor <= 0:
				out.append(_rec("goal_contribution", "target", Loc.tf("Регулярный взнос для цели «%s»", [goal.title]),
					Loc.t("Фиксированная сумма каждый месяц — самый надёжный способ дойти до цели. Укажите её, и появится прогноз срока."),
					Loc.t("Изменить цель"), "goal_edit", {"id": goal.id}, 2))

	# Норма сбережений.
	if monthly >= 0 and income > 0:
		var rate := float(monthly) * 100.0 / float(income)
		if rate < MIN_SAVINGS_RATE:
			var target := FinanceMath.percent_of(income, int(MIN_SAVINGS_RATE * 100))
			out.append(_rec("savings_rate", "trend", Loc.t("Сначала заплатите себе"),
				Loc.tf("Сейчас вы откладываете %s дохода. 10 %% — это %s в месяц и %s за год.",
					[Fmt.percent(rate), Fmt.money(target, code), Fmt.money(target * 12, code)]),
				Loc.t("Посчитать на депозите"), "deposit", {}, 3))

	# Крупные желания без паузы.
	var active_total := 0
	var big_without_pause := 0
	for item in wishlist:
		var w := item as WishlistItem
		if w == null or not w.is_active() or w.currency != code:
			continue
		active_total = mini(active_total + w.price_minor, Money.MAX_MINOR)
		if not w.has_cooldown() and FinancialCalculator.income_percentage(w.price_minor, income) >= BIG_PURCHASE_PERCENT:
			big_without_pause += 1
	if big_without_pause > 0:
		out.append(_rec("pause", "clock", Loc.t("Пауза для крупных желаний"),
			Loc.tf("%d %s дороже трети месячного дохода. Поставьте паузу на несколько дней — импульсивные желания часто проходят.",
				[big_without_pause, Loc.plural(big_without_pause, ["желание", "желания", "желаний"])]),
			Loc.t("Открыть желания"), "wishlist", {}, 3))
	if active_total > income * 3:
		out.append(_rec("wishlist_total", "heart", Loc.t("Список желаний больше трёх доходов"),
			Loc.tf("Все желания стоят %s — это %s месячных дохода. Отметьте приоритеты и сравните покупки между собой.",
				[Fmt.money(active_total, code), Fmt.decimal(float(active_total) / float(income), 1)]),
			Loc.t("Сравнить желания"), "wishlist", {}, 5))

	# Нагрузка по кредиту из калькулятора.
	var loan: Dictionary = inputs.get("loan", {})
	var amount: int = int(loan.get("amount", -1))
	var rate_h: int = int(loan.get("rate", -1))
	var term: int = int(loan.get("term", -1))
	if amount > 0 and rate_h >= 0 and term > 0:
		var r := LoanCalculator.calculate(amount, rate_h, term, str(loan.get("type", LoanCalculator.TYPE_ANNUITY)))
		if r["ok"]:
			var burden := FinancialCalculator.income_percentage(r["max_payment"], income)
			if burden >= LOAN_BURDEN_WARNING:
				out.append(_rec("loan_burden", "bank", Loc.t("Высокая нагрузка по кредиту"),
					Loc.tf("Платёж %s займёт %s дохода. Попробуйте больший срок, меньшую сумму или сначала накопить часть.",
						[Fmt.money(r["max_payment"], code), Fmt.percent(burden)]),
					Loc.t("Пересчитать кредит"), "loan", {}, 1))

	# Деньги без процентов.
	if profile.has_savings() and profile.savings_minor > 0 and not inputs.get("deposit_used", false):
		out.append(_rec("deposit", "percent", Loc.t("Посчитайте доход на депозите"),
			Loc.tf("Сколько могут принести ваши %s под проценты и как на них повлияет инфляция.", [Fmt.money(profile.savings_minor, code)]),
			Loc.t("Открыть депозит"), "deposit", {}, 6))

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["priority"]) < int(b["priority"]))
	return out


## Рекомендации по текущим данным приложения.
static func for_current_user() -> Array:
	return build(DataManager.profile, DataManager.goals, DataManager.wishlist, {
		"expenses_minor": SettingsManager.simulator_expenses_minor,
		"monthly_savings_minor": SettingsManager.simulator_monthly_savings_minor,
		"loan": SettingsManager.get_tool_inputs("loan"),
		"deposit_used": not SettingsManager.get_tool_inputs("deposit").is_empty(),
		"now": DataUtil.now(),
	})


static func _rec(id: String, icon: String, title: String, text: String, action: String,
		route: String, params: Dictionary, priority: int) -> Dictionary:
	return {"id": id, "icon": icon, "title": title, "text": text, "action": action,
		"route": route, "params": params, "priority": priority}
