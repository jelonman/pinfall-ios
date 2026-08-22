extends RefCounted
## The art direction, in one place, because the first pass got it wrong.
##
## Owner, 2026-08-01: *"I expect one of those apps or games to be ready fully and looking like
## they look on the ads... what I saw so far didn't look like that."* He was right. The first
## build used photoscanned concrete, rust and a near-black chamber. The ads for this genre are
## the opposite of that in every respect, and the reference is unambiguous — Rescue Hero, Hero
## Rescue, Pull Pin Games: Rescue & Loot are all BRIGHT saturated cartoon dungeons with a hero
## to save, gold to win and vivid lava to avoid.
##
## Four rules, each the reverse of what the first pass did:
##   1. SATURATED, not photoreal. Flat-ish colour with a strong rim, no scanned normal maps.
##      A 2K roughness scan reads as grey mush on a 6-inch screen; saturated blocks do not.
##   2. LIGHT background. The chamber was near-black, so the molten was the only thing visible
##      and everything else disappeared. A warm lit dungeon gives the lava something to be
##      brighter THAN.
##   3. STAKES on screen. Every ad in the genre shows someone to rescue and something to win in
##      the same frame as the hazard. A crucible and a drain are abstractions; a hero under the
##      lava is not.
##   4. CHUNKY silhouettes. Thick beams, big pins, round gold. It has to read at thumbnail size.

# ⛔ COOL stone, and this is the load-bearing decision. The pass before this made the dungeon
# warm brown, so orange lava sat on an orange wall and washed out to pale cream — the exact
# opposite of what it needed to do. Every game in the reference set puts HOT lava on COOL stone,
# because a complementary background is the only thing that makes a saturated hot colour read as
# hot. The hue split is the art direction; brightness alone cannot rescue it.
const STONE      := Color(0.33, 0.38, 0.52)   # cool slate, mid value
const STONE_DARK := Color(0.22, 0.26, 0.38)
const TRIM       := Color(0.42, 0.72, 0.86)   # lighter cool trim, still on the cold side
const LAVA       := Color(1.00, 0.24, 0.06)
const LAVA_HOT   := Color(1.00, 0.72, 0.20)
const GOLD       := Color(1.00, 0.78, 0.16)
const GOLD_DARK  := Color(0.78, 0.52, 0.06)
const STEEL      := Color(0.80, 0.86, 0.95)
const HERO_SKIN  := Color(0.98, 0.80, 0.62)
const HERO_CLOTH := Color(0.22, 0.52, 0.86)


static func toon(base: Color, rim := 0.55, emission := 0.0) -> StandardMaterial3D:
	"""A flat saturated material with a strong rim. The rim is doing the whole job: without a
	specular scan there is nothing to separate one brown block from the brown block behind it,
	and rim light is how every game in this reference set solves that."""
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.roughness = 0.75
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.rim_enabled = true
	m.rim = rim
	m.rim_tint = 0.35
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = base
		m.emission_energy_multiplier = emission
	return m


static func metal(base: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.roughness = 0.28
	m.metallic = 0.45
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.8
	return m
