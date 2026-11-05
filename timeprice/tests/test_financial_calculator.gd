extends TestCase
## Пример из ТЗ: доход 400 000, 22 дня, 8 часов, покупка 350 000.

const INCOME := 40_000_000      # 400 000,00
const PRICE := 35_000_000       # 350 000,00
const DAYS := 22
const MINUTES := 480


func test_hourly_rate_reference_example() -> void:
	# 400 000 / (22 × 8) = 2 272,7272…
	assert_almost(FinancialCalculator.hourly_rate(INCOME, DAYS, MINUTES), 227_272.727272727, 1e-6)
	assert_eq(FinancialCalculator.hourly_rate_rounded(INCOME, DAYS, MINUTES), 227_273)


func test_purchase_hours_reference_example() -> void:
	# 350 000 / 2 272,7272… = 154 ч
	assert_almost(FinancialCalculator.purchase_hours(PRICE, INCOME, DAYS, MINUTES), 154.0, 1e-9)
	assert_eq(FinancialCalculator.purchase_minutes(PRICE, INCOME, DAYS, MINUTES), 154 * 60)


func test_purchase_days_reference_example() -> void:
	# 154 / 8 = 19,25 дня
	assert_almost(FinancialCalculator.purchase_days(PRICE, INCOME, DAYS), 19.25, 1e-9)


func test_income_percentage() -> void:
	assert_almost(FinancialCalculator.income_percentage(PRICE, INCOME), 87.5, 1e-9)
	assert_almost(FinancialCalculator.income_percentage(INCOME * 2, INCOME), 200.0, 1e-9)
	assert_almost(FinancialCalculator.income_percentage(0, INCOME), 0.0)


func test_days_equal_hours_divided_by_day_length() -> void:
	for minutes in [240, 450, 480, 600, 720]:
		var hours := FinancialCalculator.purchase_hours(1_234_567, INCOME, DAYS, minutes)
		var days := FinancialCalculator.purchase_days(1_234_567, INCOME, DAYS)
		assert_almost(days, hours / (minutes / 60.0), 1e-9, "минут в дне: %d" % minutes)


func test_fractional_hours_per_day() -> void:
	# 7,5 ч × 20 дней = 150 ч; доход 300 000 -> 2 000 за час; покупка 5 000 -> 2,5 ч.
	assert_almost(FinancialCalculator.hourly_rate(30_000_000, 20, 450), 200_000.0, 1e-9)
	assert_almost(FinancialCalculator.purchase_hours(500_000, 30_000_000, 20, 450), 2.5, 1e-12)
	assert_eq(FinancialCalculator.purchase_minutes(500_000, 30_000_000, 20, 450), 150)


func test_no_division_by_zero() -> void:
	assert_eq(FinancialCalculator.hourly_rate(INCOME, 0, MINUTES), 0.0)
	assert_eq(FinancialCalculator.hourly_rate(INCOME, DAYS, 0), 0.0)
	assert_eq(FinancialCalculator.hourly_rate(0, DAYS, MINUTES), 0.0)
	assert_eq(FinancialCalculator.purchase_hours(PRICE, 0, DAYS, MINUTES), 0.0)
	assert_eq(FinancialCalculator.purchase_days(PRICE, 0, DAYS), 0.0)
	assert_eq(FinancialCalculator.income_percentage(PRICE, 0), 0.0)
	assert_eq(FinancialCalculator.savings_percentage(PRICE, 0), -1.0)
	assert_eq(FinancialCalculator.monthly_work_minutes(0, 480), 0)


func test_negative_values_rejected() -> void:
	assert_false(FinancialCalculator.is_profile_valid(-1, DAYS, MINUTES))
	assert_false(FinancialCalculator.is_profile_valid(INCOME, -5, MINUTES))
	assert_false(FinancialCalculator.is_profile_valid(INCOME, DAYS, -60))
	assert_eq(FinancialCalculator.purchase_hours(-100, INCOME, DAYS, MINUTES), 0.0)
	assert_eq(FinancialCalculator.income_percentage(-100, INCOME), 0.0)
	assert_eq(FinancialCalculator.convert_amount(-1, 10_000), -1)
	assert_eq(FinancialCalculator.convert_amount(100, -1), -1)


