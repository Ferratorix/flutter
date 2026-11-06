class_name CashbackCalculator
extends RefCounted
## Кэшбэк: сколько реально вернётся с учётом лимита в месяц и стоимости карты.


## rows: [{"spend_minor": int, "rate_h": int}] — траты в месяц и процент кэшбэка (сотые доли).
## monthly_cap_minor: лимит кэшбэка в месяц (0 — без лимита). annual_fee_minor — плата за обслуживание в год.
## Результат: ok, monthly_spend, monthly_raw, monthly_cashback (после лимита), capped (bool),
## yearly_cashback, yearly_net (минус обслуживание), effective_rate (% от трат, может быть < 0).
static func calculate(rows: Array, monthly_cap_minor: int = 0, annual_fee_minor: int = 0) -> Dictionary:
	var result := {"ok": false}
	if monthly_cap_minor < 0 or annual_fee_minor < 0:
		return result
	var spend := 0
	var raw := 0
	for row in rows:
		var s: int = int(row.get("spend_minor", 0))
		var r: int = int(row.get("rate_h", 0))
		if s < 0 or s > Money.MAX_MINOR / 100 or r < 0 or r > 10_000:
			return result
		spend += s
		raw += FinanceMath.percent_of(s, r)
	if spend <= 0:
		return result
	var cashback := mini(raw, monthly_cap_minor) if monthly_cap_minor > 0 else raw
	var yearly := cashback * 12
	var net := yearly - annual_fee_minor
	result["monthly_spend"] = spend
	result["monthly_raw"] = raw
	result["monthly_cashback"] = cashback
	result["capped"] = monthly_cap_minor > 0 and raw > monthly_cap_minor
	result["yearly_cashback"] = yearly
	result["yearly_net"] = net
	result["effective_rate"] = float(net) * 100.0 / float(spend * 12)
	result["ok"] = true
	return result
