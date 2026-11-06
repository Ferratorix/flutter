class_name TestCase
extends RefCounted
## Минимальный базовый класс тестов без сторонних плагинов.

var failures: Array[String] = []
var current_test: String = ""


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(value: bool, message: String = "") -> void:
	if not value:
		_fail("ожидалось true. " + message)


func assert_false(value: bool, message: String = "") -> void:
	if value:
		_fail("ожидалось false. " + message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		_fail("ожидалось <%s> (%s), получено <%s> (%s). %s" % [
			str(expected), type_string(typeof(expected)), str(actual), type_string(typeof(actual)), message])


func assert_almost(actual: float, expected: float, tolerance: float = 1e-9, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("ожидалось ≈ %s, получено %s. %s" % [str(expected), str(actual), message])


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		_fail("ожидалось null. " + message)


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		_fail("ожидалось значение, получено null. " + message)


func _fail(text: String) -> void:
	failures.append("%s: %s" % [current_test, text])
