extends RefCounted

const GAME_VERSION := "0.1.0"
const SAVE_NAME := "Voidfarer"

const RESOURCES := {
	"ferrite": {"name": "Ferrite Ore", "base_price": 14.0, "color": "a7b8c8"},
	"crystal": {"name": "Veld Crystal", "base_price": 42.0, "color": "8be9fd"},
	"salvage": {"name": "Ship Salvage", "base_price": 58.0, "color": "ffbf69"}
}

const SYSTEMS := {
	"haven": {
		"name": "Haven Reach",
		"short": "HVN",
		"security": 0.9,
		"station": "Asterion Anchorage",
		"seed": 1103,
		"asteroids": 15,
		"pirates": 2,
		"connections": ["cinder", "lumen"],
		"description": "A protected shipping hub surrounded by broad ferrite fields. A forgiving place to learn the void.",
		"market": {"ferrite": 0.90, "crystal": 1.12, "salvage": 0.95},
		"nebula": "123044",
		"accent": "48d9e8"
	},
	"cinder": {
		"name": "Cinder Belt",
		"short": "CND",
		"security": 0.4,
		"station": "Cinder Relay",
		"seed": 2207,
		"asteroids": 21,
		"pirates": 4,
		"connections": ["haven", "umbra"],
		"description": "Dense mineral belts and intermittent pirate raids. Risk and reward rise together.",
		"market": {"ferrite": 1.08, "crystal": 0.94, "salvage": 1.10},
		"nebula": "3c2034",
		"accent": "ff9e7d"
	},
	"lumen": {
		"name": "Lumen Drift",
		"short": "LMN",
		"security": 0.6,
		"station": "Lumen Exchange",
		"seed": 3301,
		"asteroids": 17,
		"pirates": 3,
		"connections": ["haven", "umbra"],
		"description": "A crystalline trade corridor lit by a blue-white giant. Prospectors and couriers converge here.",
		"market": {"ferrite": 1.02, "crystal": 1.18, "salvage": 1.04},
		"nebula": "18294b",
		"accent": "8ab4ff"
	},
	"umbra": {
		"name": "Umbra Verge",
		"short": "UMB",
		"security": 0.0,
		"station": "Freeport Null",
		"seed": 4409,
		"asteroids": 25,
		"pirates": 6,
		"connections": ["cinder", "lumen"],
		"description": "Lawless frontier space beyond dependable patrols. Rich fields attract prospectors—and hunters.",
		"market": {"ferrite": 1.24, "crystal": 1.36, "salvage": 1.42},
		"nebula": "2c1742",
		"accent": "d99aff"
	}
}

const SHIPS := {
	"wisp": {
		"name": "VF-1 Wisp",
		"class": "Scout Frigate",
		"cost": 0,
		"shield": 120.0,
		"armor": 80.0,
		"hull": 70.0,
		"energy": 110.0,
		"speed": 265.0,
		"acceleration": 210.0,
		"cargo": 60,
		"damage": 15.0,
		"fire_interval": 0.36,
		"range": 560.0,
		"mining_rate": 4.0
	},
	"kestrel": {
		"name": "VF-7 Kestrel",
		"class": "Assault Destroyer",
		"cost": 4800,
		"shield": 230.0,
		"armor": 145.0,
		"hull": 125.0,
		"energy": 155.0,
		"speed": 245.0,
		"acceleration": 185.0,
		"cargo": 105,
		"damage": 24.0,
		"fire_interval": 0.32,
		"range": 610.0,
		"mining_rate": 5.0
	}
}

const CONTRACTS := {
	"bounty": {
		"name": "Clear the Belt",
		"type": "bounty",
		"target": 3,
		"reward": 850,
		"description": "Destroy 3 pirate ships in any system, then return to a station for payment."
	},
	"ferrite_quota": {
		"name": "Ferrite Quota",
		"type": "delivery",
		"resource": "ferrite",
		"target": 30,
		"reward": 560,
		"description": "Deliver 30 units of Ferrite Ore to any station."
	},
	"crystal_circuit": {
		"name": "Crystal Circuit",
		"type": "delivery",
		"resource": "crystal",
		"target": 12,
		"reward": 900,
		"destination": "lumen",
		"description": "Deliver 12 units of Veld Crystal to Lumen Exchange in Lumen Drift."
	}
}

