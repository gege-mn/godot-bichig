@tool
class_name BichigButton
extends BaseButton
## A button with its text in the traditional Mongolian script, drawn with the theme's Button
## styles and colours.

@export_multiline var text := "":
	set(value):
		text = value
		_changed()
## Falls back to the theme's Button font.
@export var font: Font:
	set(value):
		if font and font.changed.is_connected(_restyled):
			font.changed.disconnect(_restyled)
		font = value
		if font:
			font.changed.connect(_restyled)
		_changed()
## Zero falls back to the theme's Button font size.
@export_range(0, 256, 1, "or_greater", "suffix:px") var font_size := 0:
	set(value):
		font_size = value
		_changed()
@export var alignment := BichigText.Alignment.CENTER:
	set(value):
		alignment = value
		queue_redraw()
@export_range(-64, 64, 1, "or_less", "or_greater", "suffix:px") var column_spacing := 0.0:
	set(value):
		column_spacing = value
		_changed()
@export var language := "mn":
	set(value):
		language = value
		_changed()

var _layout := BichigText.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_restyled()


func _get_minimum_size() -> Vector2:
	return _shaped().get_size() + _style().get_minimum_size()


func _restyled() -> void:
	_layout.invalidate()
	_changed()


func _changed() -> void:
	update_minimum_size()
	queue_redraw()


func _shaped() -> BichigText:
	_layout.text = text
	_layout.font = font if font else get_theme_font(&"font", &"Button")
	_layout.font_size = font_size if font_size > 0 else get_theme_font_size(&"font_size", &"Button")
	_layout.column_spacing = column_spacing
	_layout.language = language
	_layout.alignment = alignment
	return _layout


func _state() -> StringName:
	match get_draw_mode():
		DRAW_DISABLED:
			return &"disabled"
		DRAW_PRESSED, DRAW_HOVER_PRESSED:
			return &"pressed"
		DRAW_HOVER:
			return &"hover"
	return &"normal"


func _style() -> StyleBox:
	return get_theme_stylebox(_state(), &"Button")


func _draw() -> void:
	var style := _style()
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	if has_focus():
		draw_style_box(get_theme_stylebox(&"focus", &"Button"), Rect2(Vector2.ZERO, size))
	var layout := _shaped()
	var state := _state()
	var color := get_theme_color(&"font_color" if state == &"normal" else StringName("font_%s_color" % state), &"Button")
	var inner := Rect2(style.get_offset(), size - style.get_minimum_size())
	var area := layout.get_size()
	var at := inner.position + Vector2(floorf((inner.size.x - area.x) / 2.0), 0)
	layout.draw(get_canvas_item(), at, color, inner.size.y)
