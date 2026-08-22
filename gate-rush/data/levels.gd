extends RefCounted
class_name Levels

## The progression the owner asked for: not one ad-length screen, a curve that keeps going.
##
## Owner, 2026-08-19: "you are to make a full game, not just short ad like game. it should have
## this gameplay but progress further and further."
##
## So a level is generated, not hand-placed — 60 authored waves and then an endless curve past
## that, each one harder in a way the player can read: more gate rows, worse gate spread, bigger
## defending mass, and eventually gates that punish a greedy line choice.

const AUTHORED := 60

## ⛔ THE FIRST CURVE WAS BROKEN AND THE TEST CAUGHT IT: 64 of 100 levels sat outside the
## playable window — level 4 was impossible (margin 0.36), level 25 was a walkover (41.9), and
## by level 100 the enemy was 50x anything the player could reach. That is exactly the defect
## that makes a game score -10/100, and it is invisible unless something actually simulates the
## curve. So the enemy is no longer an independent formula: it is DERIVED from what this level's
## own gate layout can actually produce, times a difficulty ratio that ramps.
##
## Result: every level is winnable by construction, and "harder" means a thinner margin for
## error rather than an arbitrary wall.

## How close to perfect play the player must get. 0.55 at level 1 (forgiving), approaching 0.92.
static func target_ratio(level: int) -> float:
	return clampf(0.55 + float(level) * 0.011, 0.55, 0.92)

## Enemy strength, derived from this level's achievable maximum.
static func enemy_count(level: int, upgrade_level: int = 0) -> int:
	var best := best_possible(level, upgrade_level)
	return maxi(4, int(round(float(best) * target_ratio(level))))

## Gate rows the crowd passes through before it reaches the enemy.
static func gate_rows(level: int) -> int:
	return clampi(2 + int(level / 6), 2, 7)

## How much of the row is a trap. At level 1 both lanes help; by level 20 one side is a loss.
static func trap_ratio(level: int) -> float:
	# ⛔ Levels 1-3 have NO trap. The playtest lost level 1 outright because a punishing gate can
	# sit in the lane a centred cannon fires into, so a first-time player is beaten before the
	# mechanic has taught itself. A tutorial level that can be lost by standing still is the
	# same class of defect as the broken curve.
	if level <= 3:
		return 0.0
	return clampf(0.10 + float(level) * 0.022, 0.10, 0.62)

## Multiplier ceiling. Kept modest early so the numbers stay readable on a phone.
static func max_multiplier(level: int) -> int:
	return clampi(2 + int(level / 8), 2, 6)

## Starting crowd. The player is never handed the answer — it grows slowly and only via unlocks.
static func start_units(level: int, upgrade_level: int) -> int:
	## ⛔ 3-4 units read as a lump of specks on a phone. The reference's crowd is a MASS — dozens of
	## bodies filling the lane. The enemy is derived from best_possible(), so raising the starting
	## crowd raises the opposition by the same factor and the balance curve is untouched: this is a
	## readability change, not a difficulty change.
	var base := 8 if level <= 10 else 12
	return base + upgrade_level * 2

## One row of gates: an array of dicts {kind, value, lane}.
## kind: "mul" (x2..x6), "add" (+n), "sub" (-n)
static func build_row(level: int, row_index: int, rng: RandomNumberGenerator) -> Array:
	var lanes := 2 if level < 12 else 3
	var out: Array = []
	var trap_lane := -1
	if rng.randf() < trap_ratio(level):
		trap_lane = rng.randi_range(0, lanes - 1)
	var used: Array = []
	for lane in range(lanes):
		if lane == trap_lane:
			# A punishing gate has to hurt enough to matter but never be unrecoverable.
			# proportional, so it stings the same at 40 units and at 40,000 and never instakills
			var pct := rng.randi_range(25, 45)
			out.append({"kind": "cut", "value": pct, "lane": lane})
		else:
			## ⛔ Two lanes offering the same value is not a choice, and one decision per row is the
			## whole mechanic. Reject a value this row already carries. Verified by dupe_test.gd
			## across every row of the first 100 levels.
			var g: Dictionary = {}
			for _try in range(16):
				if rng.randf() < 0.62:
					g = {"kind": "mul", "value": rng.randi_range(2, max_multiplier(level)),
							"lane": lane}
				else:
					g = {"kind": "add", "value": rng.randi_range(2, 6 + int(level / 3)),
							"lane": lane}
				var tag: String = "%s%d" % [g["kind"], int(g["value"])]
				if not used.has(tag):
					used.append(tag)
					break
			out.append(g)
	return out

## Full level definition, deterministic per level number so a player can learn a level.
static func build(level: int, upgrade_level: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("gate-rush-v1-%d" % level)
	var rows: Array = []
	for i in range(gate_rows(level)):
		rows.append(build_row(level, i, rng))
	return {
		"level": level,
		"start_units": start_units(level, upgrade_level),
		"rows": rows,
		"endless": level > AUTHORED,
	}

## Is this level beatable at all with perfect play? Used by the balance test so a bad curve
## cannot ship — the reason the first build was unplayable was that nobody ever checked.
static func best_possible(level: int, upgrade_level: int) -> int:
	## ⛔ This used to assume the WHOLE crowd takes the best gate in every row. Under the real
	## rule — each unit passes through the gate it is physically in — that is unreachable, so the
	## enemy derived from it made levels 20+ unwinnable even with perfect steering. Model what a
	## good player actually achieves: the bulk funnelled into the best gate, a tail in the rest.
	## Funnel depends on how many lanes the crowd must be squeezed into: with two lanes a player
	## can get nearly all of it through the good gate, with three the crowd is wider than any one
	## lane and a large tail always takes the others. Fitted against the real simulation rather
	## than guessed — a single constant put the enemy 12x out of reach at level 35.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("gate-rush-v1-%d" % level)
	var rows: Array = []
	for i in range(gate_rows(level)):
		rows.append(build_row(level, i, rng))
	var n := float(start_units(level, upgrade_level))
	for row in rows:
		var best := -1.0
		var worst := -1.0
		for g in row:
			var v := n
			match g["kind"]:
				"mul": v = n * float(g["value"])
				"add": v = n + float(g["value"])
				"cut": v = maxf(1.0, n * (1.0 - float(g["value"]) / 100.0))
			if v > best:
				best = v
			if worst < 0.0 or v < worst:
				worst = v
		var funnel := 0.86 if row.size() <= 2 else 0.46
		n = best * funnel + worst * (1.0 - funnel)
	return int(round(n))
