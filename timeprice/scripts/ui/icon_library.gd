class_name IconLibrary
extends RefCounted
## Минималистичные линейные иконки. SVG рендерятся во время выполнения
## (без импорта ресурсов) белым цветом и окрашиваются через modulate / theme.

const RENDER_SCALE := 3.0

const _TEMPLATE := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\">%s</svg>"

const _ICONS := {
	"home": "<path d=\"M3.5 10.5 12 3.5l8.5 7V19a1.5 1.5 0 0 1-1.5 1.5h-4v-6h-6v6H5A1.5 1.5 0 0 1 3.5 19z\"/>",
	"calculator": "<rect x=\"5\" y=\"2.5\" width=\"14\" height=\"19\" rx=\"2.5\"/><path d=\"M8.5 7h7\"/><circle cx=\"9\" cy=\"12\" r=\"0.9\" fill=\"#ffffff\" stroke=\"none\"/><circle cx=\"12\" cy=\"12\" r=\"0.9\" fill=\"#ffffff\" stroke=\"none\"/><circle cx=\"15\" cy=\"12\" r=\"0.9\" fill=\"#ffffff\" stroke=\"none\"/><circle cx=\"9\" cy=\"15.5\" r=\"0.9\" fill=\"#ffffff\" stroke=\"none\"/><circle cx=\"12\" cy=\"15.5\" r=\"0.9\" fill=\"#ffffff\" stroke=\"none\"/><circle cx=\"15\" cy=\"15.5\" r=\"0.9\" fill=\"#ffffff\" stroke=\"none\"/><circle cx=\"9\" cy=\"19\" r=\"0.9\" fill=\"#ffffff\" stroke=\"none\"/><circle cx=\"12\" cy=\"19\" r=\"0.9\" fill=\"#ffffff\" stroke=\"none\"/><circle cx=\"15\" cy=\"19\" r=\"0.9\" fill=\"#ffffff\" stroke=\"none\"/>",
	"history": "<path d=\"M3.5 12a8.5 8.5 0 1 0 2.6-6.1L3.5 8.5\"/><path d=\"M3.5 3.5v5h5\"/><path d=\"M12 7.5V12l3 2\"/>",
	"settings": "<path d=\"M4 7h9M17 7h3M4 12h3M11 12h9M4 17h11M19 17h1\"/><circle cx=\"15\" cy=\"7\" r=\"2\"/><circle cx=\"9\" cy=\"12\" r=\"2\"/><circle cx=\"17\" cy=\"17\" r=\"2\"/>",
	"back": "<path d=\"M15 5l-7 7 7 7\"/>",
	"chevron_right": "<path d=\"M9 5l7 7-7 7\"/>",
	"trash": "<path d=\"M4 7h16\"/><path d=\"M9.5 7V4.5h5V7\"/><path d=\"M6.5 7l1 12.5a1.5 1.5 0 0 0 1.5 1.5h6a1.5 1.5 0 0 0 1.5-1.5l1-12.5\"/><path d=\"M10 11v6M14 11v6\"/>",
	"plus": "<path d=\"M12 5v14M5 12h14\"/>",
	"minus": "<path d=\"M5 12h14\"/>",
	"check": "<path d=\"M5 12.5l4.5 4.5L19 7.5\"/>",
	"clock": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><path d=\"M12 7.5V12l3 2\"/>",
	"info": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><path d=\"M12 11v5\"/><circle cx=\"12\" cy=\"8\" r=\"0.9\" fill=\"#ffffff\" stroke=\"none\"/>",
	"target": "<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><circle cx=\"12\" cy=\"12\" r=\"5\"/><circle cx=\"12\" cy=\"12\" r=\"1.5\"/>",
	"heart": "<path d=\"M12 20s-7.5-4.6-7.5-10.2A4.3 4.3 0 0 1 12 7a4.3 4.3 0 0 1 7.5 2.8C19.5 15.4 12 20 12 20z\"/>",
	"edit": "<path d=\"M4 20h4L19 9a2.1 2.1 0 0 0-3-3L5 17z\"/><path d=\"M14.5 7.5l2 2\"/>",
	"star": "<path d=\"M12 3.8l2.5 5.1 5.6.8-4 4 .9 5.6L12 16.6l-5 2.7.9-5.6-4-4 5.6-.8z\"/>",
	"compare": "<path d=\"M6 20V10M12 20V4M18 20v-7\"/>",
	"shield": "<path d=\"M12 3.5l7 3v5c0 4.5-3 7.8-7 9-4-1.2-7-4.5-7-9v-5z\"/><path d=\"M9 12l2 2 4-4\"/>",
}

static var _cache: Dictionary = {}


static func texture(icon_name: String) -> Texture2D:
	if _cache.has(icon_name):
		return _cache[icon_name]
	var body: String = _ICONS.get(icon_name, "")
	if body.is_empty():
		push_warning("Неизвестная иконка: %s" % icon_name)
		return null
	var image := Image.new()
	var err := image.load_svg_from_string(_TEMPLATE % body, RENDER_SCALE)
	if err != OK:
		push_warning("Не удалось отрисовать иконку: %s" % icon_name)
		return null
	var tex := ImageTexture.create_from_image(image)
	_cache[icon_name] = tex
	return tex


## TextureRect с иконкой заданного размера и цвета.
static func rect(icon_name: String, size: float = 24.0, color: Color = AppTheme.TEXT) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture(icon_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.self_modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
