extends TestCase

const NB := " "


func test_money() -> void:
	assert_eq(Fmt.money(40_000_000, "KZT"), "400" + NB + "000" + NB + "₸")
	assert_eq(Fmt.money(9_999, "USD"), "99,99" + NB + "$")


func test_money_compact_rounds_large_values() -> void:
	assert_eq(Fmt.money_compact(227_272.73, "KZT"), "2" + NB + "273" + NB + "₸")
	assert_eq(Fmt.money_compact(12_345.6, "USD"), "123,46" + NB + "$")


func test_decimal() -> void:
	assert_eq(Fmt.decimal(19.25, 1), "19,3")
	assert_eq(Fmt.decimal(154.0, 1), "154")
	assert_eq(Fmt.decimal(1234.5, 1), "1" + NB + "234,5")
	assert_eq(Fmt.decimal(0.04, 1), "0")
	assert_eq(Fmt.decimal(7.5, 2), "7,5")


func test_duration() -> void:
	assert_eq(Fmt.duration(0), "меньше минуты")
	assert_eq(Fmt.duration(45), "45 мин")
	assert_eq(Fmt.duration(120), "2 ч")
	assert_eq(Fmt.duration(9_250), "154 ч 10 мин")
	assert_eq(Fmt.duration(1_000 * 60 + 5), "1" + NB + "000 ч")


func test_work_days_plural() -> void:
	assert_eq(Fmt.work_days(1.0), "1 рабочий день")
	assert_eq(Fmt.work_days(3.0), "3 рабочих дня")
	assert_eq(Fmt.work_days(5.0), "5 рабочих дней")
	assert_eq(Fmt.work_days(11.0), "11 рабочих дней")
	assert_eq(Fmt.work_days(19.25), "19,3 рабочего дня")


func test_plural_ru() -> void:
	assert_eq(Loc.plural_index_ru(1), 0)
	assert_eq(Loc.plural_index_ru(21), 0)
	assert_eq(Loc.plural_index_ru(2), 1)
	assert_eq(Loc.plural_index_ru(24), 1)
	assert_eq(Loc.plural_index_ru(12), 2)
	assert_eq(Loc.plural_index_ru(111), 2)
	assert_eq(Loc.plural_index_ru(0), 2)


func test_percent() -> void:
	assert_eq(Fmt.percent(87.5), "87,5" + NB + "%")
	assert_eq(Fmt.percent(0.01), "<" + NB + "0,1" + NB + "%")
	assert_eq(Fmt.percent(0.0), "0" + NB + "%")


func test_full_days_breakdown() -> void:
	assert_eq(Fmt.full_days_breakdown(19, 120), "19 полных рабочих дней и ещё 2 ч")
	assert_eq(Fmt.full_days_breakdown(1, 0), "1 полный рабочий день")
	assert_eq(Fmt.full_days_breakdown(0, 30), "Меньше одного рабочего дня")
