class_name FilePicker
extends RefCounted
## Выбор файла для резервной копии.
## Android: системное окно (Storage Access Framework) — без разрешений на доступ
## к памяти, пользователь сам выбирает место (Загрузки, Google Диск и т. д.).
## Компьютер без системного окна: встроенный FileDialog Godot.


static func has_native() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


## on_selected(path: String) вызывается только при выборе файла.
static func save_file(host: Node, title: String, default_name: String, on_selected: Callable) -> void:
	_show(host, title, default_name, true, on_selected)


static func open_file(host: Node, title: String, on_selected: Callable) -> void:
	_show(host, title, "", false, on_selected)


static func _show(host: Node, title: String, default_name: String, save: bool, on_selected: Callable) -> void:
	if has_native():
		var mode := DisplayServer.FILE_DIALOG_MODE_SAVE_FILE if save else DisplayServer.FILE_DIALOG_MODE_OPEN_FILE
		# При открытии фильтр не задаём: часть файловых менеджеров помечает JSON как
		# «другой тип», и файл не был бы виден. Содержимое проверяется при чтении.
		var filters := PackedStringArray(["*.json"]) if save else PackedStringArray()
		DisplayServer.file_dialog_show(title, "", default_name, false, mode, filters,
			func(status: bool, paths: PackedStringArray, _filter: int) -> void:
				if status and not paths.is_empty():
					on_selected.call(paths[0]))
		return
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	dialog.title = title
	dialog.filters = PackedStringArray(["*.json"])
	dialog.current_file = default_name
	dialog.use_native_dialog = false
	dialog.file_selected.connect(func(path: String) -> void:
		on_selected.call(path)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	host.add_child(dialog)
	dialog.popup_centered_ratio(0.9)


## Запись текста по пути, полученному из окна выбора (может быть content:// на Android).
static func write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var ok := file.store_string(text)
	file.close()
	return OK if ok else ERR_FILE_CANT_WRITE


## Чтение текста: {"ok", "text", "too_large"}.
static func read_text(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "text": "", "too_large": false}
	if file.get_length() > BackupService.MAX_FILE_BYTES:
		file.close()
		return {"ok": false, "text": "", "too_large": true}
	var text := file.get_as_text()
	file.close()
	return {"ok": true, "text": text, "too_large": false}
