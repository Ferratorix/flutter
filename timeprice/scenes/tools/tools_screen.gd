extends BaseScreen
## Сервисы: депозит, кредит, рассрочка, моделирование покупки, история.

const ITEMS := [
	{"route": "deposit", "icon": "percent", "title": "Депозит",
		"text": "Накопления под проценты: доход, срок до нужной суммы и проценты в рабочем времени."},
	{"route": "loan", "icon": "bank", "title": "Кредит",
		"text": "Платёж, график, переплата и эффективная ставка с учётом комиссий."},
	{"route": "installment", "icon": "card", "title": "Рассрочка",
		"text": "Ежемесячный платёж и скрытая переплата, если при оплате сразу дают скидку."},
	{"route": "simulator", "icon": "trend", "title": "Моделирование покупки",
		"text": "Купить сейчас, через 3 или 6 месяцев: прогноз накоплений и влияние на цель."},
	{"route": "history", "icon": "history", "title": "История расчётов",
		"text": "Сохранённые расчёты стоимости покупок в рабочем времени."},
]


func _ready() -> void:
	build_scroll_layout()
	content.add_child(UI.top_bar("Сервисы"))
	content.add_child(UI.label("Все расчёты выполняются на устройстве и показывают суммы ещё и в вашем рабочем времени.", &"CaptionLabel", true))
	for item in ITEMS:
		var route: String = item["route"]
		var box := UI.tap_card(content, func() -> void: NavigationManager.push(route), 0)
		var row := UI.hbox(14)
		box.add_child(row)
		row.add_child(UI.icon_badge(item["icon"], 44.0))
		var col := UI.vbox(2)
		row.add_child(col)
		col.add_child(UI.label(item["title"], &"ValueLabel", true))
		col.add_child(UI.label(item["text"], &"CaptionLabel", true))
		var chevron := IconLibrary.rect("chevron_right", 18.0, AppTheme.TEXT_MUTED)
		chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chevron)
		UI.pass_through(box)
