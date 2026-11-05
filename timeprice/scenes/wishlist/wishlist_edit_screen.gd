extends BaseScreen
## Добавление и изменение желания: название, стоимость, категория, приоритет.

var _item: WishlistItem  # null — новое желание
var _title_field: InputField
var _price_field: InputField
var _category_option: OptionButton
var _priority_buttons: Array[Button] = []
var _priority: int = WishlistItem.PRIORITY_MEDIUM
var _preview: VBoxContainer
var _currency: String = Currency.DEFAULT_CODE


func _ready() -> void:
	build_scroll_layout()


func on_enter(params: Dictionary) -> void:
	var id := str(params.get("id", ""))
	if not id.is_empty():
		var existing := DataManager.find_wishlist_item(id)
		if existing != null:
			_item = existing.copy()
	var profile := DataManager.profile
	_currency = profile.currency
	content.add_child(UI.top_bar("Новое желание" if _item == null else "Желание", _request_back))

	var form := UI.card(content, &"Card", 16)
	_title_field = InputField.new(InputField.Mode.TEXT, "Название", "Например, наушники")
	form.add_child(_title_field)
	_price_field = InputField.new(InputField.Mode.AMOUNT, "Стоимость", "0", Currency.symbol(_currency))
	form.add_child(_price_field)

	form.add_child(UI.label("Категория", &"CaptionLabel"))
	_category_option = OptionButton.new()
	_category_option.focus_mode = Control.FOCUS_NONE
	_category_option.custom_minimum_size.y = AppTheme.TOUCH_TARGET
	_category_option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for i in WishlistItem.CATEGORY_ORDER.size():
		_category_option.add_item(WishlistItem.category_name(WishlistItem.CATEGORY_ORDER[i]), i)
	form.add_child(_category_option)

	form.add_child(UI.label("Приоритет", &"CaptionLabel"))
	var priorities := UI.hbox(8)
	form.add_child(priorities)
	for value in [WishlistItem.PRIORITY_HIGH, WishlistItem.PRIORITY_MEDIUM, WishlistItem.PRIORITY_LOW]:
		var chip := UI.button(WishlistItem.priority_name(value), &"ChipButton")
		chip.toggle_mode = true
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size.y = 44
		chip.set_meta("value", value)
		chip.pressed.connect(_set_priority.bind(value))
		priorities.add_child(chip)
		_priority_buttons.append(chip)

	if _item != null:
		_title_field.set_text(_item.title)
		_price_field.set_amount(_item.price_minor)
		_priority = _item.priority
		_category_option.select(maxi(WishlistItem.CATEGORY_ORDER.find(_item.category), 0))
		if _item.currency != _currency:
			_price_field.set_helper(Loc.tf("Сейчас цена указана в %s. Укажите стоимость в валюте дохода (%s), чтобы снова видеть рабочее время.", [_item.currency, _currency]))
		elif _item.has_original_price():
			_price_field.set_helper(Loc.tf("Добавлено из калькулятора: %s.", [Fmt.money(_item.original_price_minor, _item.original_currency)]))
		form.add_child(UI.label(Loc.tf("Добавлено %s", [Fmt.date(_item.created_at)]), &"MutedLabel"))
	else:
		_category_option.select(WishlistItem.CATEGORY_ORDER.find(WishlistItem.DEFAULT_CATEGORY))
	_refresh_priority()
	_price_field.changed.connect(_update_preview)

	_preview = UI.vbox(8)
	content.add_child(_preview)
	content.add_child(UI.button("Добавить в список" if _item == null else "Сохранить изменения", &"PrimaryButton", _save))
	if _item != null:
		content.add_child(UI.button("Удалить желание", &"DangerButton", _confirm_delete))
	_update_preview()
	if _item == null:
		_title_field.focus.call_deferred()


func handle_back() -> bool:
	_request_back()
	return true


func _request_back() -> void:
	if _is_dirty():
		NavigationManager.confirm("Выйти без сохранения?", "Изменения не будут сохранены.", "Выйти",
			func() -> void: NavigationManager.go_back(), true)
	else:
		NavigationManager.go_back()


func _is_dirty() -> bool:
	if _item == null:
		return not _title_field.get_text().is_empty() or _price_field.get_amount() != InputField.EMPTY
	return _title_field.get_text() != _item.title or _price_field.get_amount() != _item.price_minor \
		or _priority != _item.priority or _selected_category() != _item.category


func _selected_category() -> String:
	return WishlistItem.CATEGORY_ORDER[clampi(_category_option.selected, 0, WishlistItem.CATEGORY_ORDER.size() - 1)]


func _set_priority(value: int) -> void:
	_priority = value
	_refresh_priority()


func _refresh_priority() -> void:
	for chip in _priority_buttons:
		chip.set_pressed_no_signal(int(chip.get_meta("value")) == _priority)


func _update_preview() -> void:
	UI.clear_children(_preview)
	var price := _price_field.get_amount()
	if price <= 0:
		return
	var r := DataManager.profile.calculate(price)
	if not r["ok"]:
		return
	var box := UI.card(_preview, &"Card", 6)
	box.add_child(UI.label("Стоимость в рабочем времени", &"CaptionLabel"))
	box.add_child(UI.label(Fmt.duration(r["total_minutes"]), &"ValueLabel"))
	box.add_child(UI.label(Loc.tf("%s · %s месячного дохода", [Fmt.work_days(r["days"]), Fmt.percent(r["income_percentage"])]), &"MutedLabel", true))


func _save() -> void:
	var ok := true
	var title := _title_field.get_text()
	if title.is_empty():
		_title_field.set_error("Введите название")
		ok = false
	var price := _price_field.get_amount()
	if price == InputField.EMPTY:
		_price_field.set_error("Введите стоимость")
		ok = false
	elif price <= 0:
		_price_field.set_error("Введите сумму цифрами больше нуля")
		ok = false
	if not ok:
		return
	if _item == null:
		var item := WishlistItem.create(title, price, _currency, _selected_category(), _priority)
		if DataManager.add_wishlist_item(item):
			NavigationManager.go_back()
			NavigationManager.show_toast(Loc.t("Добавлено в список желаний"))
		elif not DataManager.can_add_wishlist_item():
			NavigationManager.show_toast(Loc.t("Список желаний заполнен"))
		return
	var price_changed := price != _item.price_minor or _item.currency != _currency
	_item.title = title.substr(0, WishlistItem.MAX_TITLE_LENGTH)
	_item.price_minor = price
	_item.category = _selected_category()
	_item.priority = _priority
	if price_changed:
		_item.currency = _currency
		_item.original_price_minor = 0
		_item.original_currency = ""
	if DataManager.update_wishlist_item(_item):
		NavigationManager.go_back()
		NavigationManager.show_toast(Loc.t("Изменения сохранены"))


func _confirm_delete() -> void:
	NavigationManager.confirm("Удалить желание?", Loc.tf("«%s» будет удалено из списка.", [_item.title]),
		"Удалить", _delete, true)


func _delete() -> void:
	var id := _item.id
	NavigationManager.go_back()
	if DataManager.remove_wishlist_item(id):
		NavigationManager.show_toast(Loc.t("Желание удалено"))
