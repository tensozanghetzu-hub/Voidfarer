# Voidfarer roadmap

## First Light — playable foundation

- [x] Offline project foundation and local save
- [x] Holographic procedural space presentation
- [x] Flight, targeting, orbit, combat, and mining
- [x] Four-system gate network
- [x] Stations, markets, contracts, and fitting
- [x] ARM64 Android export

## 0.2 — Direct updates

- [x] Manual GitHub release checks
- [x] Release notes, progress, cancellation, and retry
- [x] Trusted APK selection plus size/digest verification
- [x] Android user-confirmed installation and saved-download retention
- [x] Compatible package/version/signing workflow

## 0.2.1 — HUD refinement

- [x] Hide the target panel completely when no target is selected
- [x] Keep selected-target information in a bounded compact card
- [x] Prevent target-label wrapping from expanding the flight HUD

## 0.2.2 — Salvage and station usability

- [x] Toggleable 620 m salvage tractor with visible beam and cargo recovery
- [x] Depleted asteroids disappear and release target/mining state
- [x] Persistent station wallet remains visible during fitting purchases
- [x] Gameplay regression checks for all three behaviors

## 0.2.3 — Smoother direct updates

- [x] Android 12+ PackageInstaller self-updates request no user action
- [x] Private status receiver opens Android's confirmation when still required
- [x] Legacy installer fallback, cancellation handling, and session cleanup remain intact
- [x] Static native-updater regressions and merged-APK verification

## 0.3.0 — Navigation, contracts and shipyard

- [x] Live 1,600 m radar minimap with station, gate, asteroid, pirate and salvage contacts
- [x] Full tactical system map with contact targeting and a separate galaxy-route page
- [x] Elite bounty, mining-survey and salvage-recovery objectives alongside existing contracts
- [x] Atlas cargo hauler, Razor interceptor and Delver mining barge join Wisp and Kestrel
- [x] Persistent owned-hull registry, free refitting and legacy-save migration
- [x] Expanded gameplay regressions and rendered navigation/shipyard checks

## Candidate next milestones

### 0.4 — Frontier economy

- Station stock and price response to player/NPC trade
- Additional trade goods and cargo routes
- Repeatable and procedurally generated contracts
- Manufacturing and module research

### 0.5 — Living systems

- NPC miners, traders, and patrols
- Faction reputation and local security response
- Persistent asteroid depletion and market inventories
- Simulated faction control changes

### 0.6 — Greater void

- Seeded expansion to 20+ systems
- Exploration and signal scanning
- Additional hulls and role-specific modules
- Boss encounters and rare salvage

## Design constraints

- Offline single-player gameplay; networking only in the manual updater
- No audio unless explicitly requested later
- Original setting, names, ships, and artwork
- Compact source tree and one current APK
- Touch-first landscape controls with desktop test controls
