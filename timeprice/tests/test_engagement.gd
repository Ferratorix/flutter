extends TestCase
## Пауза перед покупкой, копилка решений, цена привычки, кэшбэк, советы, рекомендации.

const NOW := 1_800_000_000
const DAY := 86_400


func _profile() -> UserProfile:
	var p := UserProfile.new()
	p.monthly_income_minor = 40_000_000
	p.onboarding_completed = true
	return p


func test_cooldown_lifecycle() -> void:
	var w := WishlistItem.create("Наушники", 6_500_000, "KZT")
	w.start_cooldown(3, NOW)
	assert_true(w.has_cooldown())
	assert_true(w.is_cooling(NOW + DAY))
	assert_eq(w.cooldown_days_left(NOW + DAY), 2)
	assert_eq(w.cooldown_days_left(NOW + 1), 3, "неполный день считается вверх")
	assert_false(w.is_decision_due(NOW + DAY))
	assert_true(w.is_decision_due(NOW + 3 * DAY))
	w.resolve(WishlistItem.STATUS_DECLINED, NOW + 3 * DAY)
	assert_false(w.is_active())
	assert_false(w.is_decision_due(NOW + 4 * DAY), "после решения вопрос не задаётся")
	assert_eq(w.resolved_at, NOW + 3 * DAY)
	w.resolve(WishlistItem.STATUS_ACTIVE, NOW + 5 * DAY)
	assert_true(w.is_active())
	assert_false(w.has_cooldown())


func test_no_cooldown() -> void:
	var w := WishlistItem.create("Книга", 500_000, "KZT")
	w.start_cooldown(0, NOW)
	assert_false(w.has_cooldown())
	assert_false(w.is_decision_due(NOW))


func test_status_roundtrip_and_v2_compat() -> void:
	var w := WishlistItem.create("Велосипед", 18_000_000, "KZT")
	w.start_cooldown(7, NOW)
	w.resolve(WishlistItem.STATUS_BOUGHT, NOW + 8 * DAY)
	var r := WishlistItem.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	assert_eq(r.status, WishlistItem.STATUS_BOUGHT)
	assert_eq(r.cooldown_until, NOW + 7 * DAY)
	# Запись версии 2 без новых полей.
	var old := WishlistItem.from_dict({"id": "x", "title": "Старое", "price_minor": 100, "status": "мусор"})
	assert_eq(old.status, WishlistItem.STATUS_ACTIVE)
	assert_eq(old.cooldown_until, 0)


func test_with_status() -> void:
	var a := WishlistItem.create("A", 100, "KZT")
	var b := WishlistItem.create("B", 200, "KZT")
	b.resolve(WishlistItem.STATUS_DECLINED, NOW)
	var c := WishlistItem.create("C", 300, "KZT")
	c.resolve(WishlistItem.STATUS_DECLINED, NOW)
	var declined := WishlistItem.with_status([a, b, c], WishlistItem.STATUS_DECLINED)
	assert_eq(declined.size(), 2)
	assert_eq(WishlistItem.total_price(declined, "KZT"), 500)
	assert_eq(WishlistItem.with_status([a, b, c], WishlistItem.STATUS_ACTIVE).size(), 1)


func test_habit_daily_coffee() -> void:
	# Кофе 1 500 ₸ каждый день: 547 500 ₸ в год.
	var r := HabitCalculator.calculate(150_000, 1, HabitCalculator.PERIOD_DAY, 5)
	assert_true(r["ok"])
	assert_eq(r["yearly_minor"], 54_750_000)
	assert_eq(r["monthly_minor"], 4_562_500)
	assert_eq(r["total_minor"], 273_750_000)
	assert_eq(r["invested_minor"], 4_562_500 * 60, "без ставки — просто сумма пополнений")
	var with_rate := HabitCalculator.calculate(150_000, 1, HabitCalculator.PERIOD_DAY, 5, 1200)
	assert_true(int(with_rate["invested_minor"]) > int(with_rate["total_minor"]))


func test_habit_weekly_and_invalid() -> void:
	var r := HabitCalculator.calculate(300_000, 2, HabitCalculator.PERIOD_WEEK, 1)
	assert_eq(r["yearly_minor"], 300_000 * 2 * 52)
	assert_false(HabitCalculator.calculate(0, 1, HabitCalculator.PERIOD_DAY, 1)["ok"])
	assert_false(HabitCalculator.calculate(100, 1, "year", 1)["ok"])
	assert_false(HabitCalculator.calculate(100, 0, HabitCalculator.PERIOD_DAY, 1)["ok"])
	assert_false(HabitCalculator.calculate(100, 1, HabitCalculator.PERIOD_DAY, 0)["ok"])


