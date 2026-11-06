extends TestCase
## Резервная копия: формат, проверка, совместимость; запись поверх существующего файла.

const PATH := "user://test_backup_storage.json"
const BACKUP := "user://test_backup_storage.backup.json"


func after_each() -> void:
	for p in [PATH, BACKUP, PATH + ".tmp"]:
		JsonStorage.remove(p)


func _snapshot() -> Dictionary:
	var p := UserProfile.new()
	p.monthly_income_minor = 40_000_000
	p.savings_minor = 10_000_000
	p.onboarding_completed = true
	var goal := FinancialGoal.create("Отпуск", 150_000_000, 30_000_000, 10_000_000, "KZT")
	var wish := WishlistItem.create("Наушники", 6_500_000, "KZT")
	wish.resolve(WishlistItem.STATUS_DECLINED, 1_800_000_000)
	var item := Purchase.create("Смартфон", 35_000_000, "KZT", 0, 35_000_000, p)
	return {"schema_version": 3, "profile": p.to_dict(), "history": [item.to_dict()],
		"goals": [goal.to_dict()], "wishlist": [wish.to_dict()]}


func test_roundtrip() -> void:
	var settings := {"reduce_motion": true, "tool_inputs": {"deposit": {"rate": 1450}}}
	var text := BackupService.to_text(BackupService.compose(_snapshot(), settings, "1.0.0", 1_800_000_000))
	var r := BackupService.parse(text, 3)
	assert_true(r["ok"], str(r["error"]))
	assert_eq(r["summary"]["goals"], 1)
	assert_eq(r["summary"]["wishlist"], 1)
	assert_eq(r["summary"]["history"], 1)
	assert_true(r["summary"]["has_profile"])
	assert_eq(int(r["summary"]["created_at"]), 1_800_000_000)
	# Данные восстанавливаются моделями без потерь.
	var data: Dictionary = r["data"]
	var profile := UserProfile.from_dict(data["profile"])
	assert_eq(profile.monthly_income_minor, 40_000_000)
	assert_eq(profile.savings_minor, 10_000_000)
	var wish := WishlistItem.from_dict(data["wishlist"][0])
	assert_eq(wish.status, WishlistItem.STATUS_DECLINED)
	assert_eq(int(r["settings"]["tool_inputs"]["deposit"]["rate"]), 1450)


func test_rejects_foreign_and_broken_files() -> void:
	assert_eq(BackupService.parse("", 3)["error"], BackupService.ERROR_EMPTY)
	assert_eq(BackupService.parse("{broken", 3)["error"], BackupService.ERROR_NOT_JSON)
	assert_eq(BackupService.parse("[1,2]", 3)["error"], BackupService.ERROR_NOT_JSON)
	assert_eq(BackupService.parse("{\"format\": \"other\"}", 3)["error"], BackupService.ERROR_WRONG_FORMAT)
	# Файл данных приложения без заголовка — не копия.
	assert_eq(BackupService.parse(JSON.stringify(_snapshot()), 3)["error"], BackupService.ERROR_WRONG_FORMAT)
	var empty := BackupService.compose({"schema_version": 3, "profile": {}}, {}, "1.0.0", 1)
	assert_eq(BackupService.parse(BackupService.to_text(empty), 3)["error"], BackupService.ERROR_NO_DATA)


func test_rejects_newer_versions() -> void:
	var newer_schema := BackupService.compose(_snapshot(), {}, "9.0.0", 1)
	newer_schema["data"]["schema_version"] = 99
	assert_eq(BackupService.parse(BackupService.to_text(newer_schema), 3)["error"], BackupService.ERROR_NEWER_VERSION)
	var newer_format := BackupService.compose(_snapshot(), {}, "9.0.0", 1)
	newer_format["backup_version"] = 2
	assert_eq(BackupService.parse(BackupService.to_text(newer_format), 3)["error"], BackupService.ERROR_NEWER_VERSION)


func test_accepts_older_schema() -> void:
	var old := _snapshot()
	old["schema_version"] = 1
	old.erase("goals")
	old.erase("wishlist")
	var r := BackupService.parse(BackupService.to_text(BackupService.compose(old, {}, "0.1.0", 1)), 3)
	assert_true(r["ok"])
	assert_eq(r["summary"]["goals"], 0)


func test_default_file_name() -> void:
	assert_eq(BackupService.default_file_name(1_762_387_200), "timeprice-backup-2025-11-06.json")


func test_overwrite_keeps_backup_and_ignores_stale_tmp() -> void:
	assert_eq(JsonStorage.write_atomic(PATH, {"v": 1}, BACKUP), OK)
	# «Хвост» от прерванной записи не мешает следующей.
	var stale := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	stale.store_string("{обрыв")
	stale.close()
	assert_eq(JsonStorage.write_atomic(PATH, {"v": 2}, BACKUP), OK)
	assert_eq(int(JsonStorage.read(PATH)["data"]["v"]), 2)
	assert_eq(int(JsonStorage.read(BACKUP)["data"]["v"]), 1)
	assert_false(FileAccess.file_exists(PATH + ".tmp"))
