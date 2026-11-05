extends BaseScreen
## История сохранённых расчётов: просмотр, удаление записи, очистка.


func _ready() -> void:
	build_scroll_layout()
	_build()
	DataManager.history_changed.connect(_build)


func _build() -> void:
	UI.clear_children(content)
	content.add_child(UI.top_bar("История расчётов"))
	var items := DataManager.history
	if items.is_empty():
		UI.empty_state(content, "history", "История пока пуста",
			"Рассчитайте стоимость покупки в калькуляторе и нажмите «Сохранить в историю» — расчёт появится здесь.")
		content.add_child(UI.button("Открыть калькулятор", &"PrimaryButton",
			func() -> void: NavigationManager.switch_tab("calculator")))
		return
	content.add_child(UI.label(Loc.tf("Сохранено: %d %s", [items.size(),
		Loc.plural(items.size(), ["расчёт", "расчёта", "расчётов"])]), &"CaptionLabel"))
	for item in items:
		_add_item(item)
	content.add_child(UI.spacer(4))
	content.add_child(UI.button("Очистить историю", &"DangerButton", _confirm_clear))


func _add_item(item: Purchase) -> void:
	var r := item.result()
	var box := UI.card(content, &"Card", 8)
	var top := UI.hbox(8)
	box.add_child(top)
	var titles := UI.vbox(2)
	top.add_child(titles)
	var name_label := UI.label(item.display_title(), &"ValueLabel")
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(name_label)
	titles.add_child(UI.label(Fmt.date_time(item.created_at), &"MutedLabel"))
	top.add_child(UI.icon_button("trash", func() -> void: _confirm_delete(item), "Удалить"))

	var price_text := Fmt.money(item.price_minor, item.currency)
	if item.is_converted():
		price_text += "  ≈ " + Fmt.money(item.base_price_minor, item.base_currency)
	box.add_child(UI.label(price_text, &"", true))
	var stats := UI.hbox(16)
	box.add_child(stats)
	_stat(stats, "Время", Fmt.duration(r["total_minutes"]))
	_stat(stats, "Рабочих дней", Fmt.decimal(r["days"], 1))
	_stat(stats, "От дохода", Fmt.percent(r["income_percentage"]))


func _stat(parent: Control, key: String, value: String) -> void:
	var col := UI.vbox(2)
	parent.add_child(col)
	col.add_child(UI.label(key, &"MutedLabel"))
	var v := UI.label(value, &"AccentLabel", true)
	col.add_child(v)


func _confirm_delete(item: Purchase) -> void:
	NavigationManager.confirm("Удалить расчёт?",
		Loc.tf("«%s» будет удалён из истории.", [item.display_title()]),
		"Удалить", _delete_item.bind(item.id), true)


func _delete_item(id: String) -> void:
	if DataManager.remove_purchase(id):
		NavigationManager.show_toast(Loc.t("Расчёт удалён"))


func _confirm_clear() -> void:
	NavigationManager.confirm("Очистить историю?",
		"Все сохранённые расчёты будут удалены без возможности восстановления.",
		"Очистить", _clear_history, true)


func _clear_history() -> void:
	if DataManager.clear_history():
		NavigationManager.show_toast(Loc.t("История очищена"))
