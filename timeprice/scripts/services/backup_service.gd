class_name BackupService
extends RefCounted
## Резервная копия данных в файл, выбранный пользователем (экспорт и импорт).
##
## Файл — обычный JSON в формате хранения TIMEPRICE с заголовком. Он не
## шифруется: приложение предупреждает об этом пользователя. Сеть не используется —
## файл сохраняется туда, куда укажет пользователь в системном окне Android.

const FORMAT := "timeprice-backup"
const BACKUP_VERSION := 1
const MAX_FILE_BYTES := 20 * 1024 * 1024

const ERROR_NONE := ""
const ERROR_EMPTY := "empty"
const ERROR_TOO_LARGE := "too_large"
const ERROR_NOT_JSON := "not_json"
const ERROR_WRONG_FORMAT := "wrong_format"
const ERROR_NEWER_VERSION := "newer_version"
const ERROR_NO_DATA := "no_data"


## Собирает копию из снимка данных и настроек.
static func compose(data_snapshot: Dictionary, settings: Dictionary, app_version: String, now: int) -> Dictionary:
	return {
		"format": FORMAT,
		"backup_version": BACKUP_VERSION,
		"app_version": app_version,
		"created_at": now,
		"data": data_snapshot,
		"settings": settings,
	}


static func to_text(backup: Dictionary) -> String:
	return JSON.stringify(backup, "\t")


## Проверяет файл копии. Результат: ok, error, data, settings, summary.
## summary: created_at, has_profile, goals, wishlist, history, currency.
static func parse(text: String, max_schema_version: int) -> Dictionary:
	var result := {"ok": false, "error": ERROR_NONE, "data": {}, "settings": {}, "summary": {}}
	if text.strip_edges().is_empty():
		result["error"] = ERROR_EMPTY
		return result
	if text.length() > MAX_FILE_BYTES:
		result["error"] = ERROR_TOO_LARGE
		return result
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		result["error"] = ERROR_NOT_JSON
		return result
	var root: Dictionary = json.data
	if DataUtil.get_string(root, "format", "", 64) != FORMAT:
		result["error"] = ERROR_WRONG_FORMAT
		return result
	if DataUtil.get_int(root, "backup_version", 0, 0, 1000) > BACKUP_VERSION:
		result["error"] = ERROR_NEWER_VERSION
		return result
	var data := DataUtil.get_dict(root, "data")
	if data.is_empty():
		result["error"] = ERROR_NO_DATA
		return result
	if DataUtil.get_int(data, "schema_version", 0, 0, 100_000) > max_schema_version:
		result["error"] = ERROR_NEWER_VERSION
		return result
	var profile := UserProfile.from_dict(DataUtil.get_dict(data, "profile"))
	result["summary"] = {
		"created_at": DataUtil.get_int(root, "created_at", 0, 0, 1 << 40),
		"has_profile": profile.is_valid(),
		"currency": profile.currency,
		"goals": _count_valid(DataUtil.get_array(data, "goals"), "goal"),
		"wishlist": _count_valid(DataUtil.get_array(data, "wishlist"), "wish"),
		"history": _count_valid(DataUtil.get_array(data, "history"), "purchase"),
	}
	if not profile.is_valid() and result["summary"]["goals"] == 0 \
			and result["summary"]["wishlist"] == 0 and result["summary"]["history"] == 0:
		result["error"] = ERROR_NO_DATA
		return result
	result["data"] = data
	result["settings"] = DataUtil.get_dict(root, "settings")
	result["ok"] = true
	return result


static func error_message(code: String) -> String:
	match code:
		ERROR_EMPTY:
			return Loc.t("Файл пустой.")
		ERROR_TOO_LARGE:
			return Loc.t("Файл слишком большой для резервной копии TIMEPRICE.")
		ERROR_NOT_JSON, ERROR_WRONG_FORMAT:
			return Loc.t("Это не файл резервной копии TIMEPRICE.")
		ERROR_NEWER_VERSION:
			return Loc.t("Копия создана более новой версией приложения. Обновите TIMEPRICE и повторите.")
		ERROR_NO_DATA:
			return Loc.t("В файле нет данных для восстановления.")
	return Loc.t("Не удалось прочитать файл.")


## Имя файла по умолчанию: timeprice-backup-2026-11-06.json
static func default_file_name(now: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(now)
	return "timeprice-backup-%04d-%02d-%02d.json" % [d["year"], d["month"], d["day"]]


static func _count_valid(items: Array, kind: String) -> int:
	var n := 0
	for e in items:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var ok := false
		match kind:
			"goal":
				ok = FinancialGoal.from_dict(e) != null
			"wish":
				ok = WishlistItem.from_dict(e) != null
			"purchase":
				ok = Purchase.from_dict(e) != null
		if ok:
			n += 1
	return n
