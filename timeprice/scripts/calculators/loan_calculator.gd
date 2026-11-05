class_name LoanCalculator
extends RefCounted
## Кредит и рассрочка: график платежей, переплата, эффективная ставка.
##
## Проценты начисляются помесячно на остаток долга (1/12 годовой ставки)
## с округлением до тиына. Эффективная ставка рассчитывается как IRR денежного
## потока с учётом комиссий — это приближение к ГЭСВ; банк считает ГЭСВ по
## точным датам платежей, поэтому значение может немного отличаться.

const TYPE_ANNUITY := "annuity"
const TYPE_DIFFERENTIATED := "differentiated"

const ERROR_NONE := ""
const ERROR_INVALID_AMOUNT := "invalid_amount"
const ERROR_INVALID_RATE := "invalid_rate"
const ERROR_INVALID_TERM := "invalid_term"
const ERROR_INVALID_FEE := "invalid_fee"
const ERROR_INVALID_DOWN_PAYMENT := "invalid_down_payment"


## Аннуитетный платёж: S × i / (1 − (1 + i)^−n), округлённый до тиына.
static func annuity_payment(principal_minor: int, rate_h: int, months: int) -> int:
	if principal_minor <= 0 or months <= 0:
		return 0
	if rate_h <= 0:
		return (principal_minor + months - 1) / months
	var i := FinanceMath.rate_fraction(rate_h) / 12.0
	var p := float(principal_minor) * i / (1.0 - pow(1.0 + i, -months))
	return roundi(p)


## График: [{"month", "payment", "principal", "interest", "balance"}].
static func schedule(principal_minor: int, rate_h: int, months: int, type: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var balance := principal_minor
	var annuity := annuity_payment(principal_minor, rate_h, months)
	var base_principal: int = principal_minor / months if months > 0 else 0
	for m in range(1, months + 1):
		var interest := FinanceMath.monthly_interest(balance, rate_h)
		var principal_part := 0
		if type == TYPE_DIFFERENTIATED:
			principal_part = base_principal
		else:
			principal_part = maxi(annuity - interest, 0)
		if m == months or principal_part > balance:
			principal_part = balance
		balance -= principal_part
		rows.append({
			"month": m,
			"payment": principal_part + interest,
			"principal": principal_part,
			"interest": interest,
			"balance": balance,
		})
	return rows


## Результат: ok, error, rows, first_payment, last_payment, max_payment,
## total_payments, total_interest, fee_minor, overpayment, effective_rate (% годовых, -1 — нет),
## balances (Array[int] — остаток долга, индекс 0 — старт).
static func calculate(principal_minor: int, rate_h: int, months: int, type: String = TYPE_ANNUITY,
		fee_minor: int = 0) -> Dictionary:
	var result := {"ok": false, "error": ERROR_NONE}
	if principal_minor <= 0 or principal_minor > Money.MAX_MINOR:
		result["error"] = ERROR_INVALID_AMOUNT
		return result
	if not FinanceMath.is_rate_valid(rate_h):
		result["error"] = ERROR_INVALID_RATE
		return result
	if not FinanceMath.is_term_valid(months):
		result["error"] = ERROR_INVALID_TERM
		return result
	if fee_minor < 0 or fee_minor >= principal_minor:
		result["error"] = ERROR_INVALID_FEE
		return result
	var rows := schedule(principal_minor, rate_h, months, type)
	_fill_totals(result, rows, principal_minor, fee_minor)
	var cashflows: Array = [principal_minor - fee_minor]
	for row in rows:
		cashflows.append(-int(row["payment"]))
	result["effective_rate"] = _effective(cashflows)
	result["ok"] = true
	return result


## Рассрочка: цена, первоначальный взнос, срок, комиссия/наценка магазина (% от цены)
## и скидка при оплате сразу (% от цены). Платежи равные, остаток от деления —
## в последнем платеже. Эффективная ставка считается относительно цены со скидкой.
## Дополнительно: commission_minor, financed_minor, total_paid, cash_price, overpayment_vs_cash.
static func installment(price_minor: int, down_payment_minor: int, months: int,
		commission_h: int = 0, cash_discount_h: int = 0) -> Dictionary:
	var result := {"ok": false, "error": ERROR_NONE}
	if price_minor <= 0 or price_minor > Money.MAX_MINOR:
		result["error"] = ERROR_INVALID_AMOUNT
		return result
	if down_payment_minor < 0 or down_payment_minor >= price_minor:
		result["error"] = ERROR_INVALID_DOWN_PAYMENT
		return result
	if not FinanceMath.is_term_valid(months):
		result["error"] = ERROR_INVALID_TERM
		return result
	if not FinanceMath.is_rate_valid(commission_h) or cash_discount_h < 0 or cash_discount_h >= 10_000:
		result["error"] = ERROR_INVALID_RATE
		return result
	var commission := FinanceMath.percent_of(price_minor, commission_h)
	var financed := price_minor - down_payment_minor + commission
	var base: int = financed / months
	var rows: Array[Dictionary] = []
	var balance := financed
	for m in range(1, months + 1):
		var payment := base if m < months else balance
		balance -= payment
		rows.append({"month": m, "payment": payment, "principal": payment, "interest": 0, "balance": balance})
	_fill_totals(result, rows, financed, 0)
	var cash_price := price_minor - FinanceMath.percent_of(price_minor, cash_discount_h)
	var total_paid := down_payment_minor + financed
	result["commission_minor"] = commission
	result["financed_minor"] = financed
	result["down_payment_minor"] = down_payment_minor
	result["total_paid"] = total_paid
	result["cash_price"] = cash_price
	result["overpayment_vs_cash"] = total_paid - cash_price
	# С точки зрения покупателя: получен товар стоимостью cash_price, сразу оплачен взнос.
	var cashflows: Array = [cash_price - down_payment_minor]
	for row in rows:
		cashflows.append(-int(row["payment"]))
	result["effective_rate"] = _effective(cashflows) if cash_price - down_payment_minor > 0 else -1.0
	result["ok"] = true
	return result


static func _fill_totals(result: Dictionary, rows: Array[Dictionary], principal_minor: int, fee_minor: int) -> void:
	var total := 0
	var interest := 0
	var max_payment := 0
	var balances: Array[int] = [principal_minor]
	for row in rows:
		total += int(row["payment"])
		interest += int(row["interest"])
		max_payment = maxi(max_payment, int(row["payment"]))
		balances.append(int(row["balance"]))
	result["rows"] = rows
	result["first_payment"] = int(rows[0]["payment"]) if not rows.is_empty() else 0
	result["last_payment"] = int(rows.back()["payment"]) if not rows.is_empty() else 0
	result["max_payment"] = max_payment
	result["total_payments"] = total
	result["total_interest"] = interest
	result["fee_minor"] = fee_minor
	result["overpayment"] = interest + fee_minor
	result["balances"] = balances


static func _effective(cashflows: Array) -> float:
	var irr := FinanceMath.irr_monthly(cashflows)
	if irr < 0.0:
		return -1.0
	return FinanceMath.annual_effective_percent(irr)
