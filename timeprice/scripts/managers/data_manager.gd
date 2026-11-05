extends Node
## Хранилище пользовательских данных: профиль и история расчётов.
##
## Данные сохраняются в user://timeprice_data.json сразу после каждого
## изменения. При повреждении основного файла используется резервная копия;
## если и она недоступна, повреждённый файл переименовывается (не удаляется),
## а приложение запускается с чистыми данными и сообщает об этом.

signal profile_changed
signal history_changed
signal goals_changed
signal wishlist_changed
signal data_reset
signal save_failed

const DATA_PATH := "user://timeprice_data.json"
const BACKUP_PATH := "user://timeprice_data.backup.json"
## v1 — профиль и история; v2 — добавлены цели и список желаний.
const SCHEMA_VERSION := 2
const MAX_HISTORY := 500
const MAX_GOALS := 100
const MAX_WISHLIST := 500

var profile: UserProfile = UserProfile.new()
var history: Array[Purchase] = []
var goals: Array[FinancialGoal] = []
var wishlist: Array[WishlistItem] = []
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
	var goal_items: Array = []
	for goal in goals:
		goal_items.append(goal.to_dict())
	var wish_items: Array = []
	for wish in wishlist:
		wish_items.append(wish.to_dict())
	var data := {
		"schema_version": SCHEMA_VERSION,
		"app_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved_at": DataUtil.now(),
		"profile": profile.to_dict(),
		"history": items,
		"goals": goal_items,
		"wishlist": wish_items,
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


# --- Финансовые цели -------------------------------------------------------

func find_goal(id: String) -> FinancialGoal:
	for g in goals:
		if g.id == id:
			return g
	return null


## Основная цель (показывается на главной) или null.
func get_primary_goal() -> FinancialGoal:
	for g in goals:
		if g.is_primary:
			return g
	return null


func can_add_goal() -> bool:
	return goals.size() < MAX_GOALS


func add_goal(goal: FinancialGoal) -> bool:
	if goal == null or not goal.is_valid() or not can_add_goal():
		return false
	if get_primary_goal() == null:
		goal.is_primary = true
	goals.append(goal)
	return _commit_goals()


## Заменяет цель с тем же id.
func update_goal(goal: FinancialGoal) -> bool:
	if goal == null or not goal.is_valid():
		return false
	for i in goals.size():
		if goals[i].id == goal.id:
			goals[i] = goal
			return _commit_goals()
	return false


func remove_goal(id: String) -> bool:
	for i in goals.size():
		if goals[i].id == id:
			goals.remove_at(i)
			return _commit_goals()
	return false


func set_primary_goal(id: String) -> bool:
	if find_goal(id) == null:
		return false
	for g in goals:
		g.is_primary = g.id == id
	return _commit_goals()


func _commit_goals() -> bool:
	_normalize_primary_goal()
	var ok := save()
	goals_changed.emit()
	return ok


## Ровно одна основная цель, если цели есть.
func _normalize_primary_goal() -> void:
	var found := false
	for g in goals:
		if g.is_primary:
			if found:
				g.is_primary = false
			found = true
	if not found and not goals.is_empty():
		goals[0].is_primary = true


# --- Список желаний --------------------------------------------------------

func find_wishlist_item(id: String) -> WishlistItem:
	for w in wishlist:
		if w.id == id:
			return w
	return null


func can_add_wishlist_item() -> bool:
	return wishlist.size() < MAX_WISHLIST


func add_wishlist_item(item: WishlistItem) -> bool:
	if item == null or not item.is_valid() or not can_add_wishlist_item():
		return false
	wishlist.push_front(item)
	return _commit_wishlist()


func update_wishlist_item(item: WishlistItem) -> bool:
	if item == null or not item.is_valid():
		return false
	for i in wishlist.size():
		if wishlist[i].id == item.id:
			item.updated_at = DataUtil.now()
			wishlist[i] = item
			return _commit_wishlist()
	return false


func remove_wishlist_item(id: String) -> bool:
	for i in wishlist.size():
		if wishlist[i].id == id:
			wishlist.remove_at(i)
			return _commit_wishlist()
	return false


func _commit_wishlist() -> bool:
	var ok := save()
	wishlist_changed.emit()
	return ok


# --- Сброс -----------------------------------------------------------------

## Полное удаление данных пользователя с устройства.
func reset_all() -> bool:
	JsonStorage.remove(BACKUP_PATH)
	JsonStorage.remove(DATA_PATH)
	profile = UserProfile.new()
	history.clear()
	goals.clear()
	wishlist.clear()
	SettingsManager.reset()
	var ok := save()
	# Резервная копия «пустого» состояния не нужна.
	JsonStorage.remove(BACKUP_PATH)
	data_reset.emit()
	profile_changed.emit()
	history_changed.emit()
	goals_changed.emit()
	wishlist_changed.emit()
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
	goals.clear()
	for entry in DataUtil.get_array(data, "goals"):
		if typeof(entry) == TYPE_DICTIONARY and goals.size() < MAX_GOALS:
			var goal := FinancialGoal.from_dict(entry)
			if goal != null:
				goals.append(goal)
	_normalize_primary_goal()
	wishlist.clear()
	for entry in DataUtil.get_array(data, "wishlist"):
		if typeof(entry) == TYPE_DICTIONARY and wishlist.size() < MAX_WISHLIST:
			var wish := WishlistItem.from_dict(entry)
			if wish != null:
				wishlist.append(wish)


## Точка расширения для будущих версий формата данных.
func _migrate(data: Dictionary) -> Dictionary:
	var version := DataUtil.get_int(data, "schema_version", SCHEMA_VERSION, 0, 1000)
	if version > SCHEMA_VERSION:
		push_warning("Данные созданы более новой версией приложения (схема %d)." % version)
	# v1 -> v2: новых обязательных полей нет, цели и желания начинаются с пустых списков.
	if version < 2:
		data["goals"] = DataUtil.get_array(data, "goals")
		data["wishlist"] = DataUtil.get_array(data, "wishlist")
	return data


func _preserve_corrupted_file() -> void:
	var target := "user://timeprice_data.corrupted_%d.json" % DataUtil.now()
	if DirAccess.rename_absolute(DATA_PATH, target) != OK:
		JsonStorage.remove(DATA_PATH)