static func default_profile() -> Dictionary:
	var contracts := {}
	for id in CONTRACTS:
		contracts[id] = {"accepted": false, "progress": 0, "completed": false}
	return {
		"version": 1,
		"credits": 650,
		"ship": "wisp",
		"current_system": "haven",
		"cargo": {"ferrite": 0, "crystal": 0, "salvage": 0},
		"upgrades": {"laser": 0, "shield": 0, "engine": 0, "cargo": 0},
		"contracts": contracts,
		"total_kills": 0,
		"total_mined": 0,
		"total_earned": 0,
		"play_seconds": 0.0,
		"player_position": [320.0, 80.0],
		"player_condition": {},
		"tutorial_stage": 0
	}

static func normalize_profile(profile: Dictionary) -> Dictionary:
	var base := default_profile()
	for key in base:
		if not profile.has(key):
			profile[key] = base[key]
	for resource_id in RESOURCES:
		if not profile["cargo"].has(resource_id):
			profile["cargo"][resource_id] = 0
	for upgrade_id in base["upgrades"]:
		if not profile["upgrades"].has(upgrade_id):
			profile["upgrades"][upgrade_id] = 0
	for contract_id in CONTRACTS:
		if not profile["contracts"].has(contract_id):
			profile["contracts"][contract_id] = base["contracts"][contract_id]
	if not SHIPS.has(profile["ship"]):
		profile["ship"] = "wisp"
	if not SYSTEMS.has(profile["current_system"]):
		profile["current_system"] = "haven"
	return profile

static func ship_stats(profile: Dictionary) -> Dictionary:
	var stats: Dictionary = SHIPS[profile["ship"]].duplicate(true)
	var upgrades: Dictionary = profile["upgrades"]
	stats["shield"] += float(upgrades["shield"]) * 45.0
	stats["energy"] += float(upgrades["shield"]) * 10.0
	stats["speed"] += float(upgrades["engine"]) * 24.0
	stats["acceleration"] += float(upgrades["engine"]) * 16.0
	stats["cargo"] += int(upgrades["cargo"]) * 30
	stats["damage"] *= 1.0 + float(upgrades["laser"]) * 0.35
	stats["fire_interval"] *= maxf(0.65, 1.0 - float(upgrades["laser"]) * 0.08)
	return stats

static func cargo_used(profile: Dictionary) -> int:
	var total := 0
	for amount in profile["cargo"].values():
		total += int(amount)
	return total

static func market_prices(system_id: String, resource_id: String) -> Dictionary:
	var base := float(RESOURCES[resource_id]["base_price"])
	var modifier := float(SYSTEMS[system_id]["market"][resource_id])
	return {
		"buy": int(ceil(base * modifier * 1.12)),
		"sell": int(maxf(1.0, floor(base * modifier * 0.88)))
	}

static func upgrade_cost(upgrade_id: String, current_level: int) -> int:
	var base_costs := {"laser": 750, "shield": 600, "engine": 550, "cargo": 450}
	return int(base_costs[upgrade_id] * (current_level + 1))

static func upgrade_name(upgrade_id: String) -> String:
	return {
		"laser": "Pulse Laser Focusing",
		"shield": "Deflector Matrix",
		"engine": "Engine Injectors",
		"cargo": "Cargo Lattice"
	}[upgrade_id]

static func upgrade_description(upgrade_id: String) -> String:
	return {
		"laser": "+35% laser damage and faster cycling per rank",
		"shield": "+45 shield and +10 capacitor per rank",
		"engine": "+24 velocity and +16 acceleration per rank",
		"cargo": "+30 cargo capacity per rank"
	}[upgrade_id]
