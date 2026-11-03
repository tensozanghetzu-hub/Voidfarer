# Voidfarer Android updater bridge

`VoidfarerUpdaterPlugin.java` is the original native Android portion of the updater. The Godot `HTTPRequest` layer performs manual GitHub release checks, downloads, and size/digest verification; this plug-in installs only the verified local APK when asked.

On Android 12 (API 31) and later it:

1. Creates a full `PackageInstaller` session for Voidfarer's own package.
2. Streams and fsyncs the APK into that session.
3. Requests `USER_ACTION_NOT_REQUIRED`.
4. Commits with a mutable `PendingIntent` targeting the explicit, non-exported `VoidfarerUpdateReceiver`.
5. Lets the receiver open Android's supplied confirmation intent if `STATUS_PENDING_USER_ACTION` is returned.

The receiver ignores successful completion and user cancellation, and reports other failures with a short on-device message. Uncommitted sessions are abandoned. Android versions below 12 and session setup failures retain the original `ACTION_INSTALL_PACKAGE` / `ACTION_VIEW` FileProvider flow.

The AAR declares `UPDATE_PACKAGES_WITHOUT_USER_ACTION`; the app's export preset separately declares `REQUEST_INSTALL_PACKAGES` and `INTERNET`. No background service, automatic update checker, analytics library, or third-party dependency is added. Godot 4.3's existing `applicationId.fileprovider` is used only by the fallback path.

The compiled AAR is stored at `addons/voidfarer_updater/voidfarer_updater.aar`. Rebuild it with `native/android_updater/build.sh` after changing the Java source. The script expects:

- `JAVA_HOME` pointing to JDK 17
- `ANDROID_HOME` pointing to an SDK with `platforms/android-34/android.jar`
- `GODOT_ANDROID_CLASSES` pointing to `classes.jar` extracted from Godot 4.3's Android library AAR

After rebuilding, run `python3 tests/test_android_updater.py` with `javap` and `ANDROID_HOME` available. These static checks validate the built bridge but do not replace a physical-device installation test.

The main project still needs Godot's Android build template installed (`Project → Install Android Build Template`) because Godot 4.2+ v2 plug-ins use Gradle exports. The generated `android/` template directory is intentionally not committed.
