extends BaseScreen
## Список желаний: сумма в рабочем времени, сортировка, сравнение, удаление.

static var _sort_mode: String = WishlistItem.SORT_PRIORITY

var _compare_mode := false
var _selected: Dictionary = {}  # id -> true


func _ready() -> void:
	build_scroll_layout()
	_build()
	DataManager.wishlist_changed.connect(_on_data_changed)
	DataManager.profile_changed.connect(_build)


func handle_back() -> bool:
	if _compare_mode:
		_set_compare(false)
		return true
	return false


func _on_data_changed() -> void:
	for id in _selected.keys():
		if DataManager.find_wishlist_item(id) == null:
			_selected.erase(id)
	_build()


func _build() -> void:
	rebuild_keep_scroll(_build_content)


func _build_content() -> void:
	UI.clear_children(content)
	content.add_child(UI.top_bar("Список желаний"))
	var profile := DataManager.profile
	if not profile.is_valid():
		add_profile_required_card(content)
		return
	var items := DataManager.wishlist
	if items.is_empty():
		UI.empty_state(content, "heart", "Список желаний пуст",
			"Добавляйте сюда покупки, которые планируете. TIMEPRICE покажет стоимость каждой в рабочих часах и поможет сравнить их между собой.")
		content.add_child(UI.button("Добавить желание", &"PrimaryButton", _add))
		content.add_child(UI.label("Желание можно добавить и из калькулятора после расчёта.", &"MutedLabel", true))
		return

	_build_summary(items, profile)
	_build_controls(items.size())
	if _compare_mode:
		_build_comparison(profile)
	for item in WishlistItem.sorted(items, _sort_mode):
		_add_card(item, profile)
	if not _compare_mode and DataManager.can_add_wishlist_item():
		content.add_child(UI.button("Добавить желание", &"SecondaryButton", _add))


func _build_summary(items: Array[WishlistItem], profile: UserProfile) -> void:
	var total := WishlistItem.total_price(items, profile.currency)
	var box := UI.card(content, &"AccentCard", 6)
	box.add_child(UI.label(Loc.tf("%d %s на сумму", [items.size(), Loc.plural(items.size(), ["желание", "желания", "желаний"])]), &"CaptionLabel"))
	box.add_child(UI.label(Fmt.money(total, profile.currency), &"DisplayLabel", true))
	var r := profile.calculate(total)
	if r["ok"]:
		box.add_child(UI.label(Loc.tf("≈ %s рабочего времени · %s", [Fmt.duration(r["total_minutes"]), Fmt.work_days(r["days"])]), &"CaptionLabel", true))
		var incomes: float = r["income_percentage"] / 100.0
		box.add_child(UI.label(Loc.tf("Это %s месячного дохода", [Fmt.percent(r["income_percentage"])]) if incomes < 1.0
			else Loc.tf("Это %s месячных доходов", [Fmt.decimal(incomes, 1)]), &"MutedLabel", true))


func _build_controls(count: int) -> void:
	var row := UI.hbox(10)
	content.add_child(row)
	var sort := OptionButton.new()
	sort.focus_mode = Control.FOCUS_NONE
	sort.custom_minimum_size.y = 44
	sort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for i in WishlistItem.SORT_ORDER.size():
		var mode: String = WishlistItem.SORT_ORDER[i]
		sort.add_item(Loc.t(WishlistItem.SORT_NAMES[mode]), i)
		if mode == _sort_mode:
			sort.select(i)
	sort.item_selected.connect(func(i: int) -> void:
		_sort_mode = WishlistItem.SORT_ORDER[i]
		_build())
	row.add_child(sort)
	if count >= 2:
		var compare := UI.button("Готово" if _compare_mode else "Сравнить", &"PrimaryButton" if _compare_mode else &"SecondaryButton",
			func() -> void: _set_compare(not _compare_mode))
		compare.icon = IconLibrary.texture("compare")
		compare.custom_minimum_size.y = 44
		row.add_child(compare)


func _set_compare(on: bool) -> void:
	_compare_mode = on
	if not on:
		_selected.clear()
	_build()


