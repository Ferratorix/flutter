extends Node
## Скриншоты для страницы Google Play с одинаковыми демонстрационными данными.
## ВНИМАНИЕ: сбрасывает данные TIMEPRICE на этом компьютере (user://).
## Запуск: godot --path timeprice --resolution 1080x1920 res://tests/store_screenshots/store_screenshots.tscn
## Результат: user://store_screenshots/*.png

const OUT := "user://store_screenshots/"
var main: Control


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DataManager.reset_all()
	SettingsManager.set_reduce_motion(true)
	var p := UserProfile.new()
	p.monthly_income_minor = 40_000_000
	p.savings_minor = 50_000_000
	p.onboarding_completed = true
	DataManager.update_profile(p)
	var goal := FinancialGoal.create("Отпуск на море", 150_000_000, 45_000_000, 10_000_000, "KZT")
	DataManager.add_goal(goal)
	for w in [["Смартфон", 35_000_000, "tech", 1], ["Велосипед", 18_000_000, "transport", 3], ["Наушники", 6_500_000, "tech", 2]]:
		DataManager.add_wishlist_item(WishlistItem.create(w[0], w[1], "KZT", w[2], w[3]))
	DataManager.add_purchase(Purchase.create("Смартфон", 35_000_000, "KZT", 0, 35_000_000, p))
	SettingsManager.simulator_expenses_minor = 20_000_000
	SettingsManager.simulator_monthly_savings_minor = 6_000_000
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await shot("01_home")
	NavigationManager.switch_tab("calculator", {"price_minor": 35_000_000})
	await wait()
	main._current_screen._title_field.set_text("Смартфон")
	await shot("02_calculator")
	NavigationManager.switch_tab("goals")
	await wait()
	NavigationManager.push("goal_detail", {"id": goal.id})
	await shot("03_goal")
	NavigationManager.switch_tab("wishlist")
	await wait()
	var wl = main._current_screen
	wl._set_compare(true)
	for w in DataManager.wishlist:
		wl._on_card_pressed(w.id)
	await shot("04_wishlist_compare")
	NavigationManager.switch_tab("home")
	await wait()
	NavigationManager.push("simulator", {"price_minor": 35_000_000})
	await wait()
	main._current_screen.scroll.scroll_vertical = 1050
	await shot("05_simulator")
	NavigationManager.switch_tab("tools")
	await wait()
	NavigationManager.push("loan", {"price_minor": 200_000_000})
	await wait()
	var loan = main._current_screen
	loan._rate.set_text("21")
	loan._term.set_text("24")
	loan._recalculate()
	await wait()
	loan.scroll.scroll_vertical = 640
	await shot("06_loan")
	main._handle_back()
	await wait()
	NavigationManager.push("habit")
	await wait()
	var hab = main._current_screen
	hab._apply_preset(hab.PRESETS[0])
	hab._rate.set_text("14")
	hab._recalculate()
	await wait()
	hab.scroll.scroll_vertical = 640
	await shot("07_habit")
	main._handle_back()
	await wait()
	NavigationManager.push("advice")
	await shot("08_advice")
	DataManager.reset_all()
	get_tree().quit()


func wait(n := 20) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name_: String) -> void:
	await wait(30)
	main._toast._panel.visible = false
	await wait(3)
	get_viewport().get_texture().get_image().save_png(OUT + name_ + ".png")
