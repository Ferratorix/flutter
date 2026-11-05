extends Node
## Сквозная проверка интерфейса: onboarding, все разделы, «Назад», сохранение,
## перезапуск и восстановление повреждённого файла.
## ВНИМАНИЕ: сбрасывает данные TIMEPRICE на этом компьютере (user://).

## Скриншоты сохраняются в user://smoke_shots/.
const OUT := "user://smoke_shots/"
var main: Control
var fails: Array[String] = []

func check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)
		printerr("SMOKE FAIL: ", msg)

func wait(n := 25) -> void:
	for i in n:
		await get_tree().process_frame

func shot(shot_name: String) -> void:
	await wait(30)
	get_viewport().get_texture().get_image().save_png(OUT + shot_name + ".png")

func screen() -> BaseScreen:
	return main._current_screen

func route() -> String:
	return NavigationManager.current_route()

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DataManager.reset_all()
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await shot("01_welcome")
	check(route() == "onboarding", "старт с onboarding")
	var ob = screen()
	ob._go_next()
	await shot("02_income")
	ob._go_next()
	await wait()
	check(ob._step == 1, "пустой доход не пропускает")
	ob._income_field.set_text("400 000")
	ob._go_next()
	await shot("03_days")
	ob._go_next()
	await shot("04_hours")
	ob._go_next()
	await shot("05_currency")
	main._handle_back()
	await wait()
	check(ob._step == 3, "Назад в onboarding возвращает шаг")
	ob._go_next()
	ob._go_next()
	await shot("06_summary")
	ob._go_next()
	await wait()
	check(route() == "home", "после onboarding — главная")
	check(DataManager.profile.is_ready(), "профиль сохранён")
	var home = screen()
	home._quick_field.set_text("350000")
	home._quick_field._on_text_changed("350000")
	await shot("07_home")

	home._open_calculator()
	await wait()
	check(route() == "calculator", "переход в калькулятор")
	var calc = screen()
	calc._title_field.set_text("Смартфон")
	await shot("08_calculator")
	calc._save()
	calc._add_to_wishlist()
	await wait()
	check(DataManager.history.size() == 1, "расчёт в истории")
	check(DataManager.wishlist.size() == 1, "желание добавлено")
	NavigationManager.push("settings")
	await wait()
	main._handle_back()
	await wait()
	check(route() == "calculator" and screen() == calc and calc._price_field.get_amount() == 35_000_000, "Назад сохраняет калькулятор")
	calc._currency_option.select(3)
	calc._on_currency_selected(3)
	calc._rate_field.set_text("512,5")
	calc._recalculate()
	await shot("09_calculator_usd")

	NavigationManager.switch_tab("goals")
	await shot("10_goals_empty")
	NavigationManager.push("goal_edit")
	await wait()
	var ge = screen()
	ge._title_field.set_text("Отпуск")
	ge._target_field.set_text("1 500 000")
	ge._saved_field.set_text("300 000")
	ge._monthly_field.set_text("100 000")
	ge._update_preview()
	await shot("11_goal_edit")
	ge._save()
	await wait()
	check(DataManager.goals.size() == 1 and route() == "goals", "цель создана")
	var g := DataManager.goals[0]
	NavigationManager.push("goal_detail", {"id": g.id})
	await wait()
	screen()._apply_deposit(5_000_000)
	await shot("12_goal_detail")
	check(DataManager.goals[0].saved_minor == 35_000_000, "пополнение цели")
	main._handle_back()
	await shot("13_goals")

	DataManager.add_wishlist_item(WishlistItem.create("Наушники", 6_500_000, "KZT", "tech", 1))
	DataManager.add_wishlist_item(WishlistItem.create("Велосипед", 18_000_000, "KZT", "transport", 3))
	NavigationManager.switch_tab("wishlist")
	await shot("14_wishlist")
	var wl = screen()
	wl._set_compare(true)
	for w in DataManager.wishlist:
		wl._on_card_pressed(w.id)
	await shot("15_wishlist_compare")
	check(main._handle_back() == null and not wl._compare_mode, "Назад выходит из сравнения")

	NavigationManager.switch_tab("home")
	await wait()
	NavigationManager.push("simulator", {"price_minor": 35_000_000})
	await wait()
	var sim = screen()
	sim._savings_field.set_text("200 000")
	sim._expenses_field.set_text("200 000")
	sim._monthly_field.set_text("60 000")
	sim._recalculate()
	await shot("16_simulator")
	sim.scroll.scroll_vertical = 900
	await shot("17_simulator_scenarios")
	sim.scroll.scroll_vertical = 2400
	await shot("18_simulator_goal")
	main._handle_back()
	await wait()
	check(route() == "home", "Назад из симулятора")
	await shot("19_home_goal")

	NavigationManager.switch_tab("tools")
	await shot("20_tools")
	NavigationManager.push("deposit")
	await wait()
	var dep = screen()
	dep._initial.set_text("500 000")
	dep._monthly.set_text("50 000")
	dep._rate.set_text("14,5")
	dep._term.set_text("12")
	dep._inflation.set_text("8")
	dep._recalculate()
	await shot("22_deposit")
	dep.scroll.scroll_vertical = 1100
	await shot("23_deposit_results")
	main._handle_back()
	await wait()
	NavigationManager.push("loan", {"price_minor": 200_000_000})
	await wait()
	var loan = screen()
	loan._rate.set_text("21")
	loan._term.set_text("24")
	loan._fee.set_text("40 000")
	loan._recalculate()
	loan.scroll.scroll_vertical = 700
	await shot("24_loan")
	loan.scroll.scroll_vertical = 1500
	await shot("25_loan_schedule")
	main._handle_back()
	await wait()
	NavigationManager.push("installment", {"price_minor": 45_000_000})
	await wait()
	var inst = screen()
	inst._term.set_text("12")
	inst._discount.set_text("7")
	inst._recalculate()
	inst.scroll.scroll_vertical = 600
	await shot("26_installment")
	main._handle_back()
	await wait()
	check(route() == "tools", "Назад из инструментов")
	NavigationManager.push("history")
	await shot("20_history")
	main._handle_back()
	await wait()
	NavigationManager.push("settings")
	await shot("21_settings")
	main._handle_back()
	await wait()
	main._handle_back()
	await wait()
	check(route() == "home", "Назад с вкладки ведёт на главную")
	check(SettingsManager.get_tool_inputs("deposit").get("rate", -1) == 1450, "введённые значения депозита сохранены")

	# Перезапуск: данные перечитываются с диска.
	DataManager.load_data()
	check(DataManager.profile.is_ready(), "профиль после перезапуска")
	check(DataManager.history.size() == 1 and DataManager.goals.size() == 1 and DataManager.wishlist.size() == 3, "данные после перезапуска")
	# Повреждённый файл.
	var f := FileAccess.open(DataManager.DATA_PATH, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	DataManager.load_data()
	check(DataManager.profile.is_ready() and not DataManager.load_message.is_empty(), "восстановление из резервной копии")

	print("SMOKE DONE, fails: ", fails.size())
	DataManager.reset_all()
	get_tree().quit(1 if fails.size() > 0 else 0)
