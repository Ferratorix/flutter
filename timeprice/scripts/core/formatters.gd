class_name Fmt
extends RefCounted
## Форматирование чисел, сумм, длительностей и дат для интерфейса.
## Округление выполняется только здесь — на этапе отображения.

const NBSP := " "

const MONTHS_NOMINATIVE := ["январь", "февраль", "март", "апрель", "май", "июнь",
	"июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"]

const MONTHS_SHORT := ["янв.", "февр.", "марта", "апр.", "мая", "июня",
	"июля", "авг.", "сент.", "окт.", "нояб.", "дек."]


## "350 000 ₸"
static func money(minor: int, currency_code: String) -> String:
	return Money.format_number(minor) + NBSP + Currency.symbol(currency_code)


## Сумма, округлённая до целых при значениях от 1000 (для стоимости часа).
static func money_compact(minor_value: float, currency_code: String) -> String:
	var minor: int = roundi(minor_value)
	if absi(minor) >= 1000 * Money.MINOR_FACTOR:
		minor = Money.round_div(minor, Money.MINOR_FACTOR) * Money.MINOR_FACTOR
	return money(minor, currency_code)


## Число с не более чем digits знаками после запятой: 22.625 -> "22,6".
static func decimal(value: float, digits: int = 1) -> String:
	if not is_finite(value):
		return "—"
	var factor := Money.pow10(digits)
	var scaled: int = roundi(absf(value) * factor)
	var whole: int = scaled / factor
	var frac: int = scaled % factor
	var s := Money.group_digits(str(whole))
	if digits > 0 and frac != 0:
		var frac_str := str(frac).pad_zeros(digits)
		while frac_str.ends_with("0"):
			frac_str = frac_str.substr(0, frac_str.length() - 1)
		s += "," + frac_str
	if value < 0.0 and scaled != 0:
		s = "−" + s
	return s


## Длительность в рабочих минутах: "181 ч 10 мин", "45 мин".
static func duration(total_minutes: int) -> String:
	if total_minutes <= 0:
		return Loc.t("меньше минуты")
	var hours: int = total_minutes / 60
	var minutes: int = total_minutes % 60
	if hours == 0:
		return Loc.tf("%s мин", [minutes])
	if minutes == 0 or hours >= 1000:
		return Loc.tf("%s ч", [Money.group_digits(str(hours))])
	return Loc.tf("%s ч %s мин", [Money.group_digits(str(hours)), minutes])


## Длительность рабочего дня: 480 -> "8 ч", 450 -> "7,5 ч".
static func hours_from_minutes(minutes: int) -> String:
	return Loc.tf("%s ч", [decimal(minutes / 60.0, 2)])


## "22,6 рабочего дня", "5 рабочих дней".
static func work_days(days: float) -> String:
	var text := decimal(days, 1)
	var rounded := roundf(days * 10.0) / 10.0
	if is_equal_approx(rounded, roundf(rounded)):
		return text + " " + Loc.plural(int(roundf(rounded)), ["рабочий день", "рабочих дня", "рабочих дней"])
	return text + " " + Loc.t("рабочего дня")


## "22 рабочих дня" для целых значений.
static func days_count(days: int) -> String:
	return str(days) + " " + Loc.plural(days, ["день", "дня", "дней"])


## "87,5 %"; очень малые значения — "< 0,1 %".
static func percent(value: float) -> String:
	if value > 0.0 and value < 0.05:
		return "<" + NBSP + "0,1" + NBSP + "%"
	return decimal(value, 1) + NBSP + "%"


## Разбивка на полные рабочие дни: "19 полных рабочих дней и 2 ч".
static func full_days_breakdown(full_days: int, remainder_minutes: int) -> String:
	if full_days <= 0:
		return Loc.t("Меньше одного рабочего дня")
	var days_text := str(full_days) + " " + Loc.plural(full_days,
		["полный рабочий день", "полных рабочих дня", "полных рабочих дней"])
	if remainder_minutes <= 0:
		return days_text
	return Loc.tf("%s и ещё %s", [days_text, duration(remainder_minutes)])


## Дата и время в часовом поясе устройства: "5 нояб. 2026, 16:05".
static func date_time(unix_time: int) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var d := Time.get_datetime_dict_from_unix_time(unix_time + bias * 60)
	var month_index: int = clampi(int(d["month"]) - 1, 0, 11)
	return "%d %s %d, %02d:%02d" % [d["day"], Loc.t(MONTHS_SHORT[month_index]), d["year"], d["hour"], d["minute"]]


## Срок в месяцах: "1 год 3 месяца", "5 месяцев".
static func months_duration(months: int) -> String:
	if months <= 0:
		return Loc.t("меньше месяца")
	var years: int = months / 12
	var rest: int = months % 12
	var parts := PackedStringArray()
	if years > 0:
		parts.append(str(years) + " " + Loc.plural(years, ["год", "года", "лет"]))
	if rest > 0:
		parts.append(str(rest) + " " + Loc.plural(rest, ["месяц", "месяца", "месяцев"]))
	return " ".join(parts)


## "март 2027"
static func month_year(year: int, month: int) -> String:
	return "%s %d" % [Loc.t(MONTHS_NOMINATIVE[clampi(month - 1, 0, 11)]), year]


## Месяц и год через months месяцев от текущей даты устройства.
static func month_year_from_now(months: int) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var d := Time.get_datetime_dict_from_unix_time(DataUtil.now() + bias * 60)
	var ym := FinancialCalculator.add_months(int(d["year"]), int(d["month"]), months)
	return month_year(ym.x, ym.y)


## Короткая дата: "5 нояб. 2026".
static func date(unix_time: int) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var d := Time.get_datetime_dict_from_unix_time(unix_time + bias * 60)
	return "%d %s %d" % [d["day"], Loc.t(MONTHS_SHORT[clampi(int(d["month"]) - 1, 0, 11)]), d["year"]]


## Краткая запись суммы для осей графиков: "350 тыс.", "1,2 млн", "−40 тыс.".
static func compact_amount(minor: int) -> String:
	var major := absf(float(minor)) / Money.MINOR_FACTOR
	var text := ""
	if major >= 1_000_000_000.0:
		text = decimal(major / 1_000_000_000.0, 1) + NBSP + Loc.t("млрд")
	elif major >= 1_000_000.0:
		text = decimal(major / 1_000_000.0, 1) + NBSP + Loc.t("млн")
	elif major >= 1_000.0:
		text = decimal(major / 1_000.0, 0) + NBSP + Loc.t("тыс.")
	else:
		text = decimal(major, 0)
	return ("−" + text) if minor < 0 and text != "0" else text
