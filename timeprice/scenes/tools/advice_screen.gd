extends BaseScreen
## Советы: персональные рекомендации по данным пользователя и библиотека лайфхаков.

var _category: String = ""
var _library: VBoxContainer


func _ready() -> void:
	build_scroll_layout()


func on_enter(params: Dictionary) -> void:
	_category = str(params.get("category", ""))
	_build()
	DataManager.goals_changed.connect(_build)
	DataManager.wishlist_changed.connect(_build)
	DataManager.profile_changed.connect(_build)


func on_resume() -> void:
	_build()


func _build() -> void:
	rebuild_keep_scroll(_build_content)


func _build_content() -> void:
	UI.clear_children(content)
	content.add_child(UI.top_bar("Советы", NavigationManager.go_back))
	var recs := Advisor.for_current_user()
	content.add_child(UI.label("ДЛЯ ВАС", &"SectionLabel"))
	if recs.is_empty():
		FormKit.notice(content, Loc.t("Сейчас персональных рекомендаций нет — по вашим данным всё в порядке. Загляните позже или почитайте советы ниже."), AppTheme.ACCENT, "check")
	for rec in recs:
		var box := UI.card(content, &"Card", 10)
		var row := UI.hbox(12)
		box.add_child(row)
		row.add_child(UI.icon_badge(rec["icon"], 40.0))
		var col := UI.vbox(4)
		row.add_child(col)
		col.add_child(UI.label(rec["title"], &"ValueLabel", true))
		col.add_child(UI.label(rec["text"], &"CaptionLabel", true))
		var route: String = rec["route"]
		var params: Dictionary = rec["params"]
		var b := UI.button(rec["action"], &"SecondaryButton", func() -> void: _open(route, params))
		b.custom_minimum_size.y = 44
		box.add_child(b)

	content.add_child(UI.spacer(4))
	content.add_child(UI.label("ЛАЙФХАКИ", &"SectionLabel"))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	content.add_child(chips)
	var all := UI.button("Все", &"ChipButton", func() -> void: _set_category(""))
	all.toggle_mode = true
	all.button_pressed = _category.is_empty()
	all.custom_minimum_size.y = 36
	chips.add_child(all)
	for key in Tips.CATEGORY_ORDER:
		var k: String = key
		var chip := UI.button(Tips.category_name(k), &"ChipButton", func() -> void: _set_category(k))
		chip.toggle_mode = true
		chip.button_pressed = _category == k
		chip.custom_minimum_size.y = 36
		chips.add_child(chip)
	for key in Tips.CATEGORY_ORDER:
		if not _category.is_empty() and key != _category:
			continue
		for tip in Tips.by_category(key):
			var box := UI.card(content, &"Card", 8)
			var head := UI.hbox(10)
			box.add_child(head)
			head.add_child(UI.icon_badge(Tips.CATEGORY_ICONS.get(key, "info"), 32.0))
			var t := UI.label(tip["title"], &"ValueLabel", true)
			t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			head.add_child(t)
			box.add_child(UI.label(tip["text"], &"BodySecondaryLabel", true))
			box.add_child(UI.label(Tips.category_name(key), &"MutedLabel"))
	content.add_child(UI.label("Советы носят общий характер и не являются индивидуальной финансовой консультацией. Условия банков уточняйте в официальных источниках.", &"MutedLabel", true))


func _set_category(key: String) -> void:
	_category = key
	_build()


func _open(route: String, params: Dictionary) -> void:
	if NavigationManager.is_tab_route(route):
		NavigationManager.switch_tab(route, params)
	else:
		NavigationManager.push(route, params)
