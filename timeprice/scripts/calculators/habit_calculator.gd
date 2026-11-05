class_name HabitCalculator
extends RefCounted
## «Цена привычки»: регулярная мелкая трата за год, в рабочем времени и
## сколько накопилось бы, если откладывать эти деньги на депозит.

const PERIOD_DAY := "day"
const PERIOD_WEEK := "week"
const PERIOD_MONTH := "month"
const TIMES_PER_YEAR := {"day": 365, "week": 52, "month": 12}
const MAX_TIMES := 50
const MAX_YEARS := 40


## Результат: ok, yearly_minor, monthly_minor (среднее), total_minor (за years лет),
## invested_minor (с процентами на депозите при ежемесячном пополнении), interest_minor.
static func calculate(cost_minor: int, times: int, period: String, years: int, rate_h: int = 0) -> Dictionary:
	var result := {"ok": false}
	if cost_minor <= 0 or cost_minor > Money.MAX_MINOR / 1000 or times < 1 or times > MAX_TIMES \
			or not TIMES_PER_YEAR.has(period) or years < 1 or years > MAX_YEARS or not FinanceMath.is_rate_valid(rate_h):
		return result
	var yearly: int = cost_minor * times * int(TIMES_PER_YEAR[period])
	var monthly := Money.round_div(yearly, 12)
	result["yearly_minor"] = yearly
	result["monthly_minor"] = monthly
	result["total_minor"] = yearly * years
	var dep := DepositCalculator.calculate(0, monthly, rate_h, years * 12)
	result["invested_minor"] = int(dep["final_minor"]) if dep["ok"] else yearly * years
	result["interest_minor"] = int(dep["interest_minor"]) if dep["ok"] else 0
	result["ok"] = true
	return result
