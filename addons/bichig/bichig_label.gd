@tool
class_name BichigLabel
extends Control
## A label in the traditional Mongolian script: columns run top to bottom and follow each
## other left to right.

@export_multiline var text := "":
	set(value):
		text = value
		if visible_ratio < 1.0:
			visible_characters = int(text.length() * visible_ratio)
		_changed()
## Falls back to the theme's Label font.
@export var font: Font:
	set(value):
		if font and font.changed.is_connected(_restyled):
			font.changed.disconnect(_restyled)
		font = value
		if font:
			font.changed.connect(_restyled)
		_changed()
## Zero falls back to the theme's Label font size.
@export_range(0, 256, 1, "or_greater", "suffix:px") var font_size := 0:
	set(value):
		font_size = value
		_changed()
@export var font_color := Color.WHITE:
	set(value):
		font_color = value
		queue_redraw()
@export_range(0, 16, 1, "or_greater", "suffix:px") var outline_size := 0:
	set(value):
		outline_size = value
		queue_redraw()
@export var outline_color := Color.BLACK:
	set(value):
		outline_color = value
		queue_redraw()
## Breaks a column that is longer than the label is tall.
@export var autowrap := false:
	set(value):
		autowrap = value
		_changed()
@export var alignment := BichigText.Alignment.TOP:
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
## How many characters are drawn, for a reveal. Less than zero draws all.
@export var visible_characters := -1:
	set(value):
		visible_characters = value
		if value < 0:
			visible_ratio = 1.0
		queue_redraw()
## The share of the characters that is drawn, to tween from 0 to 1.
@export_range(0, 1, 0.001) var visible_ratio := 1.0:
	set(value):
		if value == visible_ratio:
			return
		visible_ratio = value
		visible_characters = -1 if value >= 1.0 else int(text.length() * value)

var _layout := BichigText.new()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			_restyled()
		NOTIFICATION_RESIZED:
			if autowrap and size.y != _layout.wrap_height:
				_changed()


func _get_minimum_size() -> Vector2:
	var area := _shaped().get_size()
	return Vector2(area.x, 0.0 if autowrap else area.y)


## The number of columns the text takes at the label's height.
func get_column_count() -> int:
	return _shaped().get_column_count()


func _restyled() -> void:
	_layout.invalidate()
	_changed()


func _changed() -> void:
	update_minimum_size()
	queue_redraw()


func _shaped() -> BichigText:
	_layout.text = text
	_layout.font = font if font else get_theme_font(&"font", &"Label")
	_layout.font_size = font_size if font_size > 0 else get_theme_font_size(&"font_size", &"Label")
	_layout.wrap_height = size.y if autowrap else -1.0
	_layout.column_spacing = column_spacing
	_layout.language = language
	_layout.alignment = alignment
	_layout.visible_characters = visible_characters
	return _layout


func _draw() -> void:
	var layout := _shaped()
	layout.draw_outline(get_canvas_item(), Vector2.ZERO, outline_size, outline_color, size.y)
	layout.draw(get_canvas_item(), Vector2.ZERO, font_color, size.y)
