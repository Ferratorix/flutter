class_name PurchaseSimulator
extends RefCounted
## Моделирование покупки: «купить сейчас», «через 3 месяца», «через 6 месяцев».
##
## Модель линейная и намеренно простая: каждый месяц накопления растут на
## регулярную сумму, покупка единовременно уменьшает их на свою стоимость.
## Проценты по вкладам, инфляция и изменение цены не учитываются.
## Результат — оценка на основе введённых данных, а не гарантия.

const DELAYS := [0, 3, 6]
## Горизонт прогноза в месяцах.
const HORIZON_MONTHS := 12

const WARNING_NO_REGULAR_SAVINGS := "no_regular_savings"
const WARNING_EXPENSES_EXCEED_INCOME := "expenses_exceed_income"
const WARNING_SAVINGS_EXCEED_FREE_CASH := "savings_exceed_free_cash"
const WARNING_NO_EXPENSES := "no_expenses"

const ERROR_NONE := ""
const ERROR_INVALID_PRICE := "invalid_price"
const ERROR_INVALID_INCOME := "invalid_income"
const ERROR_INVALID_SAVINGS := "invalid_savings"
const ERROR_INVALID_EXPENSES := "invalid_expenses"
const ERROR_INVALID_MONTHLY_SAVINGS := "invalid_monthly_savings"


## Аргументы — int в минимальных единицах. expenses_minor = -1 — расходы не указаны.
## Возвращает словарь:
##   ok, error, warnings: Array[String], scenarios: Array[PurchaseScenario],
##   baseline: Array[int] (накопления без покупки), recovery_months (-1 — не рассчитать),
##   free_cash_minor (доход минус обязательные расходы).
static func simulate(price_minor: int, savings_minor: int, income_minor: int,
		expenses_minor: int, monthly_savings_minor: int) -> Dictionary:
	var result := {
		"ok": false,
		"error": ERROR_NONE,
		"warnings": [],
		"scenarios": [],
		"baseline": [],
		"recovery_months": -1,
		"free_cash_minor": 0,
	}
	if not FinancialCalculator.is_price_valid(price_minor):
		result["error"] = ERROR_INVALID_PRICE
		return result
	if not FinancialCalculator.is_income_valid(income_minor):
		result["error"] = ERROR_INVALID_INCOME
		return result
	if savings_minor < 0 or savings_minor > Money.MAX_MINOR:
		result["error"] = ERROR_INVALID_SAVINGS
		return result
	if expenses_minor < -1 or expenses_minor > Money.MAX_MINOR:
		result["error"] = ERROR_INVALID_EXPENSES
		return result
	if monthly_savings_minor < 0 or monthly_savings_minor > Money.MAX_MINOR:
		result["error"] = ERROR_INVALID_MONTHLY_SAVINGS
		return result

	var warnings: Array[String] = []
	var expenses := maxi(expenses_minor, 0)
	var free_cash := income_minor - expenses
	result["free_cash_minor"] = free_cash
	if expenses_minor < 0:
		warnings.append(WARNING_NO_EXPENSES)
	if expenses > income_minor:
		warnings.append(WARNING_EXPENSES_EXCEED_INCOME)
	elif monthly_savings_minor > free_cash:
		warnings.append(WARNING_SAVINGS_EXCEED_FREE_CASH)
	if monthly_savings_minor == 0:
		warnings.append(WARNING_NO_REGULAR_SAVINGS)

	result["baseline"] = projection(savings_minor, monthly_savings_minor, -1, 0)
	result["recovery_months"] = recovery_months(price_minor, monthly_savings_minor)

	var scenarios: Array[PurchaseScenario] = []
	for d in DELAYS:
		scenarios.append(build_scenario(d, price_minor, savings_minor, expenses_minor, monthly_savings_minor))
	result["scenarios"] = scenarios
	result["warnings"] = warnings
	result["ok"] = true
	return result


static func build_scenario(delay: int, price_minor: int, savings_minor: int,
		expenses_minor: int, monthly_savings_minor: int) -> PurchaseScenario:
	var s := PurchaseScenario.new()
	s.delay_months = delay
	s.savings_before_minor = savings_minor + delay * monthly_savings_minor
	s.savings_after_minor = s.savings_before_minor - price_minor
	s.shortfall_minor = maxi(0, -s.savings_after_minor)
	s.months_until_affordable = months_until_affordable(price_minor, savings_minor, monthly_savings_minor)
	if expenses_minor > 0:
		s.cushion_months = maxf(0.0, float(s.savings_after_minor) / float(expenses_minor))
	else:
		s.cushion_months = -1.0
	s.projection = projection(savings_minor, monthly_savings_minor, delay, price_minor)
	return s


## Накопления на начало (0) и конец каждого месяца до HORIZON_MONTHS.
## purchase_month = -1 — без покупки.
static func projection(savings_minor: int, monthly_savings_minor: int, purchase_month: int, price_minor: int) -> Array[int]:
	var values: Array[int] = []
	for m in range(HORIZON_MONTHS + 1):
		var v := savings_minor + m * monthly_savings_minor
		if purchase_month >= 0 and m >= purchase_month:
			v -= price_minor
		values.append(v)
	return values


## Месяцев, чтобы регулярными накоплениями вернуть потраченную сумму; -1 — не рассчитать.
static func recovery_months(price_minor: int, monthly_savings_minor: int) -> int:
	if price_minor <= 0:
		return 0
	return FinancialCalculator.months_to_goal(price_minor, monthly_savings_minor)


## Через сколько месяцев от сегодня накоплений хватит на покупку.
static func months_until_affordable(price_minor: int, savings_minor: int, monthly_savings_minor: int) -> int:
	if savings_minor >= price_minor:
		return 0
	return FinancialCalculator.months_to_goal(price_minor - savings_minor, monthly_savings_minor)


## Насколько покупка отодвинет цель, если оплачивается из средств, которые
## иначе пошли бы на цель. Возвращает {"ok", "months_before", "months_after", "delay_months"}.
static func goal_impact(goal: FinancialGoal, price_minor: int) -> Dictionary:
	var impact := {"ok": false, "months_before": -1, "months_after": -1, "delay_months": -1}
	if goal == null or price_minor <= 0 or goal.monthly_contribution_minor <= 0:
		return impact
	var remaining := goal.remaining_minor()
	var before := FinancialCalculator.months_to_goal(remaining, goal.monthly_contribution_minor)
	var after := FinancialCalculator.months_to_goal(mini(remaining + price_minor, Money.MAX_MINOR), goal.monthly_contribution_minor)
	if before < 0 or after < 0:
		return impact
	impact["ok"] = true
	impact["months_before"] = before
	impact["months_after"] = after
	impact["delay_months"] = after - before
	return impact
