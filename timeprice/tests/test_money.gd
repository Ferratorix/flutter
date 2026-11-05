extends TestCase


func test_parse_integer_amounts() -> void:
	assert_eq(Money.parse("400000"), 40_000_000)
	assert_eq(Money.parse("400 000"), 40_000_000)
	assert_eq(Money.parse("400 000"), 40_000_000)
	assert_eq(Money.parse("  1 250  "), 125_000)
	assert_eq(Money.parse("0"), 0)
	assert_eq(Money.parse("007"), 700)


func test_parse_fraction() -> void:
	assert_eq(Money.parse("99,99"), 9_999)
	assert_eq(Money.parse("99.99"), 9_999)
	assert_eq(Money.parse("10,5"), 1_050)
	assert_eq(Money.parse(",5"), 50)
	assert_eq(Money.parse("10,"), 1_000)
	assert_eq(Money.parse("10,500"), 1_050, "лишние нули после запятой допустимы")


func test_parse_rejects_invalid() -> void:
	assert_eq(Money.parse(""), Money.INVALID)
	assert_eq(Money.parse("   "), Money.INVALID)
	assert_eq(Money.parse("abc"), Money.INVALID)
	assert_eq(Money.parse("-100"), Money.INVALID)
	assert_eq(Money.parse("+100"), Money.INVALID)
	assert_eq(Money.parse("1,2,3"), Money.INVALID)
	assert_eq(Money.parse("10,555"), Money.INVALID, "больше двух значащих знаков после запятой")
	assert_eq(Money.parse("1e5"), Money.INVALID)
	assert_eq(Money.parse("."), Money.INVALID)


func test_parse_limits() -> void:
	assert_eq(Money.parse("1000000000000"), Money.MAX_MINOR, "10^12 — максимум")
	assert_eq(Money.parse("1000000000000,01"), Money.INVALID)
	assert_eq(Money.parse("99999999999999999999"), Money.INVALID, "переполнение int64 исключено")


func test_parse_rate_with_four_digits() -> void:
	assert_eq(Money.parse("512,3456", 4, FinancialCalculator.MAX_RATE), 5_123_456)
	assert_eq(Money.parse("0,0001", 4, FinancialCalculator.MAX_RATE), 1)


func test_format_number() -> void:
	assert_eq(Money.format_number(40_000_000), "400 000")
	assert_eq(Money.format_number(9_999), "99,99")
	assert_eq(Money.format_number(1_050), "10,50")
	assert_eq(Money.format_number(0), "0")
	assert_eq(Money.format_number(12_345_678_900), "123 456 789")
	assert_eq(Money.format_number(-150_000), "−1 500")


func test_format_parse_roundtrip() -> void:
	for value in [0, 1, 99, 100, 12_345, 40_000_000, 35_000_050, Money.MAX_MINOR]:
		assert_eq(Money.parse(Money.to_input_text(value)), value, "значение %d" % value)


func test_round_div() -> void:
	assert_eq(Money.round_div(10, 4), 3, "2,5 -> 3")
	assert_eq(Money.round_div(9, 4), 2, "2,25 -> 2")
	assert_eq(Money.round_div(-10, 4), -3)
	assert_eq(Money.round_div(7, 0), 0, "деление на ноль безопасно")
