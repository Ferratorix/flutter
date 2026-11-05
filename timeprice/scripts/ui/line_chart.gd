class_name LineChart
extends Control
## Простой линейный график по месяцам. Рисуется средствами CanvasItem,
## без сторонних библиотек. Подписи оси Y — краткие суммы (Fmt.compact_amount).

const PAD_LEFT := 72.0
const PAD_RIGHT := 8.0
const PAD_TOP := 10.0
const PAD_BOTTOM := 24.0

## [{"values": Array[int], "color": Color, "width": float}]
var series: Array[Dictionary] = []
## Подписи оси X: {индекс: текст}.
var x_labels: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(0, 200)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(p_series: Array[Dictionary], p_x_labels: Dictionary) -> void:
	series = p_series
	x_labels = p_x_labels
	queue_redraw()


func _draw() -> void:
	if series.is_empty():
		return
	var count := 0
	var min_v := 0
	var max_v := 0
	var first := true
	for s in series:
		var values: Array = s["values"]
		count = maxi(count, values.size())
		for v in values:
			if first:
				min_v = v
				max_v = v
				first = false
			min_v = mini(min_v, v)
			max_v = maxi(max_v, v)
	min_v = mini(min_v, 0)
	if max_v == min_v:
		max_v = min_v + 100
	if count < 2:
		return

	var font := get_theme_default_font()
	var font_size := AppTheme.FONT_SMALL
	var plot := Rect2(PAD_LEFT, PAD_TOP, size.x - PAD_LEFT - PAD_RIGHT, size.y - PAD_TOP - PAD_BOTTOM)
	if plot.size.x <= 10.0 or plot.size.y <= 10.0:
		return
	var span := float(max_v - min_v)

	# Сетка и подписи оси Y.
	for i in 4:
		var t := i / 3.0
		var value := int(roundf(min_v + span * t))
		var y := plot.end.y - plot.size.y * t
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(1, 1, 1, 0.06), 1.0)
		draw_string(font, Vector2(0, y + font_size * 0.35), Fmt.compact_amount(value),
			HORIZONTAL_ALIGNMENT_RIGHT, PAD_LEFT - 8.0, font_size, AppTheme.TEXT_MUTED)
	# Нулевая линия, если есть отрицательные значения.
	if min_v < 0:
		var zero_y := plot.end.y - plot.size.y * (float(-min_v) / span)
		draw_dashed_line(Vector2(plot.position.x, zero_y), Vector2(plot.end.x, zero_y), AppTheme.DANGER, 1.0, 4.0)

	# Подписи оси X.
	for key in x_labels:
		var index: int = key
		var x := plot.position.x + plot.size.x * (float(index) / float(count - 1))
		var text: String = x_labels[key]
		var width := 60.0
		var align := HORIZONTAL_ALIGNMENT_CENTER
		var left := x - width / 2.0
		if index == 0:
			align = HORIZONTAL_ALIGNMENT_LEFT
			left = x
		elif index == count - 1:
			align = HORIZONTAL_ALIGNMENT_RIGHT
			left = x - width
		draw_string(font, Vector2(left, size.y - 6.0), text, align, width, font_size, AppTheme.TEXT_MUTED)

	# Линии.
	for s in series:
		var values: Array = s["values"]
		var points := PackedVector2Array()
		for i in values.size():
			var x := plot.position.x + plot.size.x * (float(i) / float(count - 1))
			var y := plot.end.y - plot.size.y * (float(int(values[i]) - min_v) / span)
			points.append(Vector2(x, y))
		if points.size() >= 2:
			draw_polyline(points, s["color"], float(s.get("width", 2.0)), true)
