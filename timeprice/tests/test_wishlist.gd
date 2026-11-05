extends TestCase


func _item(title: String, price: int, priority: int, created: int) -> WishlistItem:
	var w := WishlistItem.create(title, price, "KZT", "tech", priority)
	w.created_at = created
	return w


func test_create_and_validate() -> void:
	var w := WishlistItem.create(" Наушники ", 5_000_000, "KZT", "несуществующая", 99)
	assert_true(w.is_valid())
	assert_eq(w.title, "Наушники")
	assert_eq(w.category, WishlistItem.DEFAULT_CATEGORY)
	assert_eq(w.priority, WishlistItem.PRIORITY_LOW)
	assert_false(WishlistItem.create("", 100, "KZT").is_valid(), "без названия")
	assert_false(WishlistItem.create("x", 0, "KZT").is_valid(), "нулевая цена")


func test_result_uses_current_profile() -> void:
	var p := UserProfile.new()
	p.monthly_income_minor = 40_000_000
	var w := WishlistItem.create("Смартфон", 35_000_000, "KZT")
	assert_eq(w.result(p)["total_minutes"], 9240)
	p.currency = "USD"
	assert_false(w.result(p)["ok"], "валюта профиля изменилась")


func test_sorting() -> void:
	var a := _item("A", 300, WishlistItem.PRIORITY_LOW, 10)
	var b := _item("B", 100, WishlistItem.PRIORITY_HIGH, 20)
	var c := _item("C", 200, WishlistItem.PRIORITY_MEDIUM, 30)
	var items := [a, b, c]
	assert_eq(_titles(WishlistItem.sorted(items, WishlistItem.SORT_PRIORITY)), "BCA")
	assert_eq(_titles(WishlistItem.sorted(items, WishlistItem.SORT_NEWEST)), "CBA")
	assert_eq(_titles(WishlistItem.sorted(items, WishlistItem.SORT_PRICE_DESC)), "ACB")
	assert_eq(_titles(WishlistItem.sorted(items, WishlistItem.SORT_PRICE_ASC)), "BCA")
	assert_eq(_titles(items), "ABC", "исходный массив не изменяется")


func test_total_price_ignores_other_currencies() -> void:
	var a := _item("A", 300, 2, 1)
	var b := _item("B", 100, 2, 2)
	var usd := WishlistItem.create("C", 999, "USD")
	assert_eq(WishlistItem.total_price([a, b, usd], "KZT"), 400)
	assert_eq(WishlistItem.total_price([], "KZT"), 0)


func test_json_roundtrip() -> void:
	var w := WishlistItem.create("Ноутбук", 51_250_000, "KZT", "tech", WishlistItem.PRIORITY_HIGH)
	w.original_price_minor = 100_000
	w.original_currency = "USD"
	var restored := WishlistItem.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	assert_not_null(restored)
	assert_eq(restored.title, "Ноутбук")
	assert_eq(restored.category, "tech")
	assert_eq(restored.priority, WishlistItem.PRIORITY_HIGH)
	assert_true(restored.has_original_price())


func test_from_invalid_dict() -> void:
	assert_null(WishlistItem.from_dict({}))
	var w := WishlistItem.from_dict({"id": "x", "title": "t", "price_minor": 100, "category": "???", "priority": 7})
	assert_not_null(w)
	assert_eq(w.category, WishlistItem.DEFAULT_CATEGORY)
	assert_eq(w.priority, WishlistItem.PRIORITY_MEDIUM)


func _titles(items: Array) -> String:
	var s := ""
	for i in items:
		s += (i as WishlistItem).title
	return s
