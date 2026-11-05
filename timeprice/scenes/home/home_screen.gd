extends BaseScreen
## Главная: стоимость часа, профиль, быстрый расчёт и последние расчёты.

const RECENT_COUNT := 3

var _quick_field: InputField
var _quick_result: VBoxContainer
var _quick_price: int = -1


func _ready() -> void:
	build_scroll_layout()
	_build()
	DataManager.history_changed.connect(_build)
	DataManager.profile_changed.connect(_build)
	DataManager.goals_changed.connect(_build)


func _build() -> void:
	UI.clear_children(content)
	_quick_field = null
	var profile := DataManager.profile

	var header := UI.hbox(8)
	content.add_child(header)
	var titles := UI.vbox(2)
	header.add_child(titles)
	var brand := UI.label("TIMEPRICE", &"HeadingLabel")
	brand.add_theme_color_override("font_color", AppTheme.ACCENT)
	titles.add_child(brand)
	titles.add_child(UI.label("Твои деньги. Твоё время. Твой выбор.", &"MutedLabel", true))
	header.add_child(UI.icon_button("settings", func() -> void: NavigationManager.push("settings"), "Настройки"))

	if not profile.is_valid():
		add_profile_required_card(content)
		return

	_build_rate_card(profile)
	_build_quick_calc(profile)
	_build_goal(profile)
	_build_recent(profile)


func _build_rate_card(profile: UserProfile) -> void:
	var box := UI.card(content, &"AccentCard", 6)
	box.add_child(UI.label("Стоимость вашего рабочего часа", &"CaptionLabel"))
	box.add_child(UI.label(Fmt.money_compact(profile.hourly_rate(), profile.currency), &"DisplayLabel"))
	box.add_child(UI.spacer(6))
	var stats := UI.hbox(12)
	box.add_child(stats)
	_stat(stats, "Доход в месяц", Fmt.money(profile.monthly_income_minor, profile.currency))
	_stat(stats, "Рабочих дней", str(profile.working_days))
	_stat(stats, "Часов в день", Fmt.hours_from_minutes(profile.work_minutes_per_day))
	var edit := UI.button("Изменить данные", &"GhostButton", func() -> void: NavigationManager.push("settings"))
	edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	edit.custom_minimum_size.y = 40
	box.add_child(edit)


func _stat(parent: Control, key: String, value: String) -> void:
	var col := UI.vbox(2)
	parent.add_child(col)
	col.add_child(UI.label(key, &"MutedLabel", true))
	var v := UI.label(value, &"", true)
	v.add_theme_font_override("font", AppTheme.bold_font())
	col.add_child(v)


func _build_quick_calc(profile: UserProfile) -> void:
	var box := UI.card(content, &"Card", 12)
	box.add_child(UI.label("Быстрый расчёт", &"HeadingLabel"))
	_quick_field = InputField.new(InputField.Mode.AMOUNT, "", "Стоимость покупки", Currency.symbol(profile.currency))
	_quick_field.changed.connect(_update_quick_result)
	_quick_field.submitted.connect(_update_quick_result)
	box.add_child(_quick_field)
	_quick_result = UI.vbox(8)
	box.add_child(_quick_result)
	_update_quick_result()


func _update_quick_result() -> void:
	if _quick_field == null:
		return
	UI.clear_children(_quick_result)
	var profile := DataManager.profile
	var price := _quick_field.get_amount()
	_quick_price = -1
	if price == InputField.EMPTY:
		_quick_result.add_child(UI.label("Введите стоимость — покажем, сколько рабочего времени она занимает.", &"CaptionLabel", true))
		var sim := UI.button("Моделирование покупки", &"GhostButton", func() -> void: NavigationManager.push("simulator"))
		sim.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		sim.custom_minimum_size.y = 40
		_quick_result.add_child(sim)
		return
	if price == Money.INVALID:
		_quick_field.set_error("Введите сумму цифрами, например 350 000")
		return
	if price == 0:
		_quick_field.set_error("Стоимость должна быть больше нуля")
		return
	var r := profile.calculate(price)
	if not r["ok"]:
		return
	_quick_price = price
	var row := UI.hbox(12)
	_quick_result.add_child(row)
	row.add_child(UI.icon_badge("clock", 44.0))
	var col := UI.vbox(2)
	row.add_child(col)
	col.add_child(UI.label(Fmt.duration(r["total_minutes"]), &"ValueLabel", true))
	col.add_child(UI.label(Loc.tf("%s · %s месячного дохода", [Fmt.work_days(r["days"]), Fmt.percent(r["income_percentage"])]), &"CaptionLabel", true))
	var buttons := UI.hbox(10)
	_quick_result.add_child(buttons)
	var more := UI.button("Подробнее", &"SecondaryButton", _open_calculator)
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(more)
	var simulate := UI.button("Смоделировать", &"SecondaryButton",
		func() -> void: NavigationManager.push("simulator", {"price_minor": _quick_price}))
	simulate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(simulate)


func _open_calculator() -> void:
	if _quick_price > 0:
		NavigationManager.switch_tab("calculator", {"price_minor": _quick_price})


func _build_goal(profile: UserProfile) -> void:
	var goal := DataManager.get_primary_goal()
	var header := UI.hbox(8)
	content.add_child(header)
	var title := UI.label("Текущая цель", &"HeadingLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if goal == null:
		var box := UI.card(content, &"Card", 10)
		var row := UI.hbox(12)
		box.add_child(row)
		row.add_child(UI.icon_badge("target", 40.0))
		row.add_child(UI.label("Поставьте финансовую цель — покажем прогресс и сколько рабочего времени до неё осталось.", &"CaptionLabel", true))
		box.add_child(UI.button("Создать цель", &"SecondaryButton", func() -> void: NavigationManager.push("goal_edit")))
		return
	var all := UI.button("Все цели", &"GhostButton", func() -> void: NavigationManager.switch_tab("goals"))
	all.custom_minimum_size = Vector2(0, 40)
	header.add_child(all)
	var card := UI.tap_card(content, func() -> void: NavigationManager.push("goal_detail", {"id": goal.id}))
	GoalView.fill_summary(card, goal, profile)
	UI.pass_through(card)


func _build_recent(_profile: UserProfile) -> void:
	var header := UI.hbox(8)
	content.add_child(header)
	var title := UI.label("Последние расчёты", &"HeadingLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var recent := DataManager.get_recent(RECENT_COUNT)
	if recent.is_empty():
		UI.empty_state(content, "history", "Пока нет сохранённых расчётов",
			"Рассчитайте покупку в калькуляторе и сохраните результат — он появится здесь.")
		return
	var all := UI.button("Все", &"GhostButton", func() -> void: NavigationManager.switch_tab("history"))
	all.custom_minimum_size = Vector2(0, 40)
	header.add_child(all)
	var box := UI.card(content, &"Card", 4)
	for i in recent.size():
		if i > 0:
			box.add_child(UI.separator())
		var item: Purchase = recent[i]
		var r := item.result()
		var row := UI.hbox(12)
		row.custom_minimum_size.y = 52
		box.add_child(row)
		var left := UI.vbox(2)
		row.add_child(left)
		var name_label := UI.label(item.display_title(), &"")
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(name_label)
		left.add_child(UI.label(Fmt.money(item.price_minor, item.currency), &"MutedLabel"))
		var hours := UI.label(Fmt.duration(r["total_minutes"]), &"AccentLabel")
		hours.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(hours)
