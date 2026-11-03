# Voidfarer updates

## Player experience

From **v0.2.0 onward**, open **CHECK FOR UPDATES** on the main menu:

1. The game manually queries the latest public GitHub release.
2. If a newer version exists, review its notes and tap **DOWNLOAD UPDATE**.
3. The game verifies the APK size and GitHub's SHA-256 digest when provided.
4. Tap **INSTALL UPDATE**.
5. If Android asks, enable **Allow from this source** for Voidfarer, return to the game, and tap **INSTALL UPDATE** again.
6. Confirm Android's package-install prompt. Android does not permit a normal sideloaded app to silently replace itself.

Closing the panel cancels an active check/download. A completed download remains available if the Android installer is canceled. Gameplay and saves do not require a network connection; only this panel uses one.

**v0.1.0 does not contain the updater. Install v0.2.0 manually once to enable direct updates for later releases.**

Updates with the same package name and signing certificate install over the old app and retain local data. Uninstalling or clearing app data can erase the save.

## Publishing a compatible update

For every new release:

1. Set the same new semantic version in:
   - `scripts/game_data.gd` → `GAME_VERSION`
   - `project.godot` → `application/config/version`
   - `export_presets.cfg` → `version/name`
2. Increment `export_presets.cfg` → `version/code` by at least one. Android rejects an update with an unchanged or lower code.
3. Keep package name `com.tensozanghetzu.voidfarer` and the existing signing keystore. Never commit the keystore or passwords. A different signature requires uninstalling and can lose the save.
4. Preserve save compatibility or add explicit migration in `save_manager.gd` and `game_data.gd` before changing the save schema.
5. Run the offline integration suite and, when release infrastructure changes, the optional live network test.
6. Export and verify the APK, then publish a **public, non-draft, non-prerelease** GitHub release marked **Latest**.
7. Use tag `vX.Y.Z` and attach the asset with the exact filename **`Voidfarer.apk`**. The updater deliberately rejects other asset names and off-repository APK URLs.

The updater reads GitHub's release API and follows the official release-asset redirects. HTTPS, size/digest checks, and Android's same-signature enforcement protect the update path.

## Distribution boundary

This updater is for the personal GitHub-sideloaded build. Google Play restricts `REQUEST_INSTALL_PACKAGES` and generally requires store-managed updates. A future Play Store edition should remove the self-update installer and use the store's update mechanism instead.