func test_cashback() -> void:
	# Продукты 150 000 × 3 %, кафе 40 000 × 5 %, остальное 100 000 × 1 %.
	var rows := [{"spend_minor": 15_000_000, "rate_h": 300}, {"spend_minor": 4_000_000, "rate_h": 500},
		{"spend_minor": 10_000_000, "rate_h": 100}]
	var r := CashbackCalculator.calculate(rows)
	assert_true(r["ok"])
	assert_eq(r["monthly_spend"], 29_000_000)
	assert_eq(r["monthly_cashback"], 750_000)
	assert_eq(r["yearly_cashback"], 9_000_000)
	assert_false(r["capped"])
	assert_almost(r["effective_rate"], 9_000_000 * 100.0 / (29_000_000 * 12.0))


func test_cashback_cap_and_fee() -> void:
	var rows := [{"spend_minor": 15_000_000, "rate_h": 300}, {"spend_minor": 4_000_000, "rate_h": 500}]
	var r := CashbackCalculator.calculate(rows, 500_000, 3_000_000)
	assert_true(r["capped"])
	assert_eq(r["monthly_raw"], 650_000)
	assert_eq(r["monthly_cashback"], 500_000)
	assert_eq(r["yearly_net"], 3_000_000)
	var expensive := CashbackCalculator.calculate([{"spend_minor": 1_000_000, "rate_h": 100}], 0, 2_000_000)
	assert_true(int(expensive["yearly_net"]) < 0, "обслуживание дороже кэшбэка")
	assert_false(CashbackCalculator.calculate([])["ok"])
	assert_false(CashbackCalculator.calculate([{"spend_minor": 100, "rate_h": -1}])["ok"])


func test_tips() -> void:
	assert_true(Tips.ITEMS.size() >= 20)
	for t in Tips.ITEMS:
		assert_true(Tips.CATEGORY_NAMES.has(t["category"]), "категория %s" % t["category"])
		assert_false(String(t["title"]).is_empty())
	assert_eq(Tips.tip_of_day(NOW), Tips.tip_of_day(NOW + 60), "совет не меняется в течение дня")
	for key in Tips.CATEGORY_ORDER:
		assert_false(Tips.by_category(key).is_empty(), "советы в категории %s" % key)


func _ids(recs: Array) -> Array:
	var out: Array = []
	for r in recs:
		out.append(r["id"])
	return out


func test_advisor_new_user() -> void:
	var ids := _ids(Advisor.build(_profile(), [], [], {"now": NOW}))
	assert_true(ids.has("goal"), "предлагает цель")
	assert_true(ids.has("savings"), "предлагает указать накопления")
	assert_true(ids.has("expenses"), "предлагает посчитать расходы")
	assert_false(ids.has("cushion"))


func test_advisor_cushion_and_savings_rate() -> void:
	var p := _profile()
	p.savings_minor = 20_000_000
	var recs := Advisor.build(p, [], [], {"expenses_minor": 20_000_000, "monthly_savings_minor": 2_000_000, "now": NOW})
	var ids := _ids(recs)
	assert_true(ids.has("cushion"))
	assert_true(ids.has("savings_rate"), "5 % дохода — меньше 10 %")
	for r in recs:
		if r["id"] == "cushion":
			assert_eq(r["params"]["target_minor"], 60_000_000)
	var goal := FinancialGoal.create("Подушка безопасности", 60_000_000, 0, 1_000_000, "KZT")
	goal.is_primary = true
	assert_false(_ids(Advisor.build(p, [goal], [], {"expenses_minor": 20_000_000, "now": NOW})).has("cushion"),
		"цель-подушка уже есть")


func test_advisor_wishlist_and_loan() -> void:
	var p := _profile()
	var big := WishlistItem.create("Ноутбук", 30_000_000, "KZT")
	var due := WishlistItem.create("Кроссовки", 5_000_000, "KZT")
	due.cooldown_until = NOW - 10
	var ids := _ids(Advisor.build(p, [], [big, due], {"now": NOW,
		"loan": {"amount": 300_000_000, "rate": 2100, "term": 12}}))
	assert_true(ids.has("pause"))
	assert_true(ids.has("decisions"))
	assert_true(ids.has("loan_burden"))
	var recs := Advisor.build(p, [], [big, due], {"now": NOW})
	assert_eq(recs[0]["id"], "decisions", "решения по желаниям — первыми")


func test_advisor_invalid_profile() -> void:
	assert_true(Advisor.build(UserProfile.new(), [], [], {}).is_empty())
