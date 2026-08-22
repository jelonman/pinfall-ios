extends CanvasLayer
## The whole interface: a level number, a target, and one verdict line.
##
## Deliberately almost nothing. Games in this genre are watched before they are played, and every
## element on screen competes with the one thing that has to be legible in a three-second ad —
## the fluid moving. No buttons, no currency, no banner. Tap anywhere to retry.

var _title: Label
var _sub: Label
var _verdict: Label


func _ready() -> void:
	layer = 10
	# A dark gradient behind the text. The outline alone was not enough: the title sits over
	# sunlit concrete, and white-on-cream at 28px is unreadable in exactly the frames an ad
	# would use. A band costs one quad and makes the text survive any background under it.
	var band := ColorRect.new()
	band.anchor_right = 1.0
	band.custom_minimum_size = Vector2(0, 140)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.72))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var style := StyleBoxTexture.new()
	style.texture = tex
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_right = 1.0
	panel.custom_minimum_size = Vector2(0, 140)
	panel.offset_bottom = 140
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_title = _label(28, Color(1, 1, 1, 0.92), Vector2(0, 54), HORIZONTAL_ALIGNMENT_CENTER)
	_sub = _label(19, Color(1, 1, 1, 0.55), Vector2(0, 92), HORIZONTAL_ALIGNMENT_CENTER)
	_verdict = _label(44, Color(1, 0.86, 0.55, 0), Vector2(0, 520), HORIZONTAL_ALIGNMENT_CENTER)


func _label(size: int, colour: Color, offset: Vector2, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	# An outline rather than a panel: text has to survive being drawn over a bright concrete wall
	# and over near-black shadow in the same frame.
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	l.anchor_right = 1.0
	l.offset_top = offset.y
	add_child(l)
	return l


func set_level(n: int, needed: int, stars := 0, best := 0) -> void:
	_title.text = "Level %d" % n
	# The returning player needs to see, in the first frame, that the app remembers them. A bare
	# objective line reads identically on a first launch and a fiftieth.
	var tail := ""
	if stars > 0:
		tail += "  ·  %d clean" % stars
	if best > 0:
		tail += "  ·  best %d pins" % best
	_sub.text = "Pour %d lava into the vault, not the pit%s" % [needed, tail]


func verdict(text: String, good: bool) -> void:
	_verdict.text = text
	_verdict.add_theme_color_override(
		"font_color", Color(1, 0.86, 0.55, 1) if good else Color(1, 0.45, 0.4, 1))
	var tw := create_tween()
	tw.tween_property(_verdict, "scale", Vector2(1.06, 1.06), 0.18)
	tw.tween_property(_verdict, "scale", Vector2(1.0, 1.0), 0.22)
