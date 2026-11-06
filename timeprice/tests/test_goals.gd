extends TestCase


func test_goal_progress() -> void:
	assert_almost(FinancialCalculator.goal_progress(25_000, 100_000), 25.0)
	assert_almost(FinancialCalculator.goal_progress(150_000, 100_000), 100.0, 1e-9, "не больше 100 %")
	assert_almost(FinancialCalculator.goal_progress(0, 100_000), 0.0)
	assert_almost(FinancialCalculator.goal_progress(100, 0), 0.0, 1e-9, "без деления на ноль")
	assert_almost(FinancialCalculator.goal_progress(-100, 1000), 0.0)


func test_goal_remaining() -> void:
	assert_eq(FinancialCalculator.goal_remaining(25_000, 100_000), 75_000)
	assert_eq(FinancialCalculator.goal_remaining(150_000, 100_000), 0)
	assert_eq(FinancialCalculator.goal_remaining(-5, 100), 100)
	assert_eq(FinancialCalculator.goal_remaining(0, 0), 0)


func test_months_to_goal() -> void:
	assert_eq(FinancialCalculator.months_to_goal(100_000, 25_000), 4)
	assert_eq(FinancialCalculator.months_to_goal(100_001, 25_000), 5, "округление вверх")
	assert_eq(FinancialCalculator.months_to_goal(0, 25_000), 0)
	assert_eq(FinancialCalculator.months_to_goal(100_000, 0), -1)
	assert_eq(FinancialCalculator.months_to_goal(100_000, -10), -1)
	assert_eq(FinancialCalculator.months_to_goal(Money.MAX_MINOR, 1), -1, "больше 100 лет")
	assert_eq(FinancialCalculator.months_to_goal(1200, 1), 1200)


func test_add_months() -> void:
	assert_eq(FinancialCalculator.add_months(2026, 11, 3), Vector2i(2027, 2))
	assert_eq(FinancialCalculator.add_months(2026, 1, 0), Vector2i(2026, 1))
	assert_eq(FinancialCalculator.add_months(2026, 12, 1), Vector2i(2027, 1))
	assert_eq(FinancialCalculator.add_months(2026, 6, 24), Vector2i(2028, 6))


func test_months_duration_text() -> void:
	assert_eq(Fmt.months_duration(1), "1 месяц")
	assert_eq(Fmt.months_duration(5), "5 месяцев")
	assert_eq(Fmt.months_duration(12), "1 год")
	assert_eq(Fmt.months_duration(15), "1 год 3 месяца")
	assert_eq(Fmt.months_duration(60), "5 лет")
	assert_eq(Fmt.month_year(2027, 3), "март 2027")


func test_goal_model() -> void:
	var g := FinancialGoal.create("  Отпуск ", 150_000_000, 30_000_000, 10_000_000, "KZT")
	assert_true(g.is_valid())
	assert_eq(g.title, "Отпуск")
	assert_eq(g.remaining_minor(), 120_000_000)
	assert_eq(g.months_left(), 12)
	assert_almost(g.progress_percent(), 20.0)
	assert_eq(g.entries.size(), 1)
	assert_eq(g.entries[0]["kind"], FinancialGoal.KIND_INITIAL)


func test_goal_contributions_and_edit() -> void:
	var g := FinancialGoal.create("Ноутбук", 100_000, 0, 0, "KZT")
	assert_false(g.add_contribution(0))
	assert_false(g.add_contribution(-5))
	assert_true(g.add_contribution(60_000))
	assert_true(g.add_contribution(50_000))
	assert_eq(g.saved_minor, 110_000)
	assert_true(g.is_completed())
	assert_eq(g.remaining_minor(), 0)
	g.set_saved(40_000)
	assert_eq(g.saved_minor, 40_000)
	var last: Dictionary = g.entries.back()
	assert_eq(last["kind"], FinancialGoal.KIND_EDIT)
	assert_eq(last["delta_minor"], -70_000)
	assert_eq(g.entries.size(), 4)


func test_goal_remaining_work_minutes() -> void:
	var p := UserProfile.new()
	p.monthly_income_minor = 40_000_000
	var g := FinancialGoal.create("Цель", 35_000_000, 0, 0, "KZT")
	assert_eq(g.remaining_work_minutes(p), 9240)
	g.currency = "USD"
	assert_eq(g.remaining_work_minutes(p), -1, "другая валюта — нельзя посчитать")


func test_goal_json_roundtrip() -> void:
	var g := FinancialGoal.create("Подушка безопасности", 120_000_000, 10_000_000, 5_000_000, "KZT")
	g.add_contribution(2_500_000)
	g.is_primary = true
	var restored := FinancialGoal.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	assert_not_null(restored)
	assert_eq(restored.saved_minor, g.saved_minor)
	assert_eq(restored.monthly_contribution_minor, 5_000_000)
	assert_true(restored.is_primary)
	assert_eq(restored.entries.size(), 2)
	assert_eq(int(restored.entries[1]["delta_minor"]), 2_500_000)


func test_goal_from_invalid_dict() -> void:
	assert_null(FinancialGoal.from_dict({}))
	assert_null(FinancialGoal.from_dict({"id": "a", "title": "x", "target_minor": 0}))
	var g := FinancialGoal.from_dict({"id": "a", "title": "x", "target_minor": 100,
		"entries": [{"kind": "unknown"}, "мусор", {"kind": "deposit", "delta_minor": 10, "saved_minor": 10, "at": 1}]})
	assert_not_null(g)
	assert_eq(g.entries.size(), 1, "некорректные записи журнала отброшены")
