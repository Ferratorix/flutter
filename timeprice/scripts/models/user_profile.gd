class_name UserProfile
extends RefCounted
## Профиль пользователя: доход, рабочий график, валюта и накопления.

const DEFAULT_WORKING_DAYS := 22
const DEFAULT_WORK_MINUTES := 8 * 60
## Значение savings_minor, если пользователь не указал накопления.
const SAVINGS_NOT_SET := -1

var monthly_income_minor: int = 0
var working_days: int = DEFAULT_WORKING_DAYS
var work_minutes_per_day: int = DEFAULT_WORK_MINUTES
var currency: String = Currency.DEFAULT_CODE
var savings_minor: int = SAVINGS_NOT_SET
var onboarding_completed: bool = false
var created_at: int = 0
var updated_at: int = 0


func is_valid() -> bool:
	return Currency.is_supported(currency) and FinancialCalculator.is_profile_valid(
		monthly_income_minor, working_days, work_minutes_per_day)


## Профиль готов к работе: onboarding пройден и данные корректны.
func is_ready() -> bool:
	return onboarding_completed and is_valid()


func has_savings() -> bool:
	return savings_minor >= 0


func hourly_rate() -> float:
	return FinancialCalculator.hourly_rate(monthly_income_minor, working_days, work_minutes_per_day)


func calculate(price_minor: int) -> Dictionary:
	return FinancialCalculator.calculate(price_minor, monthly_income_minor, working_days,
		work_minutes_per_day, savings_minor)


func copy() -> UserProfile:
	return UserProfile.from_dict(to_dict())


## Совпадают ли пользовательские параметры (без служебных дат).
func same_settings_as(other: UserProfile) -> bool:
	return other != null and monthly_income_minor == other.monthly_income_minor \
		and working_days == other.working_days \
		and work_minutes_per_day == other.work_minutes_per_day \
		and currency == other.currency and savings_minor == other.savings_minor


func to_dict() -> Dictionary:
	return {
		"monthly_income_minor": monthly_income_minor,
		"working_days": working_days,
		"work_minutes_per_day": work_minutes_per_day,
		"currency": currency,
		"savings_minor": savings_minor,
		"onboarding_completed": onboarding_completed,
		"created_at": created_at,
		"updated_at": updated_at,
	}


## Восстановление из словаря. Некорректные поля заменяются значениями по умолчанию.
static func from_dict(data: Dictionary) -> UserProfile:
	var p := UserProfile.new()
	p.monthly_income_minor = DataUtil.get_int(data, "monthly_income_minor", 0, 0, Money.MAX_MINOR)
	p.working_days = DataUtil.get_int(data, "working_days", DEFAULT_WORKING_DAYS,
		FinancialCalculator.MIN_WORKING_DAYS, FinancialCalculator.MAX_WORKING_DAYS)
	p.work_minutes_per_day = DataUtil.get_int(data, "work_minutes_per_day", DEFAULT_WORK_MINUTES,
		FinancialCalculator.MIN_WORK_MINUTES, FinancialCalculator.MAX_WORK_MINUTES)
	var code := DataUtil.get_string(data, "currency", Currency.DEFAULT_CODE, 8)
	p.currency = code if Currency.is_supported(code) else Currency.DEFAULT_CODE
	p.savings_minor = DataUtil.get_int(data, "savings_minor", SAVINGS_NOT_SET, SAVINGS_NOT_SET, Money.MAX_MINOR)
	p.onboarding_completed = DataUtil.get_bool(data, "onboarding_completed", false)
	p.created_at = DataUtil.get_int(data, "created_at", 0, 0, 1 << 40)
	p.updated_at = DataUtil.get_int(data, "updated_at", 0, 0, 1 << 40)
	# Повреждённый доход не позволяет пользоваться профилем — потребуется повторная настройка.
	if not p.is_valid():
		p.onboarding_completed = false
	return p
