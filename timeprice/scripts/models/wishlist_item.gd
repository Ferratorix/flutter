class_name WishlistItem
extends RefCounted
## Желание: покупка, которую пользователь планирует.
##
## Цена хранится в валюте профиля. Если желание добавлено из калькулятора
## в другой валюте, исходная цена сохраняется только для отображения.
## Рабочее время считается по текущему профилю — список смотрит в будущее.

const MAX_TITLE_LENGTH := 80

const PRIORITY_HIGH := 1
const PRIORITY_MEDIUM := 2
const PRIORITY_LOW := 3
const PRIORITY_NAMES := {1: "Высокий", 2: "Средний", 3: "Низкий"}

const DEFAULT_CATEGORY := "other"
const CATEGORY_ORDER := ["tech", "clothes", "home", "transport", "travel", "fun",
	"health", "education", "gifts", "other"]
const CATEGORY_NAMES := {
	"tech": "Техника",
	"clothes": "Одежда и обувь",
	"home": "Дом",
	"transport": "Транспорт",
	"travel": "Путешествия",
	"fun": "Развлечения",
	"health": "Здоровье",
	"education": "Образование",
	"gifts": "Подарки",
	"other": "Другое",
}

const SORT_PRIORITY := "priority"
const SORT_NEWEST := "newest"
const SORT_PRICE_DESC := "price_desc"
const SORT_PRICE_ASC := "price_asc"
const SORT_ORDER := [SORT_PRIORITY, SORT_NEWEST, SORT_PRICE_DESC, SORT_PRICE_ASC]
const SORT_NAMES := {
	"priority": "Сначала важные",
	"newest": "Сначала новые",
	"price_desc": "Сначала дорогие",
	"price_asc": "Сначала недорогие",
}

var id: String = ""
var title: String = ""
var price_minor: int = 0
var currency: String = Currency.DEFAULT_CODE
## Исходная цена в другой валюте (0 / "" — нет).
var original_price_minor: int = 0
var original_currency: String = ""
var category: String = DEFAULT_CATEGORY
var priority: int = PRIORITY_MEDIUM
var created_at: int = 0
var updated_at: int = 0


static func create(p_title: String, p_price: int, p_currency: String, p_category: String = DEFAULT_CATEGORY,
		p_priority: int = PRIORITY_MEDIUM) -> WishlistItem:
	var item := WishlistItem.new()
	item.id = DataUtil.new_id()
	item.title = p_title.strip_edges().substr(0, MAX_TITLE_LENGTH)
	item.price_minor = p_price
	item.currency = p_currency
	item.category = p_category if CATEGORY_NAMES.has(p_category) else DEFAULT_CATEGORY
	item.priority = clampi(p_priority, PRIORITY_HIGH, PRIORITY_LOW)
	item.created_at = DataUtil.now()
	item.updated_at = item.created_at
	return item


static func category_name(key: String) -> String:
	return Loc.t(CATEGORY_NAMES.get(key, CATEGORY_NAMES[DEFAULT_CATEGORY]))


static func priority_name(value: int) -> String:
	return Loc.t(PRIORITY_NAMES.get(value, PRIORITY_NAMES[PRIORITY_MEDIUM]))


func is_valid() -> bool:
	return not id.is_empty() and not title.is_empty() and FinancialCalculator.is_price_valid(price_minor) \
		and Currency.is_supported(currency) and CATEGORY_NAMES.has(category) \
		and priority >= PRIORITY_HIGH and priority <= PRIORITY_LOW


func has_original_price() -> bool:
	return original_price_minor > 0 and Currency.is_supported(original_currency) and original_currency != currency


## Результат по текущему профилю. ok = false, если валюта профиля изменилась.
func result(profile: UserProfile) -> Dictionary:
	if profile == null or profile.currency != currency:
		return {"ok": false, "error": "currency_mismatch"}
	return profile.calculate(price_minor)


func copy() -> WishlistItem:
	return WishlistItem.from_dict(to_dict())


## Сортировка без изменения исходного массива.
static func sorted(items: Array, mode: String) -> Array:
	var out := items.duplicate()
	match mode:
		SORT_NEWEST:
			out.sort_custom(func(a: WishlistItem, b: WishlistItem) -> bool:
				return a.created_at > b.created_at if a.created_at != b.created_at else a.id > b.id)
		SORT_PRICE_DESC:
			out.sort_custom(func(a: WishlistItem, b: WishlistItem) -> bool:
				return a.price_minor > b.price_minor if a.price_minor != b.price_minor else a.created_at > b.created_at)
		SORT_PRICE_ASC:
			out.sort_custom(func(a: WishlistItem, b: WishlistItem) -> bool:
				return a.price_minor < b.price_minor if a.price_minor != b.price_minor else a.created_at > b.created_at)
		_:
			out.sort_custom(func(a: WishlistItem, b: WishlistItem) -> bool:
				return a.priority < b.priority if a.priority != b.priority else a.created_at > b.created_at)
	return out


## Сумма цен желаний в указанной валюте (желания в других валютах не учитываются).
static func total_price(items: Array, currency_code: String) -> int:
	var total := 0
	for item in items:
		var w := item as WishlistItem
		if w != null and w.currency == currency_code:
			total = mini(total + w.price_minor, Money.MAX_MINOR)
	return total


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"price_minor": price_minor,
		"currency": currency,
		"original_price_minor": original_price_minor,
		"original_currency": original_currency,
		"category": category,
		"priority": priority,
		"created_at": created_at,
		"updated_at": updated_at,
	}


static func from_dict(data: Dictionary) -> WishlistItem:
	var item := WishlistItem.new()
	item.id = DataUtil.get_string(data, "id", "", 64)
	item.title = DataUtil.get_string(data, "title", "", MAX_TITLE_LENGTH)
	item.price_minor = DataUtil.get_int(data, "price_minor", 0, 0, Money.MAX_MINOR)
	var code := DataUtil.get_string(data, "currency", Currency.DEFAULT_CODE, 8)
	item.currency = code if Currency.is_supported(code) else Currency.DEFAULT_CODE
	item.original_price_minor = DataUtil.get_int(data, "original_price_minor", 0, 0, Money.MAX_MINOR)
	item.original_currency = DataUtil.get_string(data, "original_currency", "", 8)
	var cat := DataUtil.get_string(data, "category", DEFAULT_CATEGORY, 16)
	item.category = cat if CATEGORY_NAMES.has(cat) else DEFAULT_CATEGORY
	item.priority = DataUtil.get_int(data, "priority", PRIORITY_MEDIUM, PRIORITY_HIGH, PRIORITY_LOW)
	item.created_at = DataUtil.get_int(data, "created_at", 0, 0, 1 << 40)
	item.updated_at = DataUtil.get_int(data, "updated_at", item.created_at, 0, 1 << 40)
	return item if item.is_valid() else null
