# Building and installing Voidfarer

## Install the current APK

The current build is an **ARM64 Android debug APK**, package `com.tensozanghetzu.voidfarer`, version `0.2.2` (`versionCode=4`).

1. Copy `Voidfarer.apk` to an ARM64 Android phone or tablet.
2. Open it with the device's file manager. If Android asks, allow that file manager to install unknown apps.
3. Install and launch **Voidfarer**. The game is landscape.
4. To install with ADB instead, run `adb install -r Voidfarer.apk` with USB debugging enabled.

This is a personally sideloaded debug build, not a Play Store release. Android or Play Protect may show an unknown-app warning. Only install builds you trust.

The APK declares exactly two permissions:

- `INTERNET` — used only by the manual update panel
- `REQUEST_INSTALL_PACKAGES` — used to open Android's user-confirmed update installer

Gameplay, local saves, and all station/flight systems work offline. See [`UPDATES.md`](UPDATES.md) for the update flow.

Saves are stored in the app's private local data. **Uninstalling the app or clearing its data can erase the save.** Future updates must use the same package name and signing key to install over this build without uninstalling.

## Edit and run

1. Install Godot **4.3 stable** (standard, not .NET).
2. Import `project.godot`.
3. Press **F6/F5** or run `scenes/main.tscn`.
4. The left virtual stick accepts mouse input on desktop; keyboard controls are listed in `README.md`.

The project uses GDScript, a small original Java Android updater bridge, and the OpenGL compatibility renderer. There are no external art or audio dependencies, accounts, advertisements, or analytics.

## Run integration checks

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

The offline suite exercises gameplay plus updater version/metadata and interface behavior. It uses and then removes a local test save.

An optional live test queries GitHub and downloads the current public APK to verify redirects, size, and SHA-256 handling:

```bash
godot --headless --path . --script res://tests/test_update_network.gd
```

## Export Android from the editor

1. Install Godot's matching **4.3 stable export templates**.
2. Install **JDK 17** and Android SDK platform/build tools **34**.
3. In Godot's Editor Settings, set the Java SDK, Android SDK, and debug-keystore paths.
4. Choose **Project → Install Android Build Template**. This creates the generated `android/` directory, which is intentionally excluded from Git.
5. Run `python3 tools/prepare_android_build.py` once after installing or replacing the template. It enables the updater export plug-in, applies memory-safe Gradle settings, and enables v1/v2/v3 APK signing.
6. Open **Project → Export**, select the included **Android** preset, and export `build/Voidfarer.apk`.

The updater editor plug-in ships disabled so a clean Godot 4.3 headless first import remains reliable; the preparation script enables it after the initial project/template setup. The preset is ARM64-only, landscape, signed with the configured debug key, and uses Gradle for the v2 Android updater plug-in. `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot` is required by this Godot version's Android export validation; do not remove it.

For command-line exports, put JDK 17 first on `PATH` as well as setting `JAVA_HOME`; Android's `apksigner` otherwise may use an older system Java. For example:

```bash
export JAVA_HOME=/path/to/jdk17
export ANDROID_HOME=/path/to/android-sdk
export PATH="$JAVA_HOME/bin:$PATH"
godot --headless --path . --export-debug Android build/Voidfarer.apk
```

If the Java bridge changes, rebuild `addons/voidfarer_updater/voidfarer_updater.aar` using `native/android_updater/build.sh`; see its README for the three environment paths it expects.

For a public/store release, create and securely back up a private release keystore, switch to a release export, and choose an appropriate version code. Do not commit private keystores or passwords. A Play Store edition should use store-managed updates rather than this sideload updater.