func _build_comparison(profile: UserProfile) -> void:
	var box := UI.card(content, &"Card", 10)
	box.add_child(UI.label("Сравнение", &"HeadingLabel"))
	var chosen: Array = []
	for item in DataManager.wishlist:
		if _selected.has(item.id):
			chosen.append(item)
	if chosen.size() < 2:
		box.add_child(UI.label("Отметьте два или больше желаний ниже, чтобы сравнить их в рабочем времени.", &"CaptionLabel", true))
		return
	chosen = WishlistItem.sorted(chosen, WishlistItem.SORT_PRICE_DESC)
	var max_minutes := 1
	for item in chosen:
		var r := (item as WishlistItem).result(profile)
		if r["ok"]:
			max_minutes = maxi(max_minutes, int(r["total_minutes"]))
	for item in chosen:
		var w := item as WishlistItem
		var r := w.result(profile)
		var head := UI.hbox(8)
		box.add_child(head)
		var name_label := UI.label(w.title, &"")
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		if r["ok"]:
			head.add_child(UI.label(Fmt.duration(r["total_minutes"]), &"AccentLabel"))
			box.add_child(UI.progress_bar(r["total_minutes"], max_minutes, 6.0))
			box.add_child(UI.label(Loc.tf("%s · %s · %s дохода", [Fmt.money(w.price_minor, w.currency),
				Fmt.work_days(r["days"]), Fmt.percent(r["income_percentage"])]), &"MutedLabel", true))
		else:
			head.add_child(UI.label(Fmt.money(w.price_minor, w.currency), &"CaptionLabel"))
	var total := WishlistItem.total_price(chosen, profile.currency)
	var tr_total := profile.calculate(total)
	box.add_child(UI.separator())
	box.add_child(UI.kv_row("Вместе", Fmt.money(total, profile.currency)))
	if tr_total["ok"]:
		box.add_child(UI.kv_row("В рабочем времени", Fmt.duration(tr_total["total_minutes"])))
	var cheapest := chosen.back() as WishlistItem
	var priciest := chosen.front() as WishlistItem
	if cheapest.price_minor > 0 and priciest.price_minor > cheapest.price_minor:
		box.add_child(UI.label(Loc.tf("«%s» дороже «%s» в %s раза.", [priciest.title, cheapest.title,
			Fmt.decimal(float(priciest.price_minor) / float(cheapest.price_minor), 1)]), &"MutedLabel", true))


func _add_card(item: WishlistItem, profile: UserProfile) -> void:
	var selected := _selected.has(item.id)
	var box := UI.tap_card(content, _on_card_pressed.bind(item.id), 8)
	var card_button := UI.tap_card_button(box)
	if _compare_mode and selected:
		card_button.theme_type_variation = &"CardButtonSelected"

	var top := UI.hbox(8)
	box.add_child(top)
	if _compare_mode:
		top.add_child(IconLibrary.rect("check" if selected else "plus", 20.0, AppTheme.ACCENT if selected else AppTheme.TEXT_MUTED))
	var title := UI.label(item.title, &"ValueLabel")
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if not _compare_mode:
		top.add_child(UI.icon_button("trash", _confirm_delete.bind(item.id), "Удалить"))

	var tags := UI.hbox(6)
	box.add_child(tags)
	tags.add_child(UI.tag(WishlistItem.category_name(item.category)))
	var priority_color := AppTheme.WARNING if item.priority == WishlistItem.PRIORITY_HIGH else AppTheme.TEXT_SECONDARY
	tags.add_child(UI.tag(Loc.tf("Приоритет: %s", [WishlistItem.priority_name(item.priority).to_lower()]), priority_color))

	var price_text := Fmt.money(item.price_minor, item.currency)
	if item.has_original_price():
		price_text += "  (" + Fmt.money(item.original_price_minor, item.original_currency) + ")"
	box.add_child(UI.label(price_text, &"", true))
	var r := item.result(profile)
	if r["ok"]:
		var stats := UI.hbox(16)
		box.add_child(stats)
		_stat(stats, "Время", Fmt.duration(r["total_minutes"]))
		_stat(stats, "Рабочих дней", Fmt.decimal(r["days"], 1))
		_stat(stats, "От дохода", Fmt.percent(r["income_percentage"]))
	else:
		box.add_child(UI.label("Валюта желания отличается от валюты дохода — рабочее время не рассчитать. Откройте желание и обновите цену.", &"MutedLabel", true))
	box.add_child(UI.label(Loc.tf("Добавлено %s", [Fmt.date(item.created_at)]), &"MutedLabel"))
	UI.pass_through(box)


func _stat(parent: Control, key: String, value: String) -> void:
	var col := UI.vbox(2)
	parent.add_child(col)
	col.add_child(UI.label(key, &"MutedLabel"))
	col.add_child(UI.label(value, &"AccentLabel", true))


func _on_card_pressed(id: String) -> void:
	if _compare_mode:
		if _selected.has(id):
			_selected.erase(id)
		else:
			_selected[id] = true
		_build()
	else:
		NavigationManager.push("wishlist_edit", {"id": id})


func _add() -> void:
	NavigationManager.push("wishlist_edit")


func _confirm_delete(id: String) -> void:
	var item := DataManager.find_wishlist_item(id)
	if item == null:
		return
	NavigationManager.confirm("Удалить желание?", Loc.tf("«%s» будет удалено из списка.", [item.title]),
		"Удалить", _delete.bind(id), true)


func _delete(id: String) -> void:
	if DataManager.remove_wishlist_item(id):
		NavigationManager.show_toast(Loc.t("Желание удалено"))
