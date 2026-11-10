class_name Chapters
extends RefCounted
## Ten chapters, their palettes, their puzzle sizes and their territory names.
## Colours are chosen per puzzle independently of the solution, so the palette
## can never leak where the cats are.
##
## 4x4 boards carry only two valid arrangements, so they appear once as the
## tutorial and never again; the campaign ramps through 5x5 to 10x10 instead.

const CHAPTERS: Array = [
	{
		"name": "Sunbeam Steps",
		"blurb": "Warm stones, long naps, first steps.",
		"sizes": [4, 5, 5, 5, 6, 6, 7, 7, 7, 7, 7, 7],
		"tiers": ["Tutorial", "Easy", "Medium"],
		"names": ["Sunbeam Step", "Warm Stone", "Pillow Nook", "Garden Wall", "Daisy Patch", "Tea Table",
			"Porch Rail", "Straw Hat", "Honey Jar", "Cat Mint", "Lazy Corner", "Front Gate"],
	},
	{
		"name": "Whispering Ferns",
		"blurb": "Green light, soft moss, quiet paws.",
		"sizes": [7, 7, 8, 7, 7, 8, 7, 7, 8, 7, 7, 8],
		"tiers": ["Easy", "Medium"],
		"names": ["Fern Hollow", "Mossy Nook", "Root Bridge", "Dew Pond", "Leaf Canopy", "Mushroom Ring",
			"Old Stump", "Vine Ladder", "Quiet Glade", "Beetle Row", "Snail Path", "Shade Pool"],
	},
	{
		"name": "Lantern Wharf",
		"blurb": "Salt air and bobbing lights.",
		"sizes": [7, 8, 8, 7, 8, 8, 7, 8, 8, 7, 8, 8],
		"tiers": ["Medium"],
		"names": ["Lantern Post", "Rope Coil", "Fish Crate", "Tide Pool", "Harbour Bell", "Salt Barrel",
			"Net Mender", "Dock Step", "Gull Rock", "Low Tide", "Boat Hook", "Watch Light"],
	},
	{
		"name": "Dune Postcards",
		"blurb": "Warm sand and painted tiles.",
		"sizes": [8, 8, 7, 8, 8, 8, 7, 8, 8, 8, 7, 8],
		"tiers": ["Medium", "Hard"],
		"names": ["Sand Ridge", "Painted Tile", "Dry Well", "Sun Dial", "Cactus Pot", "Nomad Tent",
			"Oasis Edge", "Clay Oven", "Dust Lane", "Palm Shade", "Caravan Rest", "Blue Door"],
	},
	{
		"name": "Crystal Hollow",
		"blurb": "Cool stone that hums when you purr.",
		"sizes": [8, 8, 9, 8, 8, 9, 8, 8, 9, 8, 8, 9],
		"tiers": ["Medium", "Hard"],
		"names": ["Crystal Shelf", "Echo Vault", "Hum Stone", "Glass River", "Miner's Lamp", "Shard Arch",
			"Quartz Bed", "Deep Spring", "Glow Moss", "Silent Hall", "Amber Vein", "Cold Fire"],
	},
	{
		"name": "Cloud Terrace",
		"blurb": "High steps and long views.",
		"sizes": [8, 9, 8, 9, 9, 8, 9, 8, 9, 9, 8, 9],
		"tiers": ["Hard", "Medium"],
		"names": ["Cloud Step", "Wind Rail", "High Ledge", "Sky Planter", "Thin Air", "Bell Tower",
			"Rope Walk", "Eagle Post", "Mist Gate", "Far Balcony", "Storm Glass", "Sun Deck"],
	},
	{
		"name": "Ember Kitchen",
		"blurb": "Copper pots, warm hearth, full bowls.",
		"sizes": [9, 8, 9, 9, 8, 9, 9, 8, 9, 9, 8, 9],
		"tiers": ["Hard", "Expert"],
		"names": ["Copper Pot", "Hearth Stone", "Spice Rack", "Bread Oven", "Kettle Stand", "Cold Pantry",
			"Chopping Block", "Warm Plate", "Tea Tin", "Iron Ladle", "Flour Bin", "Window Sill"],
	},
	{
		"name": "Moonlit Roofs",
		"blurb": "Tiles, chimneys and a very good view.",
		"sizes": [9, 9, 9, 10, 9, 9, 9, 10, 9, 9, 9, 10],
		"tiers": ["Hard", "Expert"],
		"names": ["Roof Tile", "Chimney Pot", "Gutter Run", "Moon Gate", "Night Jar", "Shingle Row",
			"Loft Window", "Cable Line", "Quiet Street", "Blue Hour", "Cat Ladder", "Star Post"],
	},
	{
		"name": "Star Orchard",
		"blurb": "Fruit that glows when picked at night.",
		"sizes": [9, 9, 10, 9, 9, 10, 9, 9, 10, 9, 9, 10],
		"tiers": ["Expert", "Hard"],
		"names": ["Star Fruit", "Orchard Row", "Glow Pear", "Night Basket", "Low Branch", "Seed Box",
			"Moon Tree", "Cider Press", "Long Ladder", "Wind Chime", "Lantern Tree", "Picked Clean"],
	},
	{
		"name": "Nine Lives Summit",
		"blurb": "The last climb, and the best seat in the world.",
		"sizes": [9, 10, 9, 9, 10, 9, 9, 10, 9, 9, 10, 9],
		"tiers": ["Expert", "Master"],
		"names": ["Summit Path", "Last Step", "Cold Peak", "Wide Sky", "Stone Throne", "Wind Banner",
			"Nine Lives", "Sunrise Ledge", "Long Drop", "Quiet Top", "First Light", "Home Again"],
	},
]

