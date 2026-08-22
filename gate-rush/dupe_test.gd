extends SceneTree

const Levels := preload("res://data/levels.gd")

## A row whose lanes offer the same value is not a choice. This asserts every generated row across
## the first 100 levels offers distinct options, which is the whole mechanic of the game.
func _init():
	var bad := 0
	var rows_checked := 0
	for lvl in range(1, 101):
		var d := Levels.build(lvl, int(lvl / 5))
		for row in d["rows"]:
			rows_checked += 1
			var seen: Array = []
			for g in row:
				if g["kind"] == "cut":
					continue
				var tag: String = "%s%d" % [g["kind"], int(g["value"])]
				if seen.has(tag):
					bad += 1
					print("level %d: duplicate %s in one row" % [lvl, tag])
					break
				seen.append(tag)
	print("checked %d rows across 100 levels, %d with duplicate choices" % [rows_checked, bad])
	print("DUPE TEST " + ("PASS" if bad == 0 else "FAIL"))
	quit(bad)
