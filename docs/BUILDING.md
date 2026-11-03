# Building and installing Voidfarer

## Install the current APK

The current build is an **ARM64 Android debug APK**, package `com.tensozanghetzu.voidfarer`, version `0.1.0`.

1. Copy `Voidfarer.apk` to an ARM64 Android phone or tablet.
2. Open it with the device's file manager. If Android asks, allow that file manager to install unknown apps.
3. Install and launch **Voidfarer**. The game is landscape and does not request network access or other Android permissions.
4. To install with ADB instead, run `adb install -r Voidfarer.apk` with USB debugging enabled.

This is a personally sideloaded debug build, not a Play Store release. Android or Play Protect may show an unknown-app warning. Only install builds you trust.

Saves are stored in the app's private local data. **Uninstalling the app or clearing its data can erase the save.** Future updates must use the same package name and signing key to install over this build without uninstalling.

## Edit and run

1. Install Godot **4.3 stable** (standard, not .NET).
2. Import `project.godot`.
3. Press **F6/F5** or run `scenes/main.tscn`.
4. The left virtual stick accepts mouse input on desktop; keyboard controls are listed in `README.md`.

The project uses GDScript and the OpenGL compatibility renderer. There are no plug-ins, external assets, network services, or audio dependencies.

## Run integration checks

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

The suite exercises mining, combat and salvage, station trading, contract rewards, upgrades, local saves, gate travel, and insurance recovery. It uses and then removes a local test save.

## Export Android from the editor

1. Install Godot's matching **4.3 stable export templates**.
2. Install **JDK 17** and Android SDK platform/build tools **34**.
3. In Godot's Editor Settings, set the Java SDK, Android SDK, and debug-keystore paths.
4. Open **Project → Export**, select the included **Android** preset, and export `build/Voidfarer.apk`.

The preset is ARM64-only, landscape, signed with the configured debug key, and has the Internet permission disabled. `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot` is required by this Godot version's Android export validation; do not remove it.

For command-line exports, put JDK 17 first on `PATH` as well as setting `JAVA_HOME`; Android's `apksigner` otherwise may use an older system Java. For example:

```bash
export JAVA_HOME=/path/to/jdk17
export PATH="$JAVA_HOME/bin:$PATH"
godot --headless --path . --export-debug Android build/Voidfarer.apk
```

For a public/store release, create and securely back up a private release keystore, switch to a release export, and choose an appropriate version code. Do not commit private keystores or passwords.
