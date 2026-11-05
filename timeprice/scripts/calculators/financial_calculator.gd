class_name FinancialCalculator
extends RefCounted
## Вся математика TIMEPRICE.
##
## Денежные значения — int в минимальных единицах (см. Money).
## Продолжительность рабочего дня — int в минутах (8 ч = 480), чтобы точно
## поддерживать значения вроде 7,5 ч.
## Промежуточные результаты не округляются: целочисленные произведения
## вычисляются точно, деление выполняется один раз в конце.
##
## Формулы:
##   hourly_rate       = monthly_income / (working_days * working_hours)
##   purchase_hours    = purchase_price / hourly_rate
##   purchase_days     = purchase_hours / working_hours
##   income_percentage = purchase_price / monthly_income * 100

const MINUTES_PER_HOUR := 60
const MIN_WORKING_DAYS := 1
const MAX_WORKING_DAYS := 31
const MIN_WORK_MINUTES := 30
const MAX_WORK_MINUTES := 24 * 60
## Знаков после запятой в курсе валют: 1 USD = 512,3456 ₸ -> 5123456.
const RATE_DIGITS := 4
## Максимальный курс: 1 000 000 единиц за 1 единицу валюты.
const MAX_RATE := 1_000_000 * 10_000

## Коды ошибок calculate().
const ERROR_NONE := ""
const ERROR_INVALID_PROFILE := "invalid_profile"
const ERROR_INVALID_PRICE := "invalid_price"


static func is_schedule_valid(working_days: int, minutes_per_day: int) -> bool:
	return working_days >= MIN_WORKING_DAYS and working_days <= MAX_WORKING_DAYS \
		and minutes_per_day >= MIN_WORK_MINUTES and minutes_per_day <= MAX_WORK_MINUTES


static func is_income_valid(monthly_income_minor: int) -> bool:
	return monthly_income_minor > 0 and monthly_income_minor <= Money.MAX_MINOR


static func is_profile_valid(monthly_income_minor: int, working_days: int, minutes_per_day: int) -> bool:
	return is_income_valid(monthly_income_minor) and is_schedule_valid(working_days, minutes_per_day)


static func is_price_valid(price_minor: int) -> bool:
	return price_minor > 0 and price_minor <= Money.MAX_MINOR


## Рабочих минут в месяц. 0 при некорректном графике.
static func monthly_work_minutes(working_days: int, minutes_per_day: int) -> int:
	if not is_schedule_valid(working_days, minutes_per_day):
		return 0
	return working_days * minutes_per_day


## Рабочих часов в месяц (может быть дробным: 22 × 7,5 = 165).
static func monthly_work_hours(working_days: int, minutes_per_day: int) -> float:
	return float(monthly_work_minutes(working_days, minutes_per_day)) / MINUTES_PER_HOUR


## Стоимость рабочего часа в минимальных единицах без округления.
## 0.0 при некорректном профиле (деление на ноль исключено).
static func hourly_rate(monthly_income_minor: int, working_days: int, minutes_per_day: int) -> float:
	if not is_profile_valid(monthly_income_minor, working_days, minutes_per_day):
		return 0.0
	return float(monthly_income_minor * MINUTES_PER_HOUR) / float(working_days * minutes_per_day)


## Стоимость рабочего часа, округлённая до минимальной единицы (для отображения).
static func hourly_rate_rounded(monthly_income_minor: int, working_days: int, minutes_per_day: int) -> int:
	if not is_profile_valid(monthly_income_minor, working_days, minutes_per_day):
		return 0
	return Money.round_div(monthly_income_minor * MINUTES_PER_HOUR, working_days * minutes_per_day)


## Стоимость покупки в рабочих часах.
static func purchase_hours(price_minor: int, monthly_income_minor: int, working_days: int, minutes_per_day: int) -> float:
	if not is_price_valid(price_minor) or not is_profile_valid(monthly_income_minor, working_days, minutes_per_day):
		return 0.0
	# price * days * minutes <= 10^14 * 31 * 1440 < 2^63 — переполнения нет.
	return float(price_minor * working_days * minutes_per_day) / float(monthly_income_minor * MINUTES_PER_HOUR)


