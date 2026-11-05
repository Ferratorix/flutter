class_name Money
extends RefCounted
## Денежные суммы в минимальных единицах (тиын, копейка, цент).
##
## Все суммы в приложении хранятся как int: 350 000,00 ₸ -> 35 000 000.
## Это исключает ошибки округления Float при сложении и сравнении сумм.

## Количество знаков после запятой для всех поддерживаемых валют.
const MINOR_DIGITS := 2
const MINOR_FACTOR := 100
## Верхняя граница: 10^12 основных единиц (10^14 минимальных).
## Гарантирует отсутствие переполнения int64 в расчётах FinancialCalculator.
const MAX_MINOR := 100_000_000_000_000
## Возвращается parse() при некорректном вводе.
const INVALID := -1

const _SPACES := [" ", " ", " ", " ", "_", "'"]


## Преобразует пользовательский ввод ("350 000", "1250,5", "99.99") в целое число
## минимальных единиц с заданным количеством дробных знаков.
## Возвращает INVALID для пустой строки, букв, отрицательных чисел и переполнения.
static func parse(text: String, fraction_digits: int = MINOR_DIGITS, max_value: int = MAX_MINOR) -> int:
	var s := normalize_input(text)
	if s.is_empty():
		return INVALID
	var parts := s.split(".", true)
	if parts.size() > 2:
		return INVALID
	var int_part: String = parts[0]
	var frac_part: String = parts[1] if parts.size() == 2 else ""
	if int_part.is_empty() and frac_part.is_empty():
		return INVALID
	if not _is_digits(int_part) or not _is_digits(frac_part):
		return INVALID
	int_part = int_part.lstrip("0")
	# Ограничение длины исключает переполнение int64 при умножении на 10^digits.
	if int_part.length() > 18 - fraction_digits:
		return INVALID
	if frac_part.length() > fraction_digits:
		# Лишние дробные знаки допустимы, только если это нули ("10,500" при 2 знаках).
		if not frac_part.substr(fraction_digits).replace("0", "").is_empty():
			return INVALID
		frac_part = frac_part.substr(0, fraction_digits)
	frac_part = frac_part.rpad(fraction_digits, "0")
	var whole: int = int_part.to_int() if not int_part.is_empty() else 0
	var frac: int = frac_part.to_int() if not frac_part.is_empty() else 0
	var result: int = whole * pow10(fraction_digits) + frac
	if result < 0 or result > max_value:
		return INVALID
	return result


## Убирает пробелы-разделители и приводит десятичную запятую к точке.
static func normalize_input(text: String) -> String:
	var s := text.strip_edges()
	for sp in _SPACES:
		s = s.replace(sp, "")
	return s.replace(",", ".")


## Форматирует сумму с разделением разрядов: 35000050 -> "350 000,50".
## Нулевая дробная часть не выводится (35000000 -> "350 000"), если не задан force_fraction.
static func format_number(minor: int, fraction_digits: int = MINOR_DIGITS, force_fraction: bool = false) -> String:
	var negative := minor < 0
	var a: int = absi(minor)
	var factor := pow10(fraction_digits)
	var whole: int = a / factor
	var frac: int = a % factor
	var s := group_digits(str(whole))
	if fraction_digits > 0 and (frac != 0 or force_fraction):
		s += "," + str(frac).pad_zeros(fraction_digits)
	return ("−" + s) if negative else s


## Значение для поля ввода (без неразрывных пробелов, удобно редактировать).
static func to_input_text(minor: int, fraction_digits: int = MINOR_DIGITS) -> String:
	return format_number(minor, fraction_digits).replace(" ", " ")


## Группирует цифры по три неразрывными пробелами: "1234567" -> "1 234 567".
static func group_digits(digits: String) -> String:
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = " " + out
		out = digits[i] + out
		count += 1
	return out


## Целочисленное деление с округлением половины от нуля (банковское не используется).
static func round_div(numerator: int, denominator: int) -> int:
	if denominator == 0:
		return 0
	var negative := (numerator < 0) != (denominator < 0)
	var n: int = absi(numerator)
	var d: int = absi(denominator)
	var q: int = n / d
	if (n % d) * 2 >= d:
		q += 1
	return -q if negative else q


static func pow10(n: int) -> int:
	var r := 1
	for i in n:
		r *= 10
	return r


static func _is_digits(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c < 48 or c > 57:
			return false
	return true
