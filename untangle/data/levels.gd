extends RefCounted
class_name Levels

## A level is a PLANAR GRAPH plus a scrambled starting layout.
##
## Solvability is guaranteed by construction rather than checked afterwards: the solved positions
## are generated first, edges are only ever added between pegs whose segment crosses nothing, and
## the start is the SAME graph with the peg positions permuted. The original assignment is always
## a solution, so no level can ship that cannot be untangled. tools/leveltest.gd asserts both ends
## of that — zero crossings in the solved layout, at least one in the scrambled one — for all 60.

const COUNT := 60


static func peg_count(n: int) -> int:
	## 5 pegs at the start, 14 by the end. Small steps: one extra peg is a real jump in a game
	## where difficulty is the number of pairs you have to hold in your head.
	return clampi(5 + int(floor(float(n) / 5.5)), 5, 14)


static func build(n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 977 * (n + 1) + 13          # deterministic: level 7 is the same level for everyone
	var count := peg_count(n)

	# Solved layout: points around a ring with jitter, which keeps every level readable and
	# guarantees general position (no three pegs in a line to make a crossing test ambiguous).
	var solved: Array[Vector2] = []
	for i in count:
		var a: float = TAU * float(i) / float(count) + rng.randf_range(-0.16, 0.16)
		var r: float = rng.randf_range(0.62, 1.0)
		solved.append(Vector2(cos(a), sin(a)) * r)

	# The ring itself, then every non-crossing chord we can add up to a density target. The ring
	# alone is trivial to solve; the chords are what make it a puzzle.
	var edges: Array = []
	for i in count:
		edges.append([i, (i + 1) % count])
	var candidates: Array = []
	for i in count:
		for j in range(i + 2, count):
			if i == 0 and j == count - 1:
				continue
			candidates.append([i, j])
	candidates.shuffle()
	var target: int = count + int(round(float(count) * (0.35 + 0.55 * clampf(float(n) / 59.0, 0.0, 1.0))))
	for c in candidates:
		if edges.size() >= target:
			break
		if _crosses_any(solved, edges, c):
			continue
		edges.append(c)

	# Scramble: permute which peg sits at which solved point. The graph is untouched, so the
	# identity permutation is still a solution.
	var order: Array = []
	for i in count:
		order.append(i)
	var start: Array[Vector2] = []
	start.resize(count)
	var guard := 0
	while true:
		order.shuffle()
		for i in count:
			start[order[i]] = solved[i]
		if crossings(start, edges) > 0 or guard > 40:
			break
		guard += 1

	return {"edges": edges, "start": start, "solved": solved, "pegs": count}


static func _crosses_any(pos: Array, edges: Array, cand: Array) -> bool:
	for e in edges:
		if e[0] == cand[0] or e[1] == cand[0] or e[0] == cand[1] or e[1] == cand[1]:
			continue
		if segments_cross(pos[e[0]], pos[e[1]], pos[cand[0]], pos[cand[1]]):
			return true
	return false


static func crossings(pos: Array, edges: Array) -> int:
	var n := 0
	for i in edges.size():
		for j in range(i + 1, edges.size()):
			var a: Array = edges[i]
			var b: Array = edges[j]
			if a[0] == b[0] or a[0] == b[1] or a[1] == b[0] or a[1] == b[1]:
				continue
			if segments_cross(pos[a[0]], pos[a[1]], pos[b[0]], pos[b[1]]):
				n += 1
	return n


static func crossing_edges(pos: Array, edges: Array) -> Dictionary:
	## Which edges are currently crossing, so the board can show the player where to look.
	var hot := {}
	for i in edges.size():
		for j in range(i + 1, edges.size()):
			var a: Array = edges[i]
			var b: Array = edges[j]
			if a[0] == b[0] or a[0] == b[1] or a[1] == b[0] or a[1] == b[1]:
				continue
			if segments_cross(pos[a[0]], pos[a[1]], pos[b[0]], pos[b[1]]):
				hot[i] = true
				hot[j] = true
	return hot


static func segments_cross(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	## Proper crossing only: shared endpoints and touching are not crossings, and the game must
	## agree with the eye on that or a solved board can read as unsolved.
	var d1 := _side(p3, p4, p1)
	var d2 := _side(p3, p4, p2)
	var d3 := _side(p1, p2, p3)
	var d4 := _side(p1, p2, p4)
	return ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) \
		and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0))


static func _side(a: Vector2, b: Vector2, c: Vector2) -> float:
	var v := (b - a).cross(c - a)
	return 0.0 if absf(v) < 0.000001 else v
