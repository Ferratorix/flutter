class_name ConfirmDialog
extends Control
## Модальный диалог подтверждения. Закрывается кнопкой «Отмена»,
## нажатием на затемнённый фон или системной кнопкой «Назад».

var _title: Label
var _message: Label
var _confirm: Button
var _on_confirm: Callable = Callable()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 24)
	add_child(margin)
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var box := UI.vbox(14)
	panel.add_child(box)
	_title = UI.label("", &"HeadingLabel", true)
	box.add_child(_title)
	_message = UI.label("", &"BodySecondaryLabel", true)
	box.add_child(_message)
	box.add_child(UI.spacer(4))
	var buttons := UI.hbox(10)
	box.add_child(buttons)
	var cancel := UI.button("Отмена", &"SecondaryButton", close)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(cancel)
	_confirm = UI.button("", &"PrimaryButton", _on_confirm_pressed)
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_confirm)


func open(options: Dictionary) -> void:
	_title.text = str(options.get("title", ""))
	_message.text = str(options.get("message", ""))
	_message.visible = not _message.text.is_empty()
	_confirm.text = str(options.get("confirm_text", "Подтвердить"))
	_confirm.theme_type_variation = &"DangerButton" if options.get("danger", false) else &"PrimaryButton"
	var cb: Variant = options.get("on_confirm", null)
	_on_confirm = cb if cb is Callable else Callable()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func close() -> void:
	visible = false
	_on_confirm = Callable()


func _on_confirm_pressed() -> void:
	var cb := _on_confirm
	close()
	if cb.is_valid():
		cb.call()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
