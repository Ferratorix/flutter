extends SceneTree
## Запуск: godot --headless --path timeprice --script res://tests/test_runner.gd
## Код возврата 0 — все тесты прошли, 1 — есть ошибки.

const SUITES := [
	"res://tests/test_money.gd",
	"res://tests/test_financial_calculator.gd",
	"res://tests/test_formatters.gd",
	"res://tests/test_models.gd",
	"res://tests/test_storage.gd",
]


func _initialize() -> void:
	TranslationServer.set_locale("ru")
	var total := 0
	var failed := 0
	var messages: Array[String] = []
	for path in SUITES:
		var script := load(path) as GDScript
		if script == null:
			messages.append("Не удалось загрузить набор %s" % path)
			failed += 1
			continue
		var suite: TestCase = script.new()
		for method in suite.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			suite.failures.clear()
			suite.current_test = "%s::%s" % [path.get_file(), method_name]
			suite.before_each()
			suite.call(method_name)
			suite.after_each()
			if suite.failures.is_empty():
				print("  ✓ ", suite.current_test)
			else:
				failed += 1
				print("  ✗ ", suite.current_test)
				messages.append_array(suite.failures)
	print("")
	for m in messages:
		printerr("    ", m)
	print("Тестов: %d, успешно: %d, с ошибками: %d" % [total, total - failed, failed])
	quit(1 if failed > 0 else 0)
