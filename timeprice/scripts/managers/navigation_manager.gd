extends Node
## Навигация: вкладки нижней панели и стек экранов поверх них.
##
## Экраны не знают друг о друге — они вызывают методы этого менеджера,
## а Main реагирует на сигнал route_changed и показывает нужную сцену.
##
## action:
##   ACTION_REPLACE — стек очищен, экран создаётся заново (вкладки, reset_to);
##   ACTION_PUSH    — новый экран поверх текущего, текущий сохраняется;
##   ACTION_POP     — верхний экран закрыт, показывается сохранённый предыдущий.
## direction (−1, 0, 1) используется только для анимации.

signal route_changed(route: String, params: Dictionary, direction: int, action: int)
signal toast_requested(message: String)
signal confirm_requested(options: Dictionary)

const DIRECTION_NONE := 0
const DIRECTION_FORWARD := 1
const DIRECTION_BACK := -1

const ACTION_REPLACE := 0
const ACTION_PUSH := 1
const ACTION_POP := 2

const HOME_ROUTE := "home"

const ROUTES := {
	"onboarding": "res://scenes/onboarding/onboarding_screen.tscn",
	"home": "res://scenes/home/home_screen.tscn",
	"calculator": "res://scenes/calculator/calculator_screen.tscn",
	"history": "res://scenes/analytics/history_screen.tscn",
	"goals": "res://scenes/goals/goals_screen.tscn",
	"goal_detail": "res://scenes/goals/goal_detail_screen.tscn",
	"goal_edit": "res://scenes/goals/goal_edit_screen.tscn",
	"wishlist": "res://scenes/wishlist/wishlist_screen.tscn",
	"wishlist_edit": "res://scenes/wishlist/wishlist_edit_screen.tscn",
	"settings": "res://scenes/settings/settings_screen.tscn",
	"about": "res://scenes/settings/about_screen.tscn",
	"simulator": "res://scenes/simulator/simulator_screen.tscn",
	"tools": "res://scenes/tools/tools_screen.tscn",
	"deposit": "res://scenes/tools/deposit_screen.tscn",
	"loan": "res://scenes/tools/loan_screen.tscn",
	"installment": "res://scenes/tools/installment_screen.tscn",
	"habit": "res://scenes/tools/habit_screen.tscn",
	"cashback": "res://scenes/tools/cashback_screen.tscn",
	"advice": "res://scenes/tools/advice_screen.tscn",
}

## Вкладки нижней панели в порядке отображения.
const TAB_ROUTES := ["home", "calculator", "goals", "wishlist", "tools"]

var _stack: Array[Dictionary] = []


func current_route() -> String:
	if _stack.is_empty():
		return ""
	return _stack.back()["route"]


func is_root() -> bool:
	return _stack.size() <= 1


func is_tab_route(route: String) -> bool:
	return TAB_ROUTES.has(route)


## Нижняя панель видна только на корневом экране-вкладке.
func is_bottom_nav_visible() -> bool:
	return is_root() and is_tab_route(current_route())


func scene_path(route: String) -> String:
	return ROUTES.get(route, "")


## Очищает стек и открывает экран (например, после onboarding).
func reset_to(route: String, params: Dictionary = {}) -> void:
	if not ROUTES.has(route):
		push_error("Неизвестный маршрут: %s" % route)
		return
	_stack = [{"route": route, "params": params}]
	route_changed.emit(route, params, DIRECTION_NONE, ACTION_REPLACE)


func switch_tab(route: String, params: Dictionary = {}) -> void:
	if not is_tab_route(route):
		push_error("Маршрут не является вкладкой: %s" % route)
		return
	var previous := current_route()
	if previous == route and is_root() and params.is_empty():
		return
	var direction := DIRECTION_NONE
	if is_tab_route(previous) and is_root():
		direction = signi(TAB_ROUTES.find(route) - TAB_ROUTES.find(previous))
	_stack = [{"route": route, "params": params}]
	route_changed.emit(route, params, direction, ACTION_REPLACE)


func push(route: String, params: Dictionary = {}) -> void:
	if not ROUTES.has(route):
		push_error("Неизвестный маршрут: %s" % route)
		return
	_stack.append({"route": route, "params": params})
	route_changed.emit(route, params, DIRECTION_FORWARD, ACTION_PUSH)


## Возврат назад. false — возвращаться некуда (корень главной вкладки).
func go_back() -> bool:
	if _stack.size() > 1:
		_stack.pop_back()
		var top: Dictionary = _stack.back()
		route_changed.emit(top["route"], top["params"], DIRECTION_BACK, ACTION_POP)
		return true
	var route := current_route()
	if is_tab_route(route) and route != HOME_ROUTE:
		_stack = [{"route": HOME_ROUTE, "params": {}}]
		route_changed.emit(HOME_ROUTE, {}, DIRECTION_BACK, ACTION_REPLACE)
		return true
	return false


func show_toast(message: String) -> void:
	toast_requested.emit(message)


## Диалог подтверждения. on_confirm вызывается только при подтверждении.
func confirm(title: String, message: String, confirm_text: String, on_confirm: Callable, danger: bool = false) -> void:
	confirm_requested.emit({
		"title": title,
		"message": message,
		"confirm_text": confirm_text,
		"on_confirm": on_confirm,
		"danger": danger,
	})
