extends SceneTree

const Levels := preload("res://data/levels.gd")

func _init():
	var fails := 0
	var report: Array = []
	for lvl in range(1, 101):
		var best: int = Levels.best_possible(lvl, 0)
		var enemy: int = Levels.enemy_count(lvl)
		var margin: float = float(best) / float(max(enemy, 1))
		# winnable by construction, and never a walkover
		if margin < 1.05 or margin > 2.2:
			fails += 1
			report.append("L%d best=%d enemy=%d margin=%.2f" % [lvl, best, enemy, margin])
		if lvl % 20 == 0:
			print("L%-3d start=%d rows=%d best=%-8d enemy=%-8d margin=%.2f" % [
				lvl, Levels.start_units(lvl, 0), Levels.gate_rows(lvl), best, enemy, margin])
	print("--- levels outside the playable window: %d of 100" % fails)
	for r in report.slice(0, 8):
		print("   ", r)
	quit(1 if fails > 0 else 0)
