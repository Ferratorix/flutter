extends Node
## Хранилище пользовательских данных: профиль и история расчётов.
##
## Данные сохраняются в user://timeprice_data.json сразу после каждого
## изменения. При повреждении основного файла используется резервная копия;
## если и она недоступна, повреждённый файл переименовывается (не удаляется),
## а приложение запускается с чистыми данными и сообщает об этом.

signal profile_changed
signal history_changed
signal data_reset
signal save_failed

const DATA_PATH := "user://timeprice_data.json"
const BACKUP_PATH := "user://timeprice_data.backup.json"
const SCHEMA_VERSION := 1
const MAX_HISTORY := 500

var profile: UserProfile = UserProfile.new()
var history: Array[Purchase] = []
## Сообщение для пользователя о проблемах при загрузке (пусто — всё в порядке).
var load_message: String = ""


func _ready() -> void:
	load_data()


func load_data() -> void:
	load_message = ""
	var main := JsonStorage.read(DATA_PATH)
	if main["status"] == JsonStorage.Status.LOADED:
		_apply(main["data"])
		return
	var backup := JsonStorage.read(BACKUP_PATH)
	var backup_ok: bool = backup["status"] == JsonStorage.Status.LOADED
	if main["status"] == JsonStorage.Status.NOT_FOUND:
		if backup_ok:
			_apply(backup["data"])
			load_message = "Данные восстановлены из резервной копии."
		else:
			_apply({})  # Первый запуск.
		return
	if main["status"] == JsonStorage.Status.CORRUPTED:
		_preserve_corrupted_file()
	if backup_ok:
		_apply(backup["data"])
		load_message = "Файл данных был повреждён. Данные восстановлены из резервной копии."
		save()
	else:
		_apply({})
		load_message = "Не удалось прочитать сохранённые данные. Приложение запущено заново, повреждённый файл сохранён отдельно."


func save() -> bool:
	var items: Array = []
	for item in history:
		items.append(item.to_dict())
	var data := {
		"schema_version": SCHEMA_VERSION,
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved_at": DataUtil.now(),
		"profile": profile.to_dict(),
		"history": items,
	}
	var err := JsonStorage.write_atomic(DATA_PATH, data, BACKUP_PATH)
	if err != OK:
		push_error("Не удалось сохранить данные: %s" % error_string(err))
		save_failed.emit()
		return false
	return true


# --- Профиль ---------------------------------------------------------------

func has_ready_profile() -> bool:
	return profile.is_ready()


func update_profile(new_profile: UserProfile) -> bool:
	if new_profile == null or not new_profile.is_valid():
		return false
	var p := new_profile.copy()
	var now := DataUtil.now()
	if p.created_at == 0:
		p.created_at = now
	p.updated_at = now
	profile = p
	var ok := save()
	profile_changed.emit()
	return ok


# --- История ---------------------------------------------------------------

func add_purchase(item: Purchase) -> bool:
	if item == null or not item.is_valid():
		return false
	history.push_front(item)
	if history.size() > MAX_HISTORY:
		history.resize(MAX_HISTORY)
	var ok := save()
	history_changed.emit()
	return ok


func remove_purchase(id: String) -> bool:
	for i in history.size():
		if history[i].id == id:
			history.remove_at(i)
			var ok := save()
			history_changed.emit()
			return ok
	return false


func clear_history() -> bool:
	history.clear()
	var ok := save()
	history_changed.emit()
	return ok


func get_recent(count: int) -> Array:
	return history.slice(0, maxi(count, 0))


# --- Сброс -----------------------------------------------------------------

## Полное удаление данных пользователя с устройства.
func reset_all() -> bool:
	JsonStorage.remove(BACKUP_PATH)
	JsonStorage.remove(DATA_PATH)
	profile = UserProfile.new()
	history.clear()
	SettingsManager.reset()
	var ok := save()
	# Резервная копия «пустого» состояния не нужна.
	JsonStorage.remove(BACKUP_PATH)
	data_reset.emit()
	profile_changed.emit()
	history_changed.emit()
	return ok


# --- Внутреннее ------------------------------------------------------------

func _apply(data: Dictionary) -> void:
	data = _migrate(data)
	profile = UserProfile.from_dict(DataUtil.get_dict(data, "profile"))
	history.clear()
	for entry in DataUtil.get_array(data, "history"):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item := Purchase.from_dict(entry)
		if item != null:
			history.append(item)
	history.sort_custom(func(a: Purchase, b: Purchase) -> bool: return a.created_at > b.created_at)
	if history.size() > MAX_HISTORY:
		history.resize(MAX_HISTORY)


## Точка расширения для будущих версий формата данных.
func _migrate(data: Dictionary) -> Dictionary:
	var version := DataUtil.get_int(data, "schema_version", SCHEMA_VERSION, 0, 1000)
	if version > SCHEMA_VERSION:
		push_warning("Данные созданы более новой версией приложения (схема %d)." % version)
	return data


func _preserve_corrupted_file() -> void:
	var target := "user://timeprice_data.corrupted_%d.json" % DataUtil.now()
	if DirAccess.rename_absolute(DATA_PATH, target) != OK:
		JsonStorage.remove(DATA_PATH)
