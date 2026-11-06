class_name Purchase
extends RefCounted
## Сохранённый расчёт покупки (запись истории).
##
## Хранит исходные данные и снимок профиля на момент расчёта, поэтому
## результат в истории не меняется, если пользователь позже изменит доход.

const MAX_TITLE_LENGTH := 80

var id: String = ""
var title: String = ""
## Цена в валюте покупки.
var price_minor: int = 0
var currency: String = Currency.DEFAULT_CODE
## Курс (× 10^RATE_DIGITS) к валюте профиля; 0 — валюты совпадают.
var rate_scaled: int = 0
## Цена в валюте профиля.
var base_price_minor: int = 0
var base_currency: String = Currency.DEFAULT_CODE
# Снимок профиля.
var income_minor: int = 0
var working_days: int = UserProfile.DEFAULT_WORKING_DAYS
var work_minutes_per_day: int = UserProfile.DEFAULT_WORK_MINUTES
var savings_minor: int = UserProfile.SAVINGS_NOT_SET
var created_at: int = 0


static func create(p_title: String, p_price_minor: int, p_currency: String, p_rate_scaled: int,
		p_base_price_minor: int, profile: UserProfile) -> Purchase:
	var item := Purchase.new()
	item.id = DataUtil.new_id()
	item.title = p_title.strip_edges().substr(0, MAX_TITLE_LENGTH)
	item.price_minor = p_price_minor
	item.currency = p_currency
	item.rate_scaled = p_rate_scaled
	item.base_price_minor = p_base_price_minor
	item.base_currency = profile.currency
	item.income_minor = profile.monthly_income_minor
	item.working_days = profile.working_days
	item.work_minutes_per_day = profile.work_minutes_per_day
	item.savings_minor = profile.savings_minor
	item.created_at = DataUtil.now()
	return item


func is_valid() -> bool:
	return not id.is_empty() and FinancialCalculator.is_price_valid(base_price_minor) \
		and FinancialCalculator.is_profile_valid(income_minor, working_days, work_minutes_per_day)


func is_converted() -> bool:
	return currency != base_currency


func display_title() -> String:
	return title if not title.is_empty() else Loc.t("Покупка без названия")


func result() -> Dictionary:
	return FinancialCalculator.calculate(base_price_minor, income_minor, working_days,
		work_minutes_per_day, savings_minor)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"price_minor": price_minor,
		"currency": currency,
		"rate_scaled": rate_scaled,
		"base_price_minor": base_price_minor,
		"base_currency": base_currency,
		"income_minor": income_minor,
		"working_days": working_days,
		"work_minutes_per_day": work_minutes_per_day,
		"savings_minor": savings_minor,
		"created_at": created_at,
	}


## Возвращает null, если запись повреждена.
static func from_dict(data: Dictionary) -> Purchase:
	var item := Purchase.new()
	item.id = DataUtil.get_string(data, "id", "", 64)
	item.title = DataUtil.get_string(data, "title", "", MAX_TITLE_LENGTH)
	item.price_minor = DataUtil.get_int(data, "price_minor", 0, 0, Money.MAX_MINOR)
	var code := DataUtil.get_string(data, "currency", Currency.DEFAULT_CODE, 8)
	item.currency = code if Currency.is_supported(code) else Currency.DEFAULT_CODE
	item.rate_scaled = DataUtil.get_int(data, "rate_scaled", 0, 0, FinancialCalculator.MAX_RATE)
	item.base_price_minor = DataUtil.get_int(data, "base_price_minor", 0, 0, Money.MAX_MINOR)
	var base := DataUtil.get_string(data, "base_currency", Currency.DEFAULT_CODE, 8)
	item.base_currency = base if Currency.is_supported(base) else Currency.DEFAULT_CODE
	item.income_minor = DataUtil.get_int(data, "income_minor", 0, 0, Money.MAX_MINOR)
	item.working_days = DataUtil.get_int(data, "working_days", 0, 0, FinancialCalculator.MAX_WORKING_DAYS)
	item.work_minutes_per_day = DataUtil.get_int(data, "work_minutes_per_day", 0, 0, FinancialCalculator.MAX_WORK_MINUTES)
	item.savings_minor = DataUtil.get_int(data, "savings_minor", UserProfile.SAVINGS_NOT_SET,
		UserProfile.SAVINGS_NOT_SET, Money.MAX_MINOR)
	item.created_at = DataUtil.get_int(data, "created_at", 0, 0, 1 << 40)
	return item if item.is_valid() else null