## Стоимость покупки в рабочих минутах, округлённая до целой минуты один раз.
static func purchase_minutes(price_minor: int, monthly_income_minor: int, working_days: int, minutes_per_day: int) -> int:
	if not is_price_valid(price_minor) or not is_profile_valid(monthly_income_minor, working_days, minutes_per_day):
		return 0
	return Money.round_div(price_minor * working_days * minutes_per_day, monthly_income_minor)


## Стоимость покупки в рабочих днях: purchase_hours / working_hours = price * days / income.
static func purchase_days(price_minor: int, monthly_income_minor: int, working_days: int) -> float:
	if not is_price_valid(price_minor) or not is_income_valid(monthly_income_minor):
		return 0.0
	if working_days < MIN_WORKING_DAYS or working_days > MAX_WORKING_DAYS:
		return 0.0
	return float(price_minor * working_days) / float(monthly_income_minor)


## Доля месячного дохода в процентах.
static func income_percentage(price_minor: int, monthly_income_minor: int) -> float:
	if price_minor < 0 or not is_income_valid(monthly_income_minor):
		return 0.0
	return float(price_minor) * 100.0 / float(monthly_income_minor)


## Доля накоплений в процентах. -1.0, если накоплений нет или они не указаны.
static func savings_percentage(price_minor: int, savings_minor: int) -> float:
	if price_minor < 0 or savings_minor <= 0:
		return -1.0
	return float(price_minor) * 100.0 / float(savings_minor)


## Пересчёт суммы по курсу rate_scaled (курс × 10^RATE_DIGITS) с округлением.
## -1 при некорректных данных или переполнении.
static func convert_amount(amount_minor: int, rate_scaled: int) -> int:
	if amount_minor < 0 or rate_scaled <= 0 or rate_scaled > MAX_RATE:
		return -1
	var factor := Money.pow10(RATE_DIGITS)
	var hi: int = amount_minor / factor
	var lo: int = amount_minor % factor
	if hi > 0 and hi > Money.MAX_MINOR / rate_scaled:
		return -1
	var result: int = hi * rate_scaled + Money.round_div(lo * rate_scaled, factor)
	if result > Money.MAX_MINOR:
		return -1
	return result


## Полный расчёт покупки. Возвращает словарь:
##   ok, error, price_minor, hourly_rate, hours, total_minutes, days,
##   full_days, remainder_minutes, income_percentage,
##   savings_percentage (-1.0 — нет данных), savings_left_minor (может быть < 0),
##   has_savings
static func calculate(price_minor: int, monthly_income_minor: int, working_days: int,
		minutes_per_day: int, savings_minor: int = -1) -> Dictionary:
	var result := {
		"ok": false,
		"error": ERROR_NONE,
		"price_minor": price_minor,
		"hourly_rate": 0.0,
		"hours": 0.0,
		"total_minutes": 0,
		"days": 0.0,
		"full_days": 0,
		"remainder_minutes": 0,
		"income_percentage": 0.0,
		"has_savings": savings_minor >= 0,
		"savings_percentage": -1.0,
		"savings_left_minor": 0,
	}
	if not is_profile_valid(monthly_income_minor, working_days, minutes_per_day):
		result["error"] = ERROR_INVALID_PROFILE
		return result
	if not is_price_valid(price_minor):
		result["error"] = ERROR_INVALID_PRICE
		return result
	var total_minutes := purchase_minutes(price_minor, monthly_income_minor, working_days, minutes_per_day)
	result["ok"] = true
	result["hourly_rate"] = hourly_rate(monthly_income_minor, working_days, minutes_per_day)
	result["hours"] = purchase_hours(price_minor, monthly_income_minor, working_days, minutes_per_day)
	result["total_minutes"] = total_minutes
	result["days"] = purchase_days(price_minor, monthly_income_minor, working_days)
	result["full_days"] = total_minutes / minutes_per_day
	result["remainder_minutes"] = total_minutes % minutes_per_day
	result["income_percentage"] = income_percentage(price_minor, monthly_income_minor)
	if savings_minor >= 0:
		result["savings_percentage"] = savings_percentage(price_minor, savings_minor)
		result["savings_left_minor"] = savings_minor - price_minor
	return result
