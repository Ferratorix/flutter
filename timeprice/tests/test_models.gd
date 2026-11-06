extends TestCase


func _profile() -> UserProfile:
	var p := UserProfile.new()
	p.monthly_income_minor = 40_000_000
	p.working_days = 22
	p.work_minutes_per_day = 480
	p.currency = "KZT"
	p.onboarding_completed = true
	return p


func test_profile_defaults() -> void:
	var p := UserProfile.new()
	assert_eq(p.working_days, 22)
	assert_eq(p.work_minutes_per_day, 480)
	assert_eq(p.currency, "KZT")
	assert_false(p.has_savings())
	assert_false(p.is_valid(), "без дохода профиль некорректен")


func test_profile_roundtrip_through_json() -> void:
	var p := _profile()
	p.savings_minor = 0
	var text := JSON.stringify(p.to_dict())
	var restored := UserProfile.from_dict(JSON.parse_string(text))
	assert_true(restored.same_settings_as(p))
	assert_true(restored.is_ready())
	assert_true(restored.has_savings(), "нулевые накопления отличаются от неуказанных")


func test_profile_from_corrupted_dict() -> void:
	var p := UserProfile.from_dict({
		"monthly_income_minor": "много",
		"working_days": 99,
		"work_minutes_per_day": -5,
		"currency": "XXX",
		"onboarding_completed": true,
	})
	assert_eq(p.monthly_income_minor, 0)
	assert_eq(p.working_days, 22)
	assert_eq(p.work_minutes_per_day, 480)
	assert_eq(p.currency, "KZT")
	assert_false(p.onboarding_completed, "некорректный профиль требует повторной настройки")


func test_purchase_snapshot_is_independent_of_profile() -> void:
	var p := _profile()
	var item := Purchase.create("  Смартфон  ", 35_000_000, "KZT", 0, 35_000_000, p)
	assert_eq(item.title, "Смартфон")
	p.monthly_income_minor = 80_000_000
	var r := item.result()
	assert_eq(r["total_minutes"], 9240, "результат считается по снимку профиля")


func test_purchase_roundtrip_through_json() -> void:
	var item := Purchase.create("Ноутбук", 100_000, "USD", 5_125_000, 5_125_000, _profile())
	var restored := Purchase.from_dict(JSON.parse_string(JSON.stringify(item.to_dict())))
	assert_not_null(restored)
	assert_eq(restored.id, item.id)
	assert_eq(restored.price_minor, 100_000)
	assert_eq(restored.base_price_minor, 5_125_000)
	assert_eq(restored.rate_scaled, 5_125_000)
	assert_true(restored.is_converted())


func test_purchase_from_invalid_dict_returns_null() -> void:
	assert_null(Purchase.from_dict({}))
	assert_null(Purchase.from_dict({"id": "x", "base_price_minor": -1}))


func test_display_title_fallback() -> void:
	var item := Purchase.create("", 100, "KZT", 0, 100, _profile())
	assert_eq(item.display_title(), "Покупка без названия")
