extends TestCase
## Покупка 350 000, накоплено 500 000, доход 400 000, расходы 200 000, откладывается 60 000.

const PRICE := 35_000_000
const SAVINGS := 50_000_000
const INCOME := 40_000_000
const EXPENSES := 20_000_000
const MONTHLY := 6_000_000


func _sim() -> Dictionary:
	return PurchaseSimulator.simulate(PRICE, SAVINGS, INCOME, EXPENSES, MONTHLY)


func _scenario(sim: Dictionary, delay: int) -> PurchaseScenario:
	for s in sim["scenarios"]:
		if (s as PurchaseScenario).delay_months == delay:
			return s
	return null


func test_three_scenarios() -> void:
	var sim := _sim()
	assert_true(sim["ok"])
	assert_eq((sim["scenarios"] as Array).size(), 3)
	assert_not_null(_scenario(sim, 0))
	assert_not_null(_scenario(sim, 3))
	assert_not_null(_scenario(sim, 6))
	assert_eq((sim["warnings"] as Array).size(), 0)


func test_buy_now() -> void:
	var s := _scenario(_sim(), 0)
	assert_eq(s.savings_before_minor, SAVINGS)
	assert_eq(s.savings_after_minor, 15_000_000)
	assert_true(s.is_affordable())
	assert_eq(s.months_until_affordable, 0)
	assert_almost(s.cushion_months, 0.75)


func test_buy_in_three_and_six_months() -> void:
	var sim := _sim()
	var s3 := _scenario(sim, 3)
	assert_eq(s3.savings_before_minor, 68_000_000)
	assert_eq(s3.savings_after_minor, 33_000_000)
	var s6 := _scenario(sim, 6)
	assert_eq(s6.savings_before_minor, 86_000_000)
	assert_eq(s6.savings_after_minor, 51_000_000)
	assert_almost(s6.cushion_months, 2.55)


func test_projection() -> void:
	var sim := _sim()
	var baseline: Array = sim["baseline"]
	assert_eq(baseline.size(), PurchaseSimulator.HORIZON_MONTHS + 1)
	assert_eq(baseline[0], SAVINGS)
	assert_eq(baseline[12], SAVINGS + 12 * MONTHLY)
	var s3 := _scenario(sim, 3)
	assert_eq(s3.projection[2], SAVINGS + 2 * MONTHLY, "до покупки совпадает с базовым прогнозом")
	assert_eq(s3.projection[3], SAVINGS + 3 * MONTHLY - PRICE)
	# Без процентов итог через 12 месяцев одинаков во всех сценариях.
	for d in PurchaseSimulator.DELAYS:
		assert_eq(_scenario(sim, d).savings_at_horizon(), SAVINGS + 12 * MONTHLY - PRICE)


func test_recovery_months() -> void:
	# 350 000 / 60 000 = 5,83 -> 6 месяцев.
	assert_eq(_sim()["recovery_months"], 6)
	assert_eq(PurchaseSimulator.recovery_months(PRICE, 0), -1)


func test_not_affordable_now() -> void:
	var sim := PurchaseSimulator.simulate(PRICE, 20_000_000, INCOME, EXPENSES, MONTHLY)
	var s0 := _scenario(sim, 0)
	assert_false(s0.is_affordable())
	assert_eq(s0.shortfall_minor, 15_000_000)
	# Не хватает 150 000 при 60 000 в месяц — 3 месяца.
	assert_eq(s0.months_until_affordable, 3)
	assert_eq(s0.cushion_months, 0.0)
	assert_true(_scenario(sim, 3).is_affordable())


func test_warnings() -> void:
	var w: Array = PurchaseSimulator.simulate(PRICE, SAVINGS, INCOME, -1, 0)["warnings"]
	assert_true(w.has(PurchaseSimulator.WARNING_NO_EXPENSES))
	assert_true(w.has(PurchaseSimulator.WARNING_NO_REGULAR_SAVINGS))
	w = PurchaseSimulator.simulate(PRICE, SAVINGS, INCOME, 50_000_000, MONTHLY)["warnings"]
	assert_true(w.has(PurchaseSimulator.WARNING_EXPENSES_EXCEED_INCOME))
	w = PurchaseSimulator.simulate(PRICE, SAVINGS, INCOME, 38_000_000, MONTHLY)["warnings"]
	assert_true(w.has(PurchaseSimulator.WARNING_SAVINGS_EXCEED_FREE_CASH))


func test_no_regular_savings() -> void:
	var sim := PurchaseSimulator.simulate(PRICE, 10_000_000, INCOME, EXPENSES, 0)
	assert_eq(sim["recovery_months"], -1)
	assert_eq(_scenario(sim, 6).months_until_affordable, -1)
	assert_eq(_scenario(sim, 6).cushion_months, 0.0)


func test_invalid_input() -> void:
	assert_eq(PurchaseSimulator.simulate(0, SAVINGS, INCOME, EXPENSES, MONTHLY)["error"], PurchaseSimulator.ERROR_INVALID_PRICE)
	assert_eq(PurchaseSimulator.simulate(PRICE, SAVINGS, 0, EXPENSES, MONTHLY)["error"], PurchaseSimulator.ERROR_INVALID_INCOME)
	assert_eq(PurchaseSimulator.simulate(PRICE, -1, INCOME, EXPENSES, MONTHLY)["error"], PurchaseSimulator.ERROR_INVALID_SAVINGS)
	assert_eq(PurchaseSimulator.simulate(PRICE, SAVINGS, INCOME, -5, MONTHLY)["error"], PurchaseSimulator.ERROR_INVALID_EXPENSES)
	assert_eq(PurchaseSimulator.simulate(PRICE, SAVINGS, INCOME, EXPENSES, -1)["error"], PurchaseSimulator.ERROR_INVALID_MONTHLY_SAVINGS)
	assert_false(PurchaseSimulator.simulate(PRICE, SAVINGS, INCOME, EXPENSES, -1)["ok"])


func test_goal_impact() -> void:
	# Осталось 1 200 000 при взносе 100 000 -> 12 мес.; с покупкой 350 000 -> 16 мес.
	var goal := FinancialGoal.create("Отпуск", 150_000_000, 30_000_000, 10_000_000, "KZT")
	var impact := PurchaseSimulator.goal_impact(goal, PRICE)
	assert_true(impact["ok"])
	assert_eq(impact["months_before"], 12)
	assert_eq(impact["months_after"], 16)
	assert_eq(impact["delay_months"], 4)
	goal.monthly_contribution_minor = 0
	assert_false(PurchaseSimulator.goal_impact(goal, PRICE)["ok"])
	assert_false(PurchaseSimulator.goal_impact(null, PRICE)["ok"])


func test_compact_amount() -> void:
	assert_eq(Fmt.compact_amount(35_000_000), "350 тыс.")
	assert_eq(Fmt.compact_amount(125_000_000), "1,3 млн")
	assert_eq(Fmt.compact_amount(-4_000_000), "−40 тыс.")
	assert_eq(Fmt.compact_amount(50_000), "500")
	assert_eq(Fmt.compact_amount(0), "0")
