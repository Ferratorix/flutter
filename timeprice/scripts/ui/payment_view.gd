class_name PaymentView
extends RefCounted
## Общие блоки для кредита и рассрочки: платёж относительно дохода и рабочего времени.

## Порог долговой нагрузки, после которого показывается предупреждение (50 % дохода).
const HIGH_BURDEN_PERCENT := 50.0


static func burden_card(parent: Control, payment_minor: int, total_minor: int, overpayment_minor: int) -> void:
	var profile := DataManager.profile
	if not profile.is_valid():
		return
	var code := profile.currency
	var box := UI.card(parent, &"Card", 10)
	box.add_child(UI.label("В рабочем времени", &"HeadingLabel"))
	var p := profile.calculate(payment_minor)
	if p["ok"]:
		box.add_child(UI.kv_row("Ежемесячный платёж", Fmt.duration(p["total_minutes"])))
		var pct: float = p["income_percentage"]
		box.add_child(UI.kv_row("Доля месячного дохода", Fmt.percent(pct)))
		box.add_child(UI.progress_bar(minf(pct, 100.0)))
		if pct >= HIGH_BURDEN_PERCENT:
			box.add_child(UI.label(Loc.tf("Платёж занимает %s дохода. Банки обычно считают нагрузку выше 50 %% высокой — учтите обязательные расходы.", [Fmt.percent(pct)]), &"ErrorLabel", true))
	if overpayment_minor > 0:
		var o := profile.calculate(overpayment_minor)
		if o["ok"]:
			box.add_child(UI.separator())
			box.add_child(UI.kv_row("Переплата", Fmt.money(overpayment_minor, code)))
			box.add_child(UI.label(Loc.tf("Это %s вашей работы — %s.", [Fmt.duration(o["total_minutes"]), Fmt.work_days(o["days"])]), &"AccentLabel", true))
	var t := profile.calculate(total_minor)
	if t["ok"]:
		box.add_child(UI.label(Loc.tf("Всего придётся отдать %s — это %s.", [Fmt.money(total_minor, code), Fmt.work_days(t["days"])]), &"MutedLabel", true))
