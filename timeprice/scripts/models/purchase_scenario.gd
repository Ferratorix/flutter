class_name PurchaseScenario
extends RefCounted
## Результат одного сценария моделирования покупки (см. PurchaseSimulator).
## Все суммы — int в минимальных денежных единицах.

## Через сколько месяцев совершается покупка (0 — сейчас).
var delay_months: int = 0
## Накопления в момент покупки (до неё).
var savings_before_minor: int = 0
## Остаток накоплений сразу после покупки (может быть < 0 — не хватает средств).
var savings_after_minor: int = 0
## Сколько не хватает в момент покупки (0 — хватает).
var shortfall_minor: int = 0
## Через сколько месяцев от сегодняшнего дня накоплений хватит на покупку;
## 0 — хватает уже сейчас; -1 — без регулярных накоплений не накопить.
var months_until_affordable: int = 0
## На сколько месяцев обязательных расходов хватит остатка; -1 — расходы не указаны.
var cushion_months: float = -1.0
## Прогноз накоплений по месяцам: индекс 0 — сейчас, далее — конец каждого месяца.
var projection: Array[int] = []


func is_affordable() -> bool:
	return shortfall_minor == 0


func savings_at_horizon() -> int:
	return projection.back() if not projection.is_empty() else savings_after_minor
