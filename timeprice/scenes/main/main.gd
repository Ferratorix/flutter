extends Control
## Корневая сцена: фон, безопасные отступы, область экранов, нижняя навигация,
## уведомления, диалоги, обработка кнопки «Назад» и виртуальной клавиатуры.

const EXIT_CONFIRM_WINDOW_MS := 2000

var _safe_margin: MarginContainer
var _screen_host: Control
var _bottom_nav: BottomNav
var _toast: Toast
var _dialog: ConfirmDialog
var _current_screen: BaseScreen
var _keyboard_height := 0.0
var _last_back_ms := -100000


func _ready() -> void:
	theme = AppTheme.get_theme()
	get_tree().root.theme = theme
	_build_layout()
	NavigationManager.route_changed.connect(_on_route_changed)
	NavigationManager.toast_requested.connect(_toast.show_message)
	NavigationManager.confirm_requested.connect(_dialog.open)
	DataManager.save_failed.connect(_on_save_failed)
	get_viewport().size_changed.connect(_update_insets)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_update_insets()

	if DataManager.has_ready_profile():
		NavigationManager.reset_to("home")
	else:
		NavigationManager.reset_to("onboarding")
	if not DataManager.load_message.is_empty():
		_toast.show_message(Loc.t(DataManager.load_message))


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = AppTheme.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_safe_margin = MarginContainer.new()
	_safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_safe_margin.add_child(column)

	_screen_host = Control.new()
	_screen_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_host.clip_contents = true
	_screen_host.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_screen_host)

	_bottom_nav = BottomNav.new()
	_bottom_nav.tab_selected.connect(_on_tab_selected)
	column.add_child(_bottom_nav)

	_toast = Toast.new()
	add_child(_toast)
	_dialog = ConfirmDialog.new()
	add_child(_dialog)


func _process(_delta: float) -> void:
	var kb := 0.0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		kb = DisplayServer.virtual_keyboard_get_height() * _screen_to_viewport_scale()
	if absf(kb - _keyboard_height) > 0.5:
		_keyboard_height = kb
		_update_insets()
		_ensure_focus_visible()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()


func _unhandled_input(event: InputEvent) -> void:
	# Esc на компьютере работает как «Назад» на Android.
	if event.is_action_pressed("ui_cancel") and not OS.has_feature("mobile"):
		get_viewport().set_input_as_handled()
		_handle_back()


func _input(event: InputEvent) -> void:
	# Касание вне поля ввода скрывает клавиатуру.
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	if not pressed:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit and not focused.get_global_rect().has_point(pos):
		focused.release_focus()


func _handle_back() -> void:
	if _dialog.visible:
		_dialog.close()
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit:
		# Клавиатуру к этому моменту уже скрыла система — просто снимаем фокус.
		focused.release_focus()
	if _current_screen != null and _current_screen.handle_back():
		return
	if NavigationManager.go_back():
		return
	var now := Time.get_ticks_msec()
	if now - _last_back_ms < EXIT_CONFIRM_WINDOW_MS:
		get_tree().quit()
	else:
		_last_back_ms = now
		_toast.show_message(Loc.t("Нажмите «Назад» ещё раз, чтобы выйти"))


func _on_tab_selected(route: String) -> void:
	NavigationManager.switch_tab(route)


func _on_route_changed(route: String, params: Dictionary, direction: int) -> void:
	var path := NavigationManager.scene_path(route)
	var packed := load(path) as PackedScene
	if packed == null:
		_toast.show_message(Loc.t("Не удалось открыть раздел"))
		push_error("Сцена не найдена: %s" % path)
		return
	var screen := packed.instantiate() as BaseScreen
	if screen == null:
		push_error("Сцена %s должна наследовать BaseScreen" % path)
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	if _current_screen != null:
		_current_screen.queue_free()
	_current_screen = screen
	_screen_host.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.on_enter(params)
	_bottom_nav.set_selected(route)
	_update_insets()
	_animate_in(screen, direction)


func _animate_in(screen: Control, direction: int) -> void:
	if SettingsManager.reduce_motion:
		return
	screen.modulate.a = 0.0
	screen.position.x = 24.0 * direction
	var tween := screen.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(screen, "modulate:a", 1.0, 0.22)
	tween.tween_property(screen, "position:x", 0.0, 0.28)


## Безопасные отступы (вырезы, системные панели) и высота клавиатуры.
func _update_insets() -> void:
	var top := 0.0
	var bottom := 0.0
	var left := 0.0
	var right := 0.0
	if OS.has_feature("mobile"):
		var px_scale := _screen_to_viewport_scale()
		var safe := DisplayServer.get_display_safe_area()
		var win_pos := DisplayServer.window_get_position()
		var win_size := DisplayServer.window_get_size()
		if safe.size.x > 0 and safe.size.y > 0:
			top = maxf(0.0, safe.position.y - win_pos.y) * px_scale
			left = maxf(0.0, safe.position.x - win_pos.x) * px_scale
			bottom = maxf(0.0, (win_pos.y + win_size.y) - safe.end.y) * px_scale
			right = maxf(0.0, (win_pos.x + win_size.x) - safe.end.x) * px_scale
	_safe_margin.add_theme_constant_override("margin_top", int(top))
	_safe_margin.add_theme_constant_override("margin_left", int(left))
	_safe_margin.add_theme_constant_override("margin_right", int(right))
	_safe_margin.add_theme_constant_override("margin_bottom", int(maxf(bottom, _keyboard_height)))
	_bottom_nav.visible = NavigationManager.is_bottom_nav_visible() and _keyboard_height <= 0.0


func _screen_to_viewport_scale() -> float:
	var win_size := DisplayServer.window_get_size()
	if win_size.y <= 0:
		return 1.0
	return get_viewport().get_visible_rect().size.y / float(win_size.y)


func _on_focus_changed(control: Control) -> void:
	if control is LineEdit:
		_ensure_focus_visible()


## Прокручивает экран так, чтобы активное поле не было закрыто клавиатурой.
func _ensure_focus_visible() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return
	var node: Node = focused.get_parent()
	while node != null and not (node is ScrollContainer):
		node = node.get_parent()
	if node is ScrollContainer:
		(node as ScrollContainer).ensure_control_visible(focused)


func _on_save_failed() -> void:
	_toast.show_message(Loc.t("Не удалось сохранить данные. Проверьте свободное место на устройстве."))
