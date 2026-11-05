class_name PurchaseResultView
extends RefCounted
## Подробный результат расчёта покупки (используется калькулятором).
## Формулировки нейтральные: приложение информирует, а не оценивает покупку.


static func build(parent: Control, r: Dictionary, profile: UserProfile, converted_note: String = "") -> void:
	var hero := UI.card(parent, &"AccentCard", 6)
	hero.add_child(UI.label("Эта покупка стоит", &"CaptionLabel"))
	hero.add_child(UI.label(Fmt.duration(r["total_minutes"]), &"DisplayLabel", true))
	hero.add_child(UI.label("вашего рабочего времени", &"CaptionLabel"))
	if not converted_note.is_empty():
		hero.add_child(UI.spacer(4))
		hero.add_child(UI.label(converted_note, &"MutedLabel", true))

	var box := UI.card(parent, &"Card", 10)
	box.add_child(UI.kv_row("Рабочих дней", Fmt.decimal(r["days"], 1)))
	box.add_child(UI.label(Fmt.full_days_breakdown(r["full_days"], r["remainder_minutes"]), &"MutedLabel", true))
	box.add_child(UI.separator())
	box.add_child(UI.kv_row("Рабочих часов", Fmt.decimal(r["hours"], 1)))
	box.add_child(UI.kv_row("Стоимость часа", Fmt.money_compact(r["hourly_rate"], profile.currency)))
	box.add_child(UI.separator())

	var pct: float = r["income_percentage"]
	box.add_child(UI.kv_row("Доля месячного дохода", Fmt.percent(pct)))
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = minf(pct, 100.0)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	box.add_child(bar)
	if pct > 100.0:
		box.add_child(UI.label(Loc.tf("Сумма больше месячного дохода в %s раза.", [Fmt.decimal(pct / 100.0, 1)]), &"MutedLabel", true))

	box.add_child(UI.separator())
	_build_savings(box, r, profile)


static func _build_savings(box: Control, r: Dictionary, profile: UserProfile) -> void:
	if not profile.has_savings():
		box.add_child(UI.kv_row("Накопления", "не указаны", &"MutedLabel"))
		box.add_child(UI.label("Укажите текущие накопления в настройках, чтобы сравнить с ними покупку.", &"MutedLabel", true))
		var link := UI.button("Указать накопления", &"GhostButton", func() -> void: NavigationManager.push("settings"))
		link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		link.custom_minimum_size.y = 40
		box.add_child(link)
		return
	if profile.savings_minor == 0:
		box.add_child(UI.kv_row("Накопления", Fmt.money(0, profile.currency)))
		box.add_child(UI.label("Сейчас накоплений нет: покупка будет оплачиваться из будущего дохода.", &"MutedLabel", true))
		return
	var spct: float = r["savings_percentage"]
	box.add_child(UI.kv_row("Доля накоплений", Fmt.percent(spct)))
	var left: int = r["savings_left_minor"]
	if left >= 0:
		box.add_child(UI.label(Loc.tf("После покупки из накоплений останется %s.", [Fmt.money(left, profile.currency)]), &"MutedLabel", true))
	else:
		box.add_child(UI.label(Loc.tf("Сумма превышает текущие накопления на %s.", [Fmt.money(-left, profile.currency)]), &"MutedLabel", true))
