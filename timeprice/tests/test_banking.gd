extends TestCase
## Депозит, кредит, рассрочка. Эталонные значения посчитаны по стандартным формулам.

const MILLION := 100_000_000  # 1 000 000,00


func test_monthly_interest_and_percent() -> void:
	assert_eq(FinanceMath.monthly_interest(MILLION, 1200), 1_000_000, "1 % в месяц от 1 000 000")
	assert_eq(FinanceMath.monthly_interest(MILLION, 0), 0)
	assert_eq(FinanceMath.monthly_interest(-5, 1200), 0)
	assert_eq(FinanceMath.percent_of(5_000_000, 1000), 500_000)


func test_deposit_monthly_capitalization() -> void:
	# 1 000 000 под 12 % на 12 мес.: по формуле 1 000 000 × 1,01^12 = 1 126 825,03.
	# Проценты округляются до тиына каждый месяц (как в банке), поэтому итог на 1 тиын меньше.
	var r := DepositCalculator.calculate(MILLION, 0, 1200, 12)
	assert_true(r["ok"])
	assert_eq(r["final_minor"], 112_682_502)
	assert_eq(r["contributed_minor"], MILLION)
	assert_eq(r["interest_minor"], 12_682_502)
	assert_eq((r["balances"] as Array).size(), 13)
	assert_almost(r["effective_rate"], 12.6825030131, 1e-6)


func test_deposit_without_capitalization() -> void:
	var r := DepositCalculator.calculate(MILLION, 0, 1200, 12, DepositCalculator.CAPITALIZATION_END)
	assert_eq(r["final_minor"], 112_000_000)
	assert_almost(r["effective_rate"], 12.0)


func test_deposit_with_topups() -> void:
	# Пополнение 10 000 в начале каждого месяца, 0 %: 12 × 10 000.
	var r := DepositCalculator.calculate(0, 1_000_000, 0, 12)
	assert_eq(r["final_minor"], 12_000_000)
	assert_eq(r["interest_minor"], 0)
	# С процентами накопится больше, чем внесено.
	var r2 := DepositCalculator.calculate(0, 1_000_000, 1200, 12)
	assert_eq(r2["contributed_minor"], 12_000_000)
	assert_true(r2["interest_minor"] > 0)
	# Пополнения в начале месяца: 10 000 × ((1,01^12 − 1) / 0,01) × 1,01 = 128 093,28;
	# с помесячным округлением процентов — 128 093,27.
	assert_eq(r2["final_minor"], 12_809_327)


func test_deposit_invalid() -> void:
	assert_eq(DepositCalculator.calculate(0, 0, 1200, 12)["error"], DepositCalculator.ERROR_INVALID_AMOUNT)
	assert_eq(DepositCalculator.calculate(MILLION, 0, -1, 12)["error"], DepositCalculator.ERROR_INVALID_RATE)
	assert_eq(DepositCalculator.calculate(MILLION, 0, 1200, 0)["error"], DepositCalculator.ERROR_INVALID_TERM)
	assert_eq(DepositCalculator.calculate(MILLION, 0, 1200, 601)["error"], DepositCalculator.ERROR_INVALID_TERM)


func test_deposit_months_to_target() -> void:
	assert_eq(DepositCalculator.months_to_target(0, 1_000_000, 0, 5_000_000), 5)
	assert_eq(DepositCalculator.months_to_target(MILLION, 0, 0, 2 * MILLION), -1, "без пополнений и процентов не накопить")
	assert_eq(DepositCalculator.months_to_target(MILLION, 0, 1200, 2 * MILLION), 70, "удвоение при 1 % в месяц")
	assert_eq(DepositCalculator.months_to_target(MILLION, 0, 1200, MILLION), 0)


func test_real_value() -> void:
	assert_eq(DepositCalculator.real_value(110_000_000, 1000, 12), MILLION)
	assert_eq(DepositCalculator.real_value(MILLION, 0, 12), MILLION)


func test_annuity_payment() -> void:
	# 1 000 000 под 12 % на 12 мес. — 88 848,79
	assert_eq(LoanCalculator.annuity_payment(MILLION, 1200, 12), 8_884_879)
	assert_eq(LoanCalculator.annuity_payment(MILLION, 0, 3), 33_333_334)


func test_loan_annuity_schedule() -> void:
	var r := LoanCalculator.calculate(MILLION, 1200, 12)
	assert_true(r["ok"])
	var rows: Array = r["rows"]
	assert_eq(rows.size(), 12)
	assert_eq(rows[0]["interest"], 1_000_000)
	assert_eq(rows[0]["payment"], 8_884_879)
	assert_eq(rows[11]["balance"], 0, "долг погашен полностью")
	var principal_sum := 0
	for row in rows:
		principal_sum += int(row["principal"])
	assert_eq(principal_sum, MILLION)
	assert_eq(r["total_payments"], MILLION + r["total_interest"])
	assert_true(absi(int(r["total_interest"]) - 6_618_550) < 200, "переплата ≈ 66 185,5")
	assert_almost(r["effective_rate"], 12.6825, 0.01)


