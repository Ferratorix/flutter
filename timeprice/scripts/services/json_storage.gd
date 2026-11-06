class_name JsonStorage
extends RefCounted
## Надёжное чтение и запись JSON-файлов.
##
## Запись атомарная: данные пишутся во временный файл, проверяются чтением
## и только затем заменяют основной файл. Предыдущая версия сохраняется
## как резервная копия.

enum Status { LOADED, NOT_FOUND, CORRUPTED, IO_ERROR }


## Возвращает {"status": Status, "data": Dictionary}.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": Status.NOT_FOUND, "data": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"status": Status.IO_ERROR, "data": {}}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return {"status": Status.CORRUPTED, "data": {}}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"status": Status.CORRUPTED, "data": {}}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"status": Status.CORRUPTED, "data": {}}
	return {"status": Status.LOADED, "data": json.data}


static func write_atomic(path: String, data: Dictionary, backup_path: String = "") -> Error:
	return write_text_atomic(path, JSON.stringify(data, "\t"), backup_path)


## Атомарная запись текста. Основной файл не удаляется заранее: временный файл
## переименовывается поверх него (на Android и Linux это атомарная операция).
## При нехватке места или другой ошибке основной файл остаётся прежним.
static func write_text_atomic(path: String, text: String, backup_path: String = "") -> Error:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := file.store_string(text)
	file.close()
	if not written:
		DirAccess.remove_absolute(tmp_path)
		return ERR_FILE_CANT_WRITE
	var check := read(tmp_path)
	if check["status"] != Status.LOADED:
		DirAccess.remove_absolute(tmp_path)
		return ERR_FILE_CORRUPT
	if not backup_path.is_empty() and FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, backup_path)
	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK and FileAccess.file_exists(path):
		# Платформы, где переименование не перезаписывает файл: резервная копия уже есть.
		DirAccess.remove_absolute(path)
		err = DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		# Последний вариант: прямая запись основного файла.
		var direct := FileAccess.open(path, FileAccess.WRITE)
		if direct == null:
			return FileAccess.get_open_error()
		var ok := direct.store_string(text)
		direct.close()
		DirAccess.remove_absolute(tmp_path)
		err = OK if ok else ERR_FILE_CANT_WRITE
	return err


static func remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
