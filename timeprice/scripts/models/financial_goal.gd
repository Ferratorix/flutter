class_name FinancialGoal
extends RefCounted
## Финансовая цель: целевая сумма, накоплено, регулярный взнос и журнал изменений.
## Журнал используется для отображения пополнений и динамики накоплений.

const MAX_TITLE_LENGTH := 60
const MAX_ENTRIES := 1000

const KIND_INITIAL := "initial"
const KIND_DEPOSIT := "deposit"
const KIND_EDIT := "edit"

var id: String = ""
var title: String = ""
var target_minor: int = 0
var saved_minor: int = 0
var monthly_contribution_minor: int = 0
var currency: String = Currency.DEFAULT_CODE
var is_primary: bool = false
var created_at: int = 0
var updated_at: int = 0
## [{"kind": String, "delta_minor": int, "saved_minor": int, "at": int}]
var entries: Array[Dictionary] = []


static func create(p_title: String, p_target: int, p_saved: int, p_monthly: int, p_currency: String) -> FinancialGoal:
	var g := FinancialGoal.new()
	g.id = DataUtil.new_id()
	g.title = p_title.strip_edges().substr(0, MAX_TITLE_LENGTH)
	g.target_minor = p_target
	g.saved_minor = maxi(p_saved, 0)
	g.monthly_contribution_minor = maxi(p_monthly, 0)
	g.currency = p_currency
	g.created_at = DataUtil.now()
	g.updated_at = g.created_at
	g._add_entry(KIND_INITIAL, g.saved_minor)
	return g


func is_valid() -> bool:
	return not id.is_empty() and not title.is_empty() \
		and target_minor > 0 and target_minor <= Money.MAX_MINOR \
		and saved_minor >= 0 and saved_minor <= Money.MAX_MINOR \
		and monthly_contribution_minor >= 0 and monthly_contribution_minor <= Money.MAX_MINOR \
		and Currency.is_supported(currency)


func is_completed() -> bool:
	return target_minor > 0 and saved_minor >= target_minor


func remaining_minor() -> int:
	return FinancialCalculator.goal_remaining(saved_minor, target_minor)


func progress_percent() -> float:
	return FinancialCalculator.goal_progress(saved_minor, target_minor)


func months_left() -> int:
	return FinancialCalculator.months_to_goal(remaining_minor(), monthly_contribution_minor)


## Оставшаяся сумма в рабочих минутах по текущему профилю; -1 — нельзя посчитать.
func remaining_work_minutes(profile: UserProfile) -> int:
	if profile == null or not profile.is_valid() or profile.currency != currency:
		return -1
	var remaining := remaining_minor()
	if remaining <= 0:
		return 0
	return FinancialCalculator.purchase_minutes(remaining, profile.monthly_income_minor,
		profile.working_days, profile.work_minutes_per_day)


## Пополнение. false — некорректная сумма.
func add_contribution(amount_minor: int) -> bool:
	if amount_minor <= 0 or amount_minor > Money.MAX_MINOR:
		return false
	var before := saved_minor
	saved_minor = mini(saved_minor + amount_minor, Money.MAX_MINOR)
	_add_entry(KIND_DEPOSIT, saved_minor - before)
	return true


## Прямое изменение накопленной суммы (при редактировании цели).
func set_saved(new_saved_minor: int) -> void:
	var value := clampi(new_saved_minor, 0, Money.MAX_MINOR)
	if value == saved_minor:
		return
	var delta := value - saved_minor
	saved_minor = value
	_add_entry(KIND_EDIT, delta)


func copy() -> FinancialGoal:
	return FinancialGoal.from_dict(to_dict())


func _add_entry(kind: String, delta: int) -> void:
	updated_at = DataUtil.now()
	entries.append({"kind": kind, "delta_minor": delta, "saved_minor": saved_minor, "at": updated_at})
	if entries.size() > MAX_ENTRIES:
		entries = entries.slice(entries.size() - MAX_ENTRIES)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"target_minor": target_minor,
		"saved_minor": saved_minor,
		"monthly_contribution_minor": monthly_contribution_minor,
		"currency": currency,
		"is_primary": is_primary,
		"created_at": created_at,
		"updated_at": updated_at,
		"entries": entries.duplicate(true),
	}


## null, если запись повреждена.
static func from_dict(data: Dictionary) -> FinancialGoal:
	var g := FinancialGoal.new()
	g.id = DataUtil.get_string(data, "id", "", 64)
	g.title = DataUtil.get_string(data, "title", "", MAX_TITLE_LENGTH)
	g.target_minor = DataUtil.get_int(data, "target_minor", 0, 0, Money.MAX_MINOR)
	g.saved_minor = DataUtil.get_int(data, "saved_minor", 0, 0, Money.MAX_MINOR)
	g.monthly_contribution_minor = DataUtil.get_int(data, "monthly_contribution_minor", 0, 0, Money.MAX_MINOR)
	var code := DataUtil.get_string(data, "currency", Currency.DEFAULT_CODE, 8)
	g.currency = code if Currency.is_supported(code) else Currency.DEFAULT_CODE
	g.is_primary = DataUtil.get_bool(data, "is_primary", false)
	g.created_at = DataUtil.get_int(data, "created_at", 0, 0, 1 << 40)
	g.updated_at = DataUtil.get_int(data, "updated_at", g.created_at, 0, 1 << 40)
	for e in DataUtil.get_array(data, "entries"):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var kind := DataUtil.get_string(e, "kind", "", 16)
		if not [KIND_INITIAL, KIND_DEPOSIT, KIND_EDIT].has(kind):
			continue
		g.entries.append({
			"kind": kind,
			"delta_minor": DataUtil.get_int(e, "delta_minor", 0, -Money.MAX_MINOR, Money.MAX_MINOR),
			"saved_minor": DataUtil.get_int(e, "saved_minor", 0, 0, Money.MAX_MINOR),
			"at": DataUtil.get_int(e, "at", 0, 0, 1 << 40),
		})
	if g.entries.size() > MAX_ENTRIES:
		g.entries = g.entries.slice(g.entries.size() - MAX_ENTRIES)
	return g if g.is_valid() else null
