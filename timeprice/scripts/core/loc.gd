class_name Loc
extends RefCounted
## Точка входа для локализации.
##
## Исходные строки интерфейса написаны на русском и служат ключами
## для TranslationServer. Пока перевод не загружен, translate() возвращает
## исходную русскую строку. Чтобы добавить язык (kk, uz, en), достаточно
## подключить файл перевода (CSV или PO) в data/translations и
## зарегистрировать локаль в SettingsManager.SUPPORTED_LOCALES.

const DEFAULT_LOCALE := "ru"


static func t(message: String) -> String:
	return String(TranslationServer.translate(message))


## Перевод шаблона и подстановка аргументов: Loc.tf("%s ч", [12]).
static func tf(template: String, args: Array) -> String:
	return t(template) % args


## Выбор формы множественного числа для текущей локали.
## forms для русского: [одна, несколько, много] — ["день", "дня", "дней"].
static func plural(n: int, forms: Array) -> String:
	var locale := TranslationServer.get_locale().substr(0, 2)
	var index := 0
	match locale:
		"ru", "uk", "be":
			index = plural_index_ru(n)
		_:
			index = 0 if absi(n) == 1 else mini(1, forms.size() - 1)
	index = clampi(index, 0, forms.size() - 1)
	return t(forms[index])


static func plural_index_ru(n: int) -> int:
	var a := absi(n)
	var mod10 := a % 10
	var mod100 := a % 100
	if mod10 == 1 and mod100 != 11:
		return 0
	if mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14):
		return 1
	return 2
