class_name FinanceMath
extends RefCounted
## Общая финансовая математика: проценты, эффективная ставка (IRR).
##
## Ставки хранятся как int в сотых долях процента: 16,5 % -> 1650.
## Проценты за месяц: сумма × ставка / (100 × 100 × 12) с округлением
## до минимальной денежной единицы — так банки начисляют проценты по периодам.

const RATE_DIGITS := 2
## 200 % годовых — верхняя граница для всех калькуляторов.
const MAX_RATE := 20_000
## Делитель для месячных процентов: 100 (проценты) × 100 (сотые доли) × 12 (месяцев).
const MONTHLY_DIVISOR := 120_000
const MAX_TERM_MONTHS := 600


static func is_rate_valid(rate_h: int) -> bool:
	return rate_h >= 0 and rate_h <= MAX_RATE


static func is_term_valid(months: int) -> bool:
	return months >= 1 and months <= MAX_TERM_MONTHS


## Проценты за один месяц по годовой ставке (сотые доли процента).
static func monthly_interest(balance_minor: int, rate_h: int) -> int:
	if balance_minor <= 0 or rate_h <= 0:
		return 0
	return Money.round_div(balance_minor * rate_h, MONTHLY_DIVISOR)


## Доля от суммы в сотых долях процента: 10 % (1000) от 50 000 -> 5 000.
static func percent_of(amount_minor: int, rate_h: int) -> int:
	if amount_minor <= 0 or rate_h <= 0:
		return 0
	return Money.round_div(amount_minor * rate_h, 10_000)


## Ставка как дробь в год: 1650 -> 0.165.
static func rate_fraction(rate_h: int) -> float:
	return rate_h / 10_000.0


## Чистая приведённая стоимость денежного потока при месячной ставке r.
static func npv(cashflows: Array, monthly_rate: float) -> float:
	var total := 0.0
	var factor := 1.0
	for cf in cashflows:
		total += float(cf) / factor
		factor *= 1.0 + monthly_rate
	return total


## Внутренняя норма доходности (месячная) методом деления пополам.
## Поток: cashflows[0] — полученная сумма (> 0), далее — платежи (< 0).
## 0.0 — переплаты нет; -1.0 — не удалось найти.
static func irr_monthly(cashflows: Array) -> float:
	if cashflows.size() < 2:
		return -1.0
	if npv(cashflows, 0.0) >= 0.0:
		return 0.0
	var lo := 0.0
	var hi := 1.0
	if npv(cashflows, hi) < 0.0:
		return -1.0
	for i in 200:
		var mid := (lo + hi) / 2.0
		if npv(cashflows, mid) < 0.0:
			lo = mid
		else:
			hi = mid
		if hi - lo < 1e-12:
			break
	return (lo + hi) / 2.0


## Эффективная годовая ставка в процентах по месячной: (1 + r)^12 − 1.
static func annual_effective_percent(monthly_rate: float) -> float:
	if monthly_rate < 0.0:
		return -1.0
	return (pow(1.0 + monthly_rate, 12.0) - 1.0) * 100.0
