extends BaseScreen
## Настройки: профиль (доход, график, валюта, накопления), интерфейс, данные.

var _draft: UserProfile
var _income_field: InputField
var _savings_field: InputField
var _days_stepper: Stepper
var _hours_stepper: Stepper
var _currency_option: OptionButton
var _rate_preview: Label
var _save_button: Button


func _ready() -> void:
	build_scroll_layout()
	_draft = DataManager.profile.copy()
	_build()


func handle_back() -> bool:
	_request_back()
	return true


func _request_back() -> void:
	_read_fields()
	if _is_dirty():
		NavigationManager.confirm("Выйти без сохранения?",
			"Изменения профиля не будут сохранены.", "Выйти",
			func() -> void: NavigationManager.go_back(), true)
	else:
		NavigationManager.go_back()


func _build() -> void:
	content.add_child(UI.top_bar("Настройки", _request_back))

	# --- Профиль ---
	content.add_child(UI.label("ПРОФИЛЬ", &"SectionLabel"))
	var profile_box := UI.card(content, &"Card", 16)
	_income_field = InputField.new(InputField.Mode.AMOUNT, "Месячный доход", "Например, 400 000", Currency.symbol(_draft.currency))
	_income_field.set_helper("Можно указать примерную сумму.")
	if _draft.monthly_income_minor > 0:
		_income_field.set_amount(_draft.monthly_income_minor)
	_income_field.changed.connect(_on_changed)
	profile_box.add_child(_income_field)

	profile_box.add_child(UI.label("Рабочих дней в месяц", &"CaptionLabel"))
	_days_stepper = Stepper.new(FinancialCalculator.MIN_WORKING_DAYS, FinancialCalculator.MAX_WORKING_DAYS,
		1, _draft.working_days, func(v: int) -> String: return Fmt.days_count(v))
	_days_stepper.value_changed.connect(func(_v: int) -> void: _on_changed())
	profile_box.add_child(_days_stepper)

	profile_box.add_child(UI.label("Часов в рабочем дне", &"CaptionLabel"))
	_hours_stepper = Stepper.new(FinancialCalculator.MIN_WORK_MINUTES, FinancialCalculator.MAX_WORK_MINUTES,
		30, _draft.work_minutes_per_day, func(v: int) -> String: return Fmt.hours_from_minutes(v))
	_hours_stepper.value_changed.connect(func(_v: int) -> void: _on_changed())
	profile_box.add_child(_hours_stepper)

	profile_box.add_child(UI.label("Валюта дохода", &"CaptionLabel"))
	_currency_option = OptionButton.new()
	_currency_option.custom_minimum_size.y = AppTheme.TOUCH_TARGET
	_currency_option.focus_mode = Control.FOCUS_NONE
	_currency_option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for i in Currency.ORDER.size():
		var code: String = Currency.ORDER[i]
		_currency_option.add_item(Currency.long_label(code), i)
		if code == _draft.currency:
			_currency_option.select(i)
	_currency_option.item_selected.connect(func(_i: int) -> void: _on_changed())
	profile_box.add_child(_currency_option)

	_savings_field = InputField.new(InputField.Mode.AMOUNT, "Текущие накопления (необязательно)", "Не указаны", Currency.symbol(_draft.currency))
	_savings_field.set_helper("Используются для сравнения покупки с накоплениями. Оставьте поле пустым, если не хотите указывать.")
	if _draft.has_savings():
		_savings_field.set_amount(_draft.savings_minor)
	_savings_field.changed.connect(_on_changed)
	profile_box.add_child(_savings_field)

	_rate_preview = UI.label("", &"AccentLabel", true)
	profile_box.add_child(_rate_preview)
	_save_button = UI.button("Сохранить изменения", &"PrimaryButton", _save)
	profile_box.add_child(_save_button)

	# --- Интерфейс ---
	content.add_child(UI.spacer(4))
	content.add_child(UI.label("ИНТЕРФЕЙС", &"SectionLabel"))
	var ui_box := UI.card(content, &"Card", 10)
	var motion := CheckButton.new()
	motion.text = "Упрощённые анимации"
	motion.focus_mode = Control.FOCUS_NONE
	motion.button_pressed = SettingsManager.reduce_motion
	motion.custom_minimum_size.y = 44
	motion.toggled.connect(func(on: bool) -> void: SettingsManager.set_reduce_motion(on))
	ui_box.add_child(motion)
	ui_box.add_child(UI.separator())
	ui_box.add_child(UI.kv_row("Язык интерфейса", "Русский"))
	ui_box.add_child(UI.label("Казахский, узбекский и английский языки появятся в следующих версиях.", &"MutedLabel", true))

	# --- Данные ---
	content.add_child(UI.spacer(4))
	content.add_child(UI.label("ДАННЫЕ", &"SectionLabel"))
	var data_box := UI.card(content, &"Card", 12)
	var privacy := UI.hbox(12)
	data_box.add_child(privacy)
	privacy.add_child(UI.icon_badge("shield", 36.0))
	privacy.add_child(UI.label("Все данные хранятся только на этом устройстве и никуда не передаются.", &"CaptionLabel", true))
	data_box.add_child(UI.separator())
	data_box.add_child(UI.label("Резервная копия", &"ValueLabel"))
	data_box.add_child(UI.label("Сохраните копию в файл — в «Загрузки», на Google Диск или в другое место — и восстановите её на новом телефоне или после переустановки. Файл не зашифрован: храните его в надёжном месте и не пересылайте посторонним.", &"CaptionLabel", true))
	data_box.add_child(UI.button("Сохранить копию в файл", &"SecondaryButton", _export_backup))
	data_box.add_child(UI.button("Восстановить из файла", &"SecondaryButton", _pick_import))
	data_box.add_child(UI.separator())
	data_box.add_child(UI.button("Удалить все данные", &"DangerButton", _confirm_reset))

	content.add_child(UI.spacer(4))
	content.add_child(UI.label("О ПРИЛОЖЕНИИ", &"SectionLabel"))
	var about_box := UI.card(content, &"Card", 10)
	about_box.add_child(UI.button("Конфиденциальность и о приложении", &"SecondaryButton",
		func() -> void: NavigationManager.push("about")))

	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var about := UI.label(Loc.tf("TIMEPRICE, версия %s", [version]), &"MutedLabel")
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(UI.spacer(4))
	content.add_child(about)
	_on_changed()