func test_loan_differentiated() -> void:
	var r := LoanCalculator.calculate(MILLION, 1200, 12, LoanCalculator.TYPE_DIFFERENTIATED)
	assert_true(r["ok"])
	var rows: Array = r["rows"]
	# Первый платёж: 83 333,33 + 10 000 = 93 333,33
	assert_eq(rows[0]["payment"], 9_333_333)
	assert_eq(rows[11]["balance"], 0)
	assert_true(int(r["last_payment"]) < int(r["first_payment"]))
	# Переплата: сумма процентов = 1 000 000 × 1 % × (12 + 11 + ... + 1) / 12 = 65 000
	assert_true(absi(int(r["total_interest"]) - 6_500_000) < 10)
	assert_true(int(r["total_interest"]) < int(LoanCalculator.calculate(MILLION, 1200, 12)["total_interest"]),
		"дифференцированный дешевле аннуитетного")


func test_loan_fee_raises_effective_rate() -> void:
	var plain := LoanCalculator.calculate(MILLION, 1200, 12)
	var with_fee := LoanCalculator.calculate(MILLION, 1200, 12, LoanCalculator.TYPE_ANNUITY, 2_000_000)
	assert_eq(with_fee["overpayment"], int(plain["total_interest"]) + 2_000_000)
	assert_true(float(with_fee["effective_rate"]) > float(plain["effective_rate"]) + 3.0)


func test_loan_zero_rate() -> void:
	var r := LoanCalculator.calculate(MILLION, 0, 10)
	assert_eq(r["total_interest"], 0)
	assert_almost(r["effective_rate"], 0.0)
	assert_eq((r["rows"] as Array).back()["balance"], 0)


func test_loan_invalid() -> void:
	assert_eq(LoanCalculator.calculate(0, 1200, 12)["error"], LoanCalculator.ERROR_INVALID_AMOUNT)
	assert_eq(LoanCalculator.calculate(MILLION, 20_001, 12)["error"], LoanCalculator.ERROR_INVALID_RATE)
	assert_eq(LoanCalculator.calculate(MILLION, 1200, 0)["error"], LoanCalculator.ERROR_INVALID_TERM)
	assert_eq(LoanCalculator.calculate(MILLION, 1200, 12, LoanCalculator.TYPE_ANNUITY, MILLION)["error"], LoanCalculator.ERROR_INVALID_FEE)


func test_installment_zero_overpayment() -> void:
	# 0-0-12: 360 000 на 12 месяцев без наценки.
	var r := LoanCalculator.installment(36_000_000, 0, 12)
	assert_true(r["ok"])
	assert_eq(r["first_payment"], 3_000_000)
	assert_eq(r["total_paid"], 36_000_000)
	assert_eq(r["overpayment_vs_cash"], 0)
	assert_almost(r["effective_rate"], 0.0)


func test_installment_remainder_in_last_payment() -> void:
	var r := LoanCalculator.installment(10_000_000, 0, 3)
	var rows: Array = r["rows"]
	assert_eq(rows[0]["payment"], 3_333_333)
	assert_eq(rows[2]["payment"], 3_333_334)
	assert_eq(r["total_paid"], 10_000_000)


func test_installment_commission_and_discount() -> void:
	# Цена 300 000, взнос 60 000, 6 мес., наценка 6 %, скидка за оплату сразу 5 %.
	var r := LoanCalculator.installment(30_000_000, 6_000_000, 6, 600, 500)
	assert_eq(r["commission_minor"], 1_800_000)
	assert_eq(r["financed_minor"], 25_800_000)
	assert_eq(r["first_payment"], 4_300_000)
	assert_eq(r["total_paid"], 31_800_000)
	assert_eq(r["cash_price"], 28_500_000)
	assert_eq(r["overpayment_vs_cash"], 3_300_000)
	assert_true(float(r["effective_rate"]) > 30.0, "скрытая ставка заметно выше наценки")


func test_installment_discount_only_reveals_hidden_rate() -> void:
	var r := LoanCalculator.installment(36_000_000, 0, 12, 0, 1000)
	assert_eq(r["overpayment_vs_cash"], 3_600_000)
	assert_true(float(r["effective_rate"]) > 15.0 and float(r["effective_rate"]) < 30.0)


func test_installment_invalid() -> void:
	assert_eq(LoanCalculator.installment(0, 0, 12)["error"], LoanCalculator.ERROR_INVALID_AMOUNT)
	assert_eq(LoanCalculator.installment(100, 100, 12)["error"], LoanCalculator.ERROR_INVALID_DOWN_PAYMENT)
	assert_eq(LoanCalculator.installment(100, 0, 0)["error"], LoanCalculator.ERROR_INVALID_TERM)
	assert_eq(LoanCalculator.installment(100, 0, 3, 0, 10_000)["error"], LoanCalculator.ERROR_INVALID_RATE)


func test_irr() -> void:
	assert_almost(FinanceMath.irr_monthly([100.0, -101.0]), 0.01, 1e-9)
	assert_almost(FinanceMath.irr_monthly([100.0, -100.0]), 0.0)
	assert_almost(FinanceMath.annual_effective_percent(0.01), 12.6825030131, 1e-6)
