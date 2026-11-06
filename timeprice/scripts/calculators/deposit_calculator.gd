class_name DepositCalculator
extends RefCounted
## Депозит: начальная сумма, ежемесячное пополнение, годовая ставка, срок.
##
## Модель: пополнение вносится в начале каждого месяца (включая первый),
## проценты начисляются в конце месяца на остаток с округлением до тиына.
## CAPITALIZATION_MONTHLY — проценты добавляются к вкладу каждый месяц;
## CAPITALIZATION_END — проценты не капитализируются и выплачиваются в конце срока.
## Банки обычно считают проценты по дням, поэтому реальный результат может
## немного отличаться. Налоги не учитываются.

const CAPITALIZATION_MONTHLY := "monthly"
const CAPITALIZATION_END := "end"

const ERROR_NONE := ""
const ERROR_INVALID_AMOUNT := "invalid_amount"
const ERROR_INVALID_RATE := "invalid_rate"
const ERROR_INVALID_TERM := "invalid_term"
const ERROR_OVERFLOW := "overflow"


## Результат: ok, error, final_minor, contributed_minor, interest_minor,
## balances (Array[int], индекс 0 — старт, далее — конец каждого месяца),
## contributions (Array[int] — внесено нарастающим итогом), effective_rate (% годовых).
static func calculate(initial_minor: int, monthly_minor: int, rate_h: int, term_months: int,
		capitalization: String = CAPITALIZATION_MONTHLY) -> Dictionary:
	var result := {
		"ok": false, "error": ERROR_NONE,
		"final_minor": 0, "contributed_minor": 0, "interest_minor": 0,
		"balances": [], "contributions": [], "effective_rate": 0.0,
	}
	if initial_minor < 0 or monthly_minor < 0 or initial_minor + monthly_minor <= 0 \
			or initial_minor > Money.MAX_MINOR or monthly_minor > Money.MAX_MINOR:
		result["error"] = ERROR_INVALID_AMOUNT
		return result
	if not FinanceMath.is_rate_valid(rate_h):
		result["error"] = ERROR_INVALID_RATE
		return result
	if not FinanceMath.is_term_valid(term_months):
		result["error"] = ERROR_INVALID_TERM
		return result

	var monthly_cap := capitalization != CAPITALIZATION_END
	var balance := initial_minor
	var accrued := 0
	var contributed := initial_minor
	var balances: Array[int] = [initial_minor]
	var contributions: Array[int] = [initial_minor]
	for m in range(1, term_months + 1):
		balance += monthly_minor
		contributed += monthly_minor
		var interest := FinanceMath.monthly_interest(balance, rate_h)
		if monthly_cap:
			balance += interest
		else:
			accrued += interest
		if balance + accrued > Money.MAX_MINOR:
			result["error"] = ERROR_OVERFLOW
			return result
		balances.append(balance + accrued)
		contributions.append(contributed)

	var final_balance := balance + accrued
	result["ok"] = true
	result["final_minor"] = final_balance
	result["contributed_minor"] = contributed
	result["interest_minor"] = final_balance - contributed
	result["balances"] = balances
	result["contributions"] = contributions
	result["effective_rate"] = effective_rate(rate_h, capitalization)
	return result


## Эффективная годовая доходность в процентах.
static func effective_rate(rate_h: int, capitalization: String) -> float:
	if capitalization == CAPITALIZATION_END:
		return rate_h / 100.0
	return (pow(1.0 + FinanceMath.rate_fraction(rate_h) / 12.0, 12.0) - 1.0) * 100.0


## Через сколько месяцев накопится target_minor (ежемесячная капитализация).
## 0 — уже накоплено; -1 — не накопится за FinanceMath.MAX_TERM_MONTHS.
static func months_to_target(initial_minor: int, monthly_minor: int, rate_h: int, target_minor: int) -> int:
	if target_minor <= 0 or initial_minor >= target_minor:
		return 0
	if initial_minor < 0 or monthly_minor < 0 or not FinanceMath.is_rate_valid(rate_h):
		return -1
	var balance := initial_minor
	for m in range(1, FinanceMath.MAX_TERM_MONTHS + 1):
		balance += monthly_minor
		balance += FinanceMath.monthly_interest(balance, rate_h)
		if balance >= target_minor:
			return m
		if balance <= 0:
			return -1
	return -1


## Покупательная способность суммы через months месяцев при годовой инфляции.
static func real_value(amount_minor: int, inflation_h: int, months: int) -> int:
	if inflation_h <= 0 or months <= 0:
		return amount_minor
	var factor := pow(1.0 + FinanceMath.rate_fraction(inflation_h), months / 12.0)
	return roundi(float(amount_minor) / factor)
