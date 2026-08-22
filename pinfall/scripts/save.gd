extends Node
## Progress that survives closing the app. The hybrid-casual layer, and the only structural
## difference between this and the pin-pullers it is competing with.
##
## Why it is here at all: see MARKET_CHECK.md. Pure hypercasual sheds nearly every player by
## Day 30; hybrid-casual titles run roughly 2.5x the Day 7 retention, and the difference the
## data attributes it to is having something waiting when you come back. That is cheap to build
## now and expensive to retrofit once levels, currency and UI all assume a fresh start.
##
## Stored with ConfigFile in user:// rather than a JSON blob somewhere clever, because on iOS
## user:// is the one directory that is backed up, survives an update, and is not wiped by the
## system when storage runs low.

const PATH := "user://pinfall.cfg"

var level := 0          ## furthest level reached
var stars := 0          ## earned by finishing without spilling — the reason to replay a level
var best: Dictionary = {}   ## level index -> fewest pins pulled


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	level = int(cf.get_value("progress", "level", 0))
	stars = int(cf.get_value("progress", "stars", 0))
	best = cf.get_value("progress", "best", {})


func save_progress() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "level", level)
	cf.set_value("progress", "stars", stars)
	cf.set_value("progress", "best", best)
	cf.save(PATH)


func record_win(index: int, pins_pulled: int, clean: bool) -> bool:
	## Returns true when this run beat the stored best, which is what the UI celebrates.
	level = maxi(level, index + 1)
	if clean:
		stars += 1
	var prev: int = int(best.get(index, 999))
	var improved := pins_pulled < prev
	if improved:
		best[index] = pins_pulled
	save_progress()
	return improved
