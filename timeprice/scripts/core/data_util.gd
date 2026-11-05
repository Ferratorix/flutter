class_name DataUtil
extends RefCounted
## Безопасное чтение значений из словарей, загруженных из JSON.
## JSON возвращает все числа как float, поэтому значения проверяются и приводятся.


static func get_int(data: Dictionary, key: String, default_value: int, min_value: int, max_value: int) -> int:
	var v: Variant = data.get(key, default_value)
	var result := default_value
	match typeof(v):
		TYPE_INT:
			result = v
		TYPE_FLOAT:
			if is_finite(v):
				result = int(roundf(v))
		_:
			return default_value
	if result < min_value or result > max_value:
		return default_value
	return result


static func get_string(data: Dictionary, key: String, default_value: String, max_length: int = 200) -> String:
	var v: Variant = data.get(key, default_value)
	if typeof(v) != TYPE_STRING:
		return default_value
	var s: String = v
	return s.substr(0, max_length)


static func get_bool(data: Dictionary, key: String, default_value: bool) -> bool:
	var v: Variant = data.get(key, default_value)
	if typeof(v) == TYPE_BOOL:
		return v
	return default_value


static func get_dict(data: Dictionary, key: String) -> Dictionary:
	var v: Variant = data.get(key, {})
	if typeof(v) == TYPE_DICTIONARY:
		return v
	return {}


static func get_array(data: Dictionary, key: String) -> Array:
	var v: Variant = data.get(key, [])
	if typeof(v) == TYPE_ARRAY:
		return v
	return []


static func now() -> int:
	return int(Time.get_unix_time_from_system())


static func new_id() -> String:
	return "%d-%08x" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]
