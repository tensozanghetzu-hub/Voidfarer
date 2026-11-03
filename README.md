# Voidfarer

**Voidfarer: First Light** is an original, offline Android space-sandbox game with a holographic 2D/2.5D presentation. It is inspired by the tactical targeting, mining, trading, and ship progression of large space MMOs, but designed as a compact single-player experience.

## Current playable features

- Four connected star systems with distinct security, markets, and procedural environments
- Real-time flight with touch joystick and keyboard controls
- Target locking, automatic orbit, pulse-laser combat, and capacitor management
- Mineable ferrite and crystal asteroids that disappear when depleted
- Pirate AI, elite encounters, tractor-beam salvage recovery, and ship destruction
- Station docking with free repair and capacitor recharge
- Regional commodity markets
- Bounty and delivery contracts
- Four three-rank upgrade paths and a purchasable destroyer
- Autopilot routes through the local jump-gate network
- Local JSON save/continue and insurance recovery
- Manual GitHub update checks, verified downloads, and Android 12+ no-user-action self-updates when permitted, with confirmation fallback
- Original procedural visuals and application icon
- No sound, accounts, advertisements, analytics, in-app purchases, or required network connection

## Controls

### Android / touch

- **Left stick:** thrust
- **Tap a ship or asteroid:** target it
- **FIRE:** engage the selected pirate or nearest pirate
- **MINE:** engage the selected asteroid or nearest asteroid
- **TRACTOR:** pull salvage within 620 m into your cargo hold
- **ORBIT:** automatically approach and orbit the selected target
- **TARGET:** cycle available targets by distance
- **DOCK:** dock nearby or plot an approach to the station
- **MAP:** select a connected system and plot a gate route

Manual thrust cancels autopilot. The Android back button pauses or closes the current panel.

### Updating

From v0.2.0 onward, choose **CHECK FOR UPDATES** on the main menu and download a newer GitHub release. From v0.2.3 onward, Android 12+ can install later self-updates without confirmation when the operating system permits it; otherwise the normal confirmation opens automatically. Only this manual updater uses the network; gameplay remains offline. See [`docs/UPDATES.md`](docs/UPDATES.md) for details and release requirements.

### Keyboard

| Input | Action |
|---|---|
| WASD / arrow keys | Thrust |
| Space | Fire pulse laser |
| Tab | Cycle target |
| M | Toggle mining |
| T | Toggle salvage tractor |
| O | Toggle automatic orbit |
| F | Dock / approach station |
| G | Galaxy map |
| Escape | Pause / back |

## First-flight route

1. Select an asteroid and engage **MINE**.
2. Target a pirate, engage **ORBIT**, then **FIRE**.
3. Engage **TRACTOR** to pull in salvage, or fly through it manually.
4. Dock, sell cargo, and accept a contract.
5. Buy upgrades or save for the **VF-7 Kestrel**.
6. Use the map to transport goods between regional markets.

## Technology

- Godot 4.3
- GDScript plus an original Java Android updater bridge
- OpenGL compatibility renderer
- ARM64 Android APK
- No external art or audio dependencies

## Project layout

```text
assets/             Original application icon
scenes/             Main scene
scripts/            Simulation, interface, updater, data, controls, and saving
addons/             Godot Android updater export plug-in
native/             Editable Java updater bridge and build script
tools/              Reproducible Android template setup
tests/              Headless gameplay and updater integration checks
docs/               Design, build, and update notes
export_presets.cfg Android export configuration
project.godot       Godot project settings
```

## Build, install, and test

See [`docs/BUILDING.md`](docs/BUILDING.md) for sideloading, signing, local-save, and Android export notes.

Open `project.godot` in Godot 4.3 or a newer compatible version. The Android preset is named **Android**.

Run the integration checks from a terminal with Godot on PATH:

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

The game is a personal project and is not affiliated with or endorsed by CCP Games, Fenris Creations, NetEase, or EVE.
