class_name BaseScreen
extends Control
## Базовый класс экранов. Main создаёт экран, добавляет его в дерево и
## вызывает on_enter(params). handle_back() позволяет экрану перехватить
## системную кнопку «Назад» (например, шаги onboarding или несохранённые изменения).

var scroll: ScrollContainer
var content: VBoxContainer


func on_enter(_params: Dictionary) -> void:
	pass


## true — событие обработано экраном.
func handle_back() -> bool:
	return false


## Прокручиваемая область с отступами. Возвращает контейнер для содержимого.
func build_scroll_layout(parent: Control = null, separation: int = 16) -> VBoxContainer:
	var host: Control = parent if parent != null else self
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent == null:
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", AppTheme.SCREEN_PADDING)
	margin.add_theme_constant_override("margin_right", AppTheme.SCREEN_PADDING)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 28)
	scroll.add_child(margin)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", separation)
	margin.add_child(content)
	return content


## Сообщение о необходимости настроить профиль (если данные повреждены или сброшены).
func add_profile_required_card(parent: Control) -> void:
	var box := UI.card(parent, &"Card", 12)
	box.add_child(UI.label("Профиль не настроен", &"HeadingLabel", true))
	box.add_child(UI.label("Чтобы рассчитывать стоимость покупок в рабочем времени, укажите доход и рабочий график.", &"CaptionLabel", true))
	box.add_child(UI.button("Пройти настройку", &"PrimaryButton",
		func() -> void: NavigationManager.reset_to("onboarding")))