## Переносит значения полей в черновик. false — есть ошибки ввода.
func _read_fields(show_errors: bool = false) -> bool:
	var ok := true
	var income := _income_field.get_amount()
	if income > 0:
		_draft.monthly_income_minor = income
	else:
		ok = false
		if show_errors:
			if income == InputField.EMPTY:
				_income_field.set_error("Введите сумму дохода")
			elif income == 0:
				_income_field.set_error("Доход должен быть больше нуля")
			else:
				_income_field.set_error("Введите сумму цифрами, например 400 000")
	var savings := _savings_field.get_amount()
	if savings == InputField.EMPTY:
		_draft.savings_minor = UserProfile.SAVINGS_NOT_SET
	elif savings == Money.INVALID:
		ok = false
		if show_errors:
			_savings_field.set_error("Введите сумму цифрами или оставьте поле пустым")
	else:
		_draft.savings_minor = savings
	_draft.working_days = _days_stepper.value
	_draft.work_minutes_per_day = _hours_stepper.value
	_draft.currency = Currency.ORDER[clampi(_currency_option.selected, 0, Currency.ORDER.size() - 1)]
	return ok


func _is_dirty() -> bool:
	return not _draft.same_settings_as(DataManager.profile)


func _on_changed() -> void:
	var valid := _read_fields()
	var symbol := Currency.symbol(_draft.currency)
	_income_field.set_suffix(symbol)
	_savings_field.set_suffix(symbol)
	if valid and _draft.is_valid():
		_rate_preview.text = Loc.tf("Стоимость часа: %s", [Fmt.money_compact(_draft.hourly_rate(), _draft.currency)])
	else:
		_rate_preview.text = ""
	_save_button.disabled = not _is_dirty()


func _save() -> void:
	if not _read_fields(true) or not _draft.is_valid():
		NavigationManager.show_toast(Loc.t("Проверьте введённые данные"))
		return
	_draft.onboarding_completed = true
	if DataManager.update_profile(_draft):
		_draft = DataManager.profile.copy()
		_save_button.disabled = true
		NavigationManager.show_toast(Loc.t("Изменения сохранены"))


# --- Резервная копия --------------------------------------------------------

func _export_backup() -> void:
	var backup := BackupService.compose(DataManager.snapshot(), SettingsManager.export_dict(),
		str(ProjectSettings.get_setting("application/config/version", "")), DataUtil.now())
	FilePicker.save_file(self, Loc.t("Сохранить резервную копию"), BackupService.default_file_name(DataUtil.now()),
		func(path: String) -> void: _write_backup(path, BackupService.to_text(backup)))


func _write_backup(path: String, text: String) -> void:
	if FilePicker.write_text(path, text) == OK:
		NavigationManager.show_toast(Loc.t("Резервная копия сохранена"))
	else:
		NavigationManager.show_toast(Loc.t("Не удалось сохранить файл. Выберите другое место."))


func _pick_import() -> void:
	FilePicker.open_file(self, Loc.t("Выберите файл резервной копии"), _read_import)


func _read_import(path: String) -> void:
	var file := FilePicker.read_text(path)
	if file["too_large"]:
		NavigationManager.show_toast(BackupService.error_message(BackupService.ERROR_TOO_LARGE))
		return
	if not file["ok"]:
		NavigationManager.show_toast(Loc.t("Не удалось открыть файл."))
		return
	var parsed := BackupService.parse(file["text"], DataManager.SCHEMA_VERSION)
	if not parsed["ok"]:
		NavigationManager.show_toast(BackupService.error_message(parsed["error"]))
		return
	var summary: Dictionary = parsed["summary"]
	var details := Loc.tf("Копия от %s: профиль — %s, целей — %d, желаний — %d, расчётов — %d.", [
		Fmt.date_time(summary["created_at"]) if int(summary["created_at"]) > 0 else Loc.t("неизвестной даты"),
		Loc.t("есть") if summary["has_profile"] else Loc.t("нет"),
		summary["goals"], summary["wishlist"], summary["history"]])
	NavigationManager.confirm("Восстановить данные?",
		details + " " + Loc.t("Текущие данные будут заменены. Перед заменой они сохранятся в отдельный файл на устройстве."),
		"Восстановить", _apply_import.bind(parsed), true)


func _apply_import(parsed: Dictionary) -> void:
	if not DataManager.restore_snapshot(parsed["data"]):
		NavigationManager.show_toast(Loc.t("Не удалось восстановить данные. Текущие данные не изменены."))
		return
	SettingsManager.import_dict(parsed["settings"])
	NavigationManager.show_toast(Loc.t("Данные восстановлены"))
	if DataManager.has_ready_profile():
		NavigationManager.reset_to("home")
	else:
		NavigationManager.reset_to("onboarding")


func _confirm_reset() -> void:
	NavigationManager.confirm("Удалить все данные?",
		"Профиль, настройки и история расчётов будут удалены с устройства. Это действие нельзя отменить.",
		"Удалить", _reset_all, true)


func _reset_all() -> void:
	DataManager.reset_all()
	NavigationManager.reset_to("onboarding")
