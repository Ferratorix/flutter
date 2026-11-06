class_name Currency
extends RefCounted
## Справочник поддерживаемых валют. Курсы не загружаются из сети —
## при расчёте в другой валюте пользователь указывает курс вручную.

const DEFAULT_CODE := "KZT"

const ORDER := ["KZT", "RUB", "UZS", "USD", "EUR"]

const DATA := {
	"KZT": {"symbol": "₸", "name": "Казахстанский тенге"},
	"RUB": {"symbol": "₽", "name": "Российский рубль"},
	"UZS": {"symbol": "сум", "name": "Узбекский сум"},
	"USD": {"symbol": "$", "name": "Доллар США"},
	"EUR": {"symbol": "€", "name": "Евро"},
}


static func is_supported(code: String) -> bool:
	return DATA.has(code)


static func symbol(code: String) -> String:
	if not DATA.has(code):
		return code
	return Loc.t(DATA[code]["symbol"])


static func display_name(code: String) -> String:
	if not DATA.has(code):
		return code
	return Loc.t(DATA[code]["name"])


## "₸ — Казахстанский тенге (KZT)"
static func long_label(code: String) -> String:
	return "%s — %s (%s)" % [symbol(code), display_name(code), code]
