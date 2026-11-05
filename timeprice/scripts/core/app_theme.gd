class_name AppTheme
extends RefCounted
## Дизайн-система TIMEPRICE: палитра, типографика и Theme для всех Control-узлов.
##
## Вариации типов (theme_type_variation):
##   Label:          TitleLabel, HeadingLabel, DisplayLabel, ValueLabel,
##                   CaptionLabel, MutedLabel, AccentLabel, ErrorLabel, SectionLabel
##   Button:         PrimaryButton, SecondaryButton, GhostButton, DangerButton,
##                   IconButton, NavButton, ChipButton, OptionRowButton
##   PanelContainer: Card, AccentCard, InputPanel, ToastPanel, DialogPanel, NavPanel
##   LineEdit:       BareLineEdit

# Палитра.
const BG := Color(0.0549, 0.0784, 0.1255)          # #0E1420
const SURFACE := Color(0.0824, 0.1137, 0.1686)     # #151D2B
const SURFACE_2 := Color(0.1098, 0.149, 0.2196)    # #1C2638
const SURFACE_3 := Color(0.1412, 0.1882, 0.2863)   # #243049
const BORDER := Color(0.1647, 0.2118, 0.2941)      # #2A364B
const NAV_BG := Color(0.0667, 0.098, 0.1529)       # #111927
const TEXT := Color(0.9529, 0.9608, 0.9765)        # #F3F5F9
const TEXT_SECONDARY := Color(0.6392, 0.6824, 0.7529)  # #A3AEC0
const TEXT_MUTED := Color(0.4314, 0.4784, 0.5569)  # #6E7A8E
const ACCENT := Color(0.2039, 0.7765, 0.6588)      # #34C6A8
const ACCENT_PRESSED := Color(0.1647, 0.6588, 0.5608)
const ACCENT_SOFT := Color(0.2039, 0.7765, 0.6588, 0.14)
const ON_ACCENT := Color(0.0235, 0.1373, 0.1137)   # #06231D
const DANGER := Color(0.8902, 0.4196, 0.4824)      # #E36B7B
const DANGER_SOFT := Color(0.8902, 0.4196, 0.4824, 0.14)
const WARNING := Color(0.898, 0.698, 0.3216)       # #E5B252

# Отступы и размеры (в логических пикселях окна 400×860).
const SCREEN_PADDING := 20
const RADIUS_CARD := 20
const RADIUS_CONTROL := 14
const TOUCH_TARGET := 52.0

# Типографика.
const FONT_BODY := 16
const FONT_CAPTION := 13
const FONT_SMALL := 12
const FONT_VALUE := 20
const FONT_HEADING := 20
const FONT_TITLE := 26
const FONT_DISPLAY := 38

static var _theme: Theme
static var _regular: Font
static var _bold: Font


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func bold_font() -> Font:
	if _bold == null:
		_bold = _system_font(650)
	return _bold


static func regular_font() -> Font:
	if _regular == null:
		_regular = _system_font(400)
	return _regular


