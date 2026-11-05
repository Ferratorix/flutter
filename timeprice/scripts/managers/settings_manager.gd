extends Node
## Настройки приложения (ConfigFile): язык, анимации, вручную введённые курсы валют.

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
## Сейчас доступен только русский. Планируются: "kk", "uz", "en".
const SUPPORTED_LOCALES := ["ru"]

var locale: String = Loc.DEFAULT_LOCALE
var reduce_motion: bool = false
## "USD>KZT" -> курс × 10^FinancialCalculator.RATE_DIGITS
var exchange_rates: Dictionary = {}
## Последние значения в моделировании покупки (-1 — не указано).
var simulator_expenses_minor: int = -1
var simulator_monthly_savings_minor: int = -1


func _ready() -> void:
	load_settings()
	apply_locale()


func load_settings() -> void:
	_set_defaults()
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		push_warning("Файл настроек повреждён, восстановлены значения по умолчанию.")
		save_settings()
		return
	var loc_value: Variant = cfg.get_value("ui", "locale", Loc.DEFAULT_LOCALE)
	if typeof(loc_value) == TYPE_STRING and SUPPORTED_LOCALES.has(loc_value):
		locale = loc_value
	var motion: Variant = cfg.get_value("ui", "reduce_motion", false)
	if typeof(motion) == TYPE_BOOL:
		reduce_motion = motion
	var rates: Variant = cfg.get_value("finance", "exchange_rates", {})
	if typeof(rates) == TYPE_DICTIONARY:
		for key in rates:
			var v: Variant = rates[key]
			if typeof(key) == TYPE_STRING and typeof(v) == TYPE_INT \
					and v > 0 and v <= FinancialCalculator.MAX_RATE:
				exchange_rates[key] = v
	simulator_expenses_minor = _read_amount(cfg, "simulator", "expenses_minor")
	simulator_monthly_savings_minor = _read_amount(cfg, "simulator", "monthly_savings_minor")


func _read_amount(cfg: ConfigFile, section: String, key: String) -> int:
	var v: Variant = cfg.get_value(section, key, -1)
	if typeof(v) == TYPE_INT and v >= -1 and v <= Money.MAX_MINOR:
		return v
	return -1


func save_settings() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "locale", locale)
	cfg.set_value("ui", "reduce_motion", reduce_motion)
	cfg.set_value("finance", "exchange_rates", exchange_rates)
	cfg.set_value("simulator", "expenses_minor", simulator_expenses_minor)
	cfg.set_value("simulator", "monthly_savings_minor", simulator_monthly_savings_minor)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_error("Не удалось сохранить настройки: %s" % error_string(err))
		return false
	return true


func apply_locale() -> void:
	TranslationServer.set_locale(locale)


func set_reduce_motion(value: bool) -> void:
	if reduce_motion == value:
		return
	reduce_motion = value
	save_settings()
	settings_changed.emit()


## Курс из валюты from_code в to_code; 0, если не задан.
func get_rate(from_code: String, to_code: String) -> int:
	return int(exchange_rates.get(_rate_key(from_code, to_code), 0))


func set_rate(from_code: String, to_code: String, rate_scaled: int) -> void:
	if rate_scaled <= 0 or rate_scaled > FinancialCalculator.MAX_RATE:
		return
	var key := _rate_key(from_code, to_code)
	if int(exchange_rates.get(key, 0)) == rate_scaled:
		return
	exchange_rates[key] = rate_scaled
	save_settings()


func set_simulator_inputs(expenses_minor: int, monthly_savings_minor: int) -> void:
	var e := clampi(expenses_minor, -1, Money.MAX_MINOR)
	var m := clampi(monthly_savings_minor, -1, Money.MAX_MINOR)
	if e == simulator_expenses_minor and m == simulator_monthly_savings_minor:
		return
	simulator_expenses_minor = e
	simulator_monthly_savings_minor = m
	save_settings()


func reset() -> void:
	_set_defaults()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	apply_locale()
	settings_changed.emit()


func _set_defaults() -> void:
	locale = Loc.DEFAULT_LOCALE
	reduce_motion = false
	exchange_rates = {}
	simulator_expenses_minor = -1
	simulator_monthly_savings_minor = -1


func _rate_key(from_code: String, to_code: String) -> String:
	return from_code + ">" + to_code
