extends BaseScreen
## Конфиденциальность и о приложении: политика, правовая пометка, контакты, лицензии.

var _licenses: VBoxContainer


func _ready() -> void:
	build_scroll_layout()
	content.add_child(UI.top_bar("О приложении", NavigationManager.go_back))
	var head := UI.card(content, &"AccentCard", 6)
	head.add_child(UI.label("TIMEPRICE", &"HeadingLabel"))
	head.add_child(UI.label(Loc.tf("Версия %s", [str(ProjectSettings.get_setting("application/config/version", ""))]), &"CaptionLabel"))
	head.add_child(UI.label("Твои деньги. Твоё время. Твой выбор.", &"MutedLabel", true))

	content.add_child(UI.label("ПОЛИТИКА КОНФИДЕНЦИАЛЬНОСТИ", &"SectionLabel"))
	content.add_child(UI.label(Loc.tf("Действует с %s", [LegalText.POLICY_DATE]), &"MutedLabel"))
	for section in LegalText.PRIVACY:
		var box := UI.card(content, &"Card", 6)
		box.add_child(UI.label(section[0], &"ValueLabel", true))
		box.add_child(UI.label(section[1], &"BodySecondaryLabel", true))

	content.add_child(UI.label("ВАЖНО", &"SectionLabel"))
	var disclaimer := UI.card(content, &"Card", 6)
	disclaimer.add_child(UI.label(LegalText.DISCLAIMER, &"BodySecondaryLabel", true))

	content.add_child(UI.label("КОНТАКТЫ", &"SectionLabel"))
	var contact := UI.card(content, &"Card", 8)
	contact.add_child(UI.label("Вопросы о приложении и обработке данных:", &"CaptionLabel", true))
	var mail := UI.label(LegalText.CONTACT_EMAIL, &"AccentLabel")
	contact.add_child(mail)

	content.add_child(UI.label("ЛИЦЕНЗИИ", &"SectionLabel"))
	var lic := UI.card(content, &"Card", 8)
	lic.add_child(UI.label("Приложение создано на Godot Engine (лицензия MIT) и использует компоненты с открытым исходным кодом.", &"CaptionLabel", true))
	_licenses = UI.vbox(8)
	lic.add_child(_licenses)
	var toggle := UI.button("Показать лицензии", &"GhostButton")
	toggle.pressed.connect(func() -> void:
		toggle.queue_free()
		_show_licenses())
	lic.add_child(toggle)


func _show_licenses() -> void:
	var godot := UI.label(Engine.get_license_text(), &"MutedLabel", true)
	_licenses.add_child(godot)
	var names := PackedStringArray()
	for info in Engine.get_copyright_info():
		names.append(str(info.get("name", "")))
	_licenses.add_child(UI.label(Loc.t("Сторонние компоненты движка: ") + ", ".join(names) + ".", &"MutedLabel", true))
	var licenses: Dictionary = Engine.get_license_info()
	for key in licenses:
		_licenses.add_child(UI.label(str(key), &"CaptionLabel"))
		_licenses.add_child(UI.label(str(licenses[key]), &"MutedLabel", true))
