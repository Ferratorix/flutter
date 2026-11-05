class_name ScheduleView
extends RefCounted
## График платежей: первые строки и кнопка «Показать весь график».

const PREVIEW_ROWS := 6


static func build(parent: Control, rows: Array, currency_code: String, show_interest: bool = true) -> void:
	var box := UI.card(parent, &"Card", 6)
	box.add_child(UI.label("График платежей", &"HeadingLabel"))
	var list := UI.vbox(6)
	box.add_child(list)
	_fill(list, rows, currency_code, show_interest, mini(PREVIEW_ROWS, rows.size()))
	if rows.size() > PREVIEW_ROWS:
		var more := UI.button(Loc.tf("Показать весь график (%d)", [rows.size()]), &"GhostButton")
		more.custom_minimum_size.y = 40
		more.pressed.connect(func() -> void:
			UI.clear_children(list)
			_fill(list, rows, currency_code, show_interest, rows.size())
			more.queue_free())
		box.add_child(more)


static func _fill(list: VBoxContainer, rows: Array, currency_code: String, show_interest: bool, count: int) -> void:
	for i in count:
		var row: Dictionary = rows[i]
		if i > 0:
			list.add_child(UI.separator())
		var head := UI.hbox(8)
		list.add_child(head)
		var month_label := UI.label(Loc.tf("%d-й месяц", [int(row["month"])]), &"")
		month_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(month_label)
		var pay := UI.label(Fmt.money(int(row["payment"]), currency_code), &"")
		pay.add_theme_font_override("font", AppTheme.bold_font())
		head.add_child(pay)
		var details := ""
		if show_interest:
			details = Loc.tf("долг %s · проценты %s · остаток %s", [
				Fmt.money(int(row["principal"]), currency_code),
				Fmt.money(int(row["interest"]), currency_code),
				Fmt.money(int(row["balance"]), currency_code)])
		else:
			details = Loc.tf("остаток %s", [Fmt.money(int(row["balance"]), currency_code)])
		list.add_child(UI.label(details, &"MutedLabel", true))