static func stylebox(color: Color, radius: int = RADIUS_CONTROL, border_color: Color = Color(0, 0, 0, 0),
		border_width: int = 0, pad_h: float = 16.0, pad_v: float = 12.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border_width > 0:
		sb.border_color = border_color
		sb.set_border_width_all(border_width)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.anti_aliasing = true
	return sb


static func _system_font(weight: int) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Roboto", "Inter", "Noto Sans", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"])
	font.font_weight = weight
	font.allow_system_fallback = true
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_LIGHT
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return font


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = regular_font()
	t.default_font_size = FONT_BODY
	var empty := StyleBoxEmpty.new()

	# --- Label ---
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("line_spacing", "Label", 3)
	_label_variation(t, "TitleLabel", FONT_TITLE, TEXT, true)
	_label_variation(t, "HeadingLabel", FONT_HEADING, TEXT, true)
	_label_variation(t, "DisplayLabel", FONT_DISPLAY, ACCENT, true)
	_label_variation(t, "ValueLabel", FONT_VALUE, TEXT, true)
	_label_variation(t, "CaptionLabel", FONT_CAPTION, TEXT_SECONDARY, false)
	_label_variation(t, "MutedLabel", FONT_CAPTION, TEXT_MUTED, false)
	_label_variation(t, "AccentLabel", FONT_BODY, ACCENT, true)
	_label_variation(t, "ErrorLabel", FONT_CAPTION, DANGER, false)
	_label_variation(t, "SectionLabel", FONT_CAPTION, TEXT_SECONDARY, true)
	_label_variation(t, "BodySecondaryLabel", FONT_BODY, TEXT_SECONDARY, false)

	# --- Button (базовый — вторичная кнопка) ---
	_button_styles(t, "Button", SURFACE_2, SURFACE_3, SURFACE_3, TEXT)
	t.set_font("font", "Button", bold_font())
	t.set_font_size("font_size", "Button", FONT_BODY)
	t.set_constant("h_separation", "Button", 10)
	t.set_constant("icon_max_width", "Button", 22)
	t.set_color("font_disabled_color", "Button", TEXT_MUTED)
	t.set_stylebox("disabled", "Button", stylebox(SURFACE, RADIUS_CONTROL, BORDER, 1, 18, 14))

	t.set_type_variation("PrimaryButton", "Button")
	_button_styles(t, "PrimaryButton", ACCENT, ACCENT_PRESSED, Color(0.26, 0.82, 0.71), ON_ACCENT)
	t.set_stylebox("disabled", "PrimaryButton", stylebox(SURFACE_2, RADIUS_CONTROL, Color(0, 0, 0, 0), 0, 18, 14))
	t.set_color("font_disabled_color", "PrimaryButton", TEXT_MUTED)

	t.set_type_variation("SecondaryButton", "Button")
	_button_styles(t, "SecondaryButton", SURFACE_2, SURFACE_3, SURFACE_3, TEXT)

	t.set_type_variation("GhostButton", "Button")
	_button_styles(t, "GhostButton", Color(0, 0, 0, 0), ACCENT_SOFT, ACCENT_SOFT, ACCENT, 10, 10)
	t.set_stylebox("disabled", "GhostButton", empty)

	t.set_type_variation("DangerButton", "Button")
	_button_styles(t, "DangerButton", DANGER_SOFT, Color(0.89, 0.42, 0.48, 0.26), Color(0.89, 0.42, 0.48, 0.2), DANGER)

	t.set_type_variation("IconButton", "Button")
	_button_styles(t, "IconButton", Color(0, 0, 0, 0), SURFACE_3, SURFACE_2, TEXT_SECONDARY, 10, 10)
	t.set_color("icon_normal_color", "IconButton", TEXT_SECONDARY)
	t.set_color("icon_hover_color", "IconButton", TEXT)
	t.set_color("icon_pressed_color", "IconButton", TEXT)
	t.set_color("icon_focus_color", "IconButton", TEXT)

	t.set_type_variation("NavButton", "Button")
	_button_styles(t, "NavButton", Color(0, 0, 0, 0), ACCENT_SOFT, Color(0, 0, 0, 0), TEXT_MUTED, 4, 4)

	t.set_type_variation("ChipButton", "Button")
	_button_styles(t, "ChipButton", SURFACE_2, SURFACE_3, SURFACE_3, TEXT_SECONDARY, 14, 8)
	t.set_font_size("font_size", "ChipButton", FONT_CAPTION + 1)
	var chip_on := stylebox(ACCENT_SOFT, 100, ACCENT, 1, 14, 8)
	t.set_stylebox("pressed", "ChipButton", chip_on)
	t.set_stylebox("hover_pressed", "ChipButton", chip_on)
	t.set_color("font_pressed_color", "ChipButton", ACCENT)
	t.set_color("font_hover_pressed_color", "ChipButton", ACCENT)
	for state in ["normal", "hover", "focus"]:
		t.set_stylebox(state, "ChipButton", stylebox(SURFACE_2, 100, BORDER, 1, 14, 8))
	t.set_stylebox("focus", "ChipButton", empty)

	t.set_type_variation("OptionRowButton", "Button")
	_button_styles(t, "OptionRowButton", SURFACE, SURFACE_2, SURFACE_2, TEXT, 18, 16)
	t.set_font("font", "OptionRowButton", regular_font())
	var row_on := stylebox(ACCENT_SOFT, RADIUS_CONTROL, ACCENT, 1, 18, 16)
	t.set_stylebox("pressed", "OptionRowButton", row_on)
	t.set_stylebox("hover_pressed", "OptionRowButton", row_on)
	t.set_color("font_pressed_color", "OptionRowButton", TEXT)
	t.set_color("font_hover_pressed_color", "OptionRowButton", TEXT)
	t.set_color("icon_pressed_color", "OptionRowButton", ACCENT)
	t.set_color("icon_hover_pressed_color", "OptionRowButton", ACCENT)

	# --- OptionButton / PopupMenu ---
	_button_styles(t, "OptionButton", SURFACE_2, SURFACE_3, SURFACE_3, TEXT, 16, 14)
	t.set_font_size("font_size", "OptionButton", FONT_BODY)
	t.set_constant("arrow_margin", "OptionButton", 14)
	t.set_color("font_disabled_color", "OptionButton", TEXT_MUTED)
	t.set_stylebox("panel", "PopupMenu", stylebox(SURFACE_2, RADIUS_CONTROL, BORDER, 1, 8, 8))
	t.set_stylebox("hover", "PopupMenu", stylebox(SURFACE_3, 10, Color(0, 0, 0, 0), 0, 12, 10))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	t.set_font_size("font_size", "PopupMenu", FONT_BODY + 1)
	t.set_constant("v_separation", "PopupMenu", 18)
	t.set_constant("item_start_padding", "PopupMenu", 14)
	t.set_constant("item_end_padding", "PopupMenu", 14)

	# --- CheckButton ---
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", TEXT)
	t.set_color("font_focus_color", "CheckButton", TEXT)
	for state in ["normal", "pressed", "hover", "hover_pressed", "focus"]:
		t.set_stylebox(state, "CheckButton", stylebox(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 0, 10))
	t.set_constant("h_separation", "CheckButton", 12)

	# --- LineEdit ---
	t.set_stylebox("normal", "LineEdit", stylebox(SURFACE_2, RADIUS_CONTROL, BORDER, 1, 16, 14))
	t.set_stylebox("focus", "LineEdit", stylebox(Color(0, 0, 0, 0), RADIUS_CONTROL, ACCENT, 2, 16, 14))
	t.set_stylebox("read_only", "LineEdit", stylebox(SURFACE, RADIUS_CONTROL, BORDER, 1, 16, 14))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_MUTED)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(0.2039, 0.7765, 0.6588, 0.35))
	t.set_font_size("font_size", "LineEdit", FONT_BODY + 1)
	t.set_constant("caret_width", "LineEdit", 2)
	t.set_type_variation("BareLineEdit", "LineEdit")
	var bare := StyleBoxEmpty.new()
	bare.content_margin_top = 14
	bare.content_margin_bottom = 14
	t.set_stylebox("normal", "BareLineEdit", bare)
	t.set_stylebox("focus", "BareLineEdit", StyleBoxEmpty.new())
	t.set_stylebox("read_only", "BareLineEdit", bare)

	# --- PanelContainer ---
	t.set_stylebox("panel", "PanelContainer", empty)
	_panel_variation(t, "Card", stylebox(SURFACE, RADIUS_CARD, Color(1, 1, 1, 0.04), 1, 18, 18))
	_panel_variation(t, "AccentCard", stylebox(Color(0.11, 0.2, 0.22), RADIUS_CARD, Color(0.2039, 0.7765, 0.6588, 0.35), 1, 20, 20))
	_panel_variation(t, "InputPanel", stylebox(SURFACE_2, RADIUS_CONTROL, BORDER, 1, 16, 0))
	_panel_variation(t, "InputPanelFocus", stylebox(SURFACE_2, RADIUS_CONTROL, ACCENT, 2, 16, 0))
	_panel_variation(t, "InputPanelError", stylebox(SURFACE_2, RADIUS_CONTROL, DANGER, 2, 16, 0))
	_panel_variation(t, "ToastPanel", stylebox(SURFACE_3, RADIUS_CONTROL, BORDER, 1, 18, 14))
	_panel_variation(t, "DialogPanel", stylebox(SURFACE, RADIUS_CARD, BORDER, 1, 22, 22))
	var nav := stylebox(NAV_BG, 0, Color(0, 0, 0, 0), 0, 8, 6)
	nav.border_color = BORDER
	nav.border_width_top = 1
	_panel_variation(t, "NavPanel", nav)
	_panel_variation(t, "IconBadge", stylebox(ACCENT_SOFT, 18, Color(0, 0, 0, 0), 0, 0, 0))

	# --- ProgressBar ---
	t.set_stylebox("background", "ProgressBar", stylebox(SURFACE_3, 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", stylebox(ACCENT, 4, Color(0, 0, 0, 0), 0, 0, 0))

	# --- ScrollContainer ---
	t.set_stylebox("panel", "ScrollContainer", empty)
	t.set_stylebox("scroll", "VScrollBar", empty)
	t.set_stylebox("scroll_focus", "VScrollBar", empty)
	var grabber := stylebox(Color(1, 1, 1, 0.12), 3, Color(0, 0, 0, 0), 0, 2, 0)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)

	# --- Separator ---
	var line := StyleBoxLine.new()
	line.color = BORDER
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 1)
	return t


static func _label_variation(t: Theme, name: String, size: int, color: Color, bold: bool) -> void:
	t.set_type_variation(name, "Label")
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
	if bold:
		t.set_font("font", name, bold_font())


static func _panel_variation(t: Theme, name: String, sb: StyleBox) -> void:
	t.set_type_variation(name, "PanelContainer")
	t.set_stylebox("panel", name, sb)


static func _button_styles(t: Theme, type: String, normal: Color, pressed: Color, hover: Color,
		font_color: Color, pad_h: float = 18.0, pad_v: float = 14.0) -> void:
	var radius := RADIUS_CONTROL
	t.set_stylebox("normal", type, stylebox(normal, radius, Color(0, 0, 0, 0), 0, pad_h, pad_v))
	t.set_stylebox("pressed", type, stylebox(pressed, radius, Color(0, 0, 0, 0), 0, pad_h, pad_v))
	t.set_stylebox("hover", type, stylebox(hover, radius, Color(0, 0, 0, 0), 0, pad_h, pad_v))
	t.set_stylebox("hover_pressed", type, stylebox(pressed, radius, Color(0, 0, 0, 0), 0, pad_h, pad_v))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	for c in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type, font_color)
	for c in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_focus_color"]:
		t.set_color(c, type, font_color)