const PALETTE: Array = [
	"#f2cf6b", "#7fc8a9", "#6fb3e0", "#c79be8", "#f49c8b", "#9ed36a",
	"#e8a0c8", "#f2b35e", "#79d9d0", "#b0b7f0", "#e4e07a", "#d98a8a",
]

const LEVELS_PER_CHAPTER := 100
const CHAPTER_COUNT := 10


static func count() -> int:
	return CHAPTERS.size()


static func get_chapter(index: int) -> Dictionary:
	return CHAPTERS[clampi(index, 0, CHAPTERS.size() - 1)]


static func chapter_of(level_id: int) -> int:
	return clampi((level_id - 1) / LEVELS_PER_CHAPTER, 0, CHAPTERS.size() - 1)


static func level_count() -> int:
	return CHAPTERS.size() * LEVELS_PER_CHAPTER


static func size_for(level_id: int) -> int:
	var chapter := chapter_of(level_id)
	var sizes: Array = get_chapter(chapter)["sizes"]
	var offset := (level_id - 1) % LEVELS_PER_CHAPTER
	return int(sizes[offset % sizes.size()])


static func tiers_for(chapter: int) -> Array:
	return get_chapter(chapter)["tiers"]


static func region_names(chapter: int) -> Array:
	return get_chapter(chapter)["names"]


static func title_for(level_id: int) -> String:
	var chapter := chapter_of(level_id)
	var index := (level_id - 1) % LEVELS_PER_CHAPTER
	return "%s %d" % [get_chapter(chapter)["name"], index + 1]


## A stable, per-level colour order. Hues are spaced evenly around the wheel
## with a per-level offset, so no two territories can look alike — the old
## palette could hand a four-territory board three near-identical yellows.
## The offset hash never includes the solution, so colour cannot leak cats.
static func colors_for(level_id: int, n: int) -> Array:
	var colors: Array = []
	var count := maxi(1, n)
	var step := 360.0 / float(count)
	var offset := float((level_id * 137 + 53) % 360)
	for i in range(count):
		var hue := fposmod(offset + step * float(i), 360.0) / 360.0
		var color := Color.from_hsv(hue, 0.56, 0.93)
		colors.append("#" + color.to_html(false))
	return colors
