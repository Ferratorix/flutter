extends TestCase
## Проверка записи, чтения, резервной копии и обработки повреждённых файлов.

const PATH := "user://test_storage.json"
const BACKUP := "user://test_storage.backup.json"


func before_each() -> void:
	_cleanup()


func after_each() -> void:
	_cleanup()


func _cleanup() -> void:
	for p in [PATH, BACKUP, PATH + ".tmp"]:
		JsonStorage.remove(p)


func test_missing_file() -> void:
	assert_eq(JsonStorage.read(PATH)["status"], JsonStorage.Status.NOT_FOUND)


func test_write_and_read() -> void:
	var err := JsonStorage.write_atomic(PATH, {"a": 1, "text": "тенге ₸"}, BACKUP)
	assert_eq(err, OK)
	var r := JsonStorage.read(PATH)
	assert_eq(r["status"], JsonStorage.Status.LOADED)
	assert_eq(int(r["data"]["a"]), 1)
	assert_eq(r["data"]["text"], "тенге ₸")
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "временный файл удалён")


func test_backup_keeps_previous_version() -> void:
	JsonStorage.write_atomic(PATH, {"v": 1}, BACKUP)
	JsonStorage.write_atomic(PATH, {"v": 2}, BACKUP)
	assert_eq(int(JsonStorage.read(PATH)["data"]["v"]), 2)
	assert_eq(int(JsonStorage.read(BACKUP)["data"]["v"]), 1)


func test_corrupted_file_detected() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{\"profile\": {\"monthly_inc")
	f.close()
	assert_eq(JsonStorage.read(PATH)["status"], JsonStorage.Status.CORRUPTED)


func test_non_object_json_is_corrupted() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[1, 2, 3]")
	f.close()
	assert_eq(JsonStorage.read(PATH)["status"], JsonStorage.Status.CORRUPTED)


func test_empty_file_is_corrupted() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.close()
	assert_eq(JsonStorage.read(PATH)["status"], JsonStorage.Status.CORRUPTED)


func test_full_profile_persistence_cycle() -> void:
	var p := UserProfile.new()
	p.monthly_income_minor = 40_000_000
	p.savings_minor = 10_000_000
	p.onboarding_completed = true
	var item := Purchase.create("Смартфон", 35_000_000, "KZT", 0, 35_000_000, p)
	JsonStorage.write_atomic(PATH, {"profile": p.to_dict(), "history": [item.to_dict()]}, BACKUP)
	var data: Dictionary = JsonStorage.read(PATH)["data"]
	var restored := UserProfile.from_dict(data["profile"])
	assert_true(restored.same_settings_as(p))
	assert_true(restored.is_ready())
	var restored_item := Purchase.from_dict(data["history"][0])
	assert_not_null(restored_item)
	assert_eq(restored_item.title, "Смартфон")