func test_schedule_bounds() -> void:
	assert_true(FinancialCalculator.is_schedule_valid(1, 30))
	assert_true(FinancialCalculator.is_schedule_valid(31, 1440))
	assert_false(FinancialCalculator.is_schedule_valid(32, 480))
	assert_false(FinancialCalculator.is_schedule_valid(22, 1441))
	assert_false(FinancialCalculator.is_schedule_valid(22, 29))


func test_calculate_full_result() -> void:
	var r := FinancialCalculator.calculate(PRICE, INCOME, DAYS, MINUTES, 80_000_000)
	assert_true(r["ok"])
	assert_eq(r["error"], FinancialCalculator.ERROR_NONE)
	assert_eq(r["total_minutes"], 9240)
	assert_eq(r["full_days"], 19)
	assert_eq(r["remainder_minutes"], 120)
	assert_almost(r["days"], 19.25)
	assert_almost(r["income_percentage"], 87.5)
	assert_almost(r["savings_percentage"], 43.75)
	assert_eq(r["savings_left_minor"], 45_000_000)


func test_calculate_without_savings() -> void:
	var r := FinancialCalculator.calculate(PRICE, INCOME, DAYS, MINUTES)
	assert_true(r["ok"])
	assert_false(r["has_savings"])
	assert_eq(r["savings_percentage"], -1.0)


func test_calculate_errors() -> void:
	assert_eq(FinancialCalculator.calculate(PRICE, 0, DAYS, MINUTES)["error"], FinancialCalculator.ERROR_INVALID_PROFILE)
	assert_eq(FinancialCalculator.calculate(0, INCOME, DAYS, MINUTES)["error"], FinancialCalculator.ERROR_INVALID_PRICE)
	assert_eq(FinancialCalculator.calculate(-5, INCOME, DAYS, MINUTES)["error"], FinancialCalculator.ERROR_INVALID_PRICE)
	assert_false(FinancialCalculator.calculate(PRICE, INCOME, 0, MINUTES)["ok"])


func test_minimal_price_rounds_to_minutes() -> void:
	# 1 тиын при доходе 400 000 — меньше минуты.
	assert_eq(FinancialCalculator.purchase_minutes(1, INCOME, DAYS, MINUTES), 0)
	assert_true(FinancialCalculator.purchase_hours(1, INCOME, DAYS, MINUTES) > 0.0)


func test_extreme_values_do_not_overflow() -> void:
	var r := FinancialCalculator.calculate(Money.MAX_MINOR, 100, 31, 1440)
	assert_true(r["ok"])
	assert_true(r["total_minutes"] > 0, "результат положительный — переполнения нет")
	assert_almost(r["days"], 31.0 * Money.MAX_MINOR / 100.0, 1.0)


func test_convert_amount() -> void:
	# 100,00 USD × 512,5 = 51 250,00 ₸
	assert_eq(FinancialCalculator.convert_amount(10_000, 5_125_000), 5_125_000)
	# 0,01 × 0,5 = 0,005 -> 0,01 (округление половины вверх)
	assert_eq(FinancialCalculator.convert_amount(1, 5_000), 1)
	assert_eq(FinancialCalculator.convert_amount(10_000, 10_000), 10_000, "курс 1:1")
	assert_eq(FinancialCalculator.convert_amount(Money.MAX_MINOR, 20_000), -1, "переполнение")
	assert_eq(FinancialCalculator.convert_amount(100, 0), -1)


func test_float_free_precision() -> void:
	# 0,1 + 0,2 в минимальных единицах — точное сложение.
	assert_eq(Money.parse("0,1") + Money.parse("0,2"), Money.parse("0,3"))
