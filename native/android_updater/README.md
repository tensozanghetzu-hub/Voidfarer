# Voidfarer Android updater bridge

`VoidfarerUpdaterPlugin.java` is the original native Android portion of the updater. The Godot `HTTPRequest` layer performs manual GitHub release checks and downloads; this plug-in only opens Android's unknown-source settings or package-install confirmation when asked.

It uses Godot 4.3's existing `applicationId.fileprovider` and does not add another provider, background service, analytics library, or third-party dependency.

The compiled AAR is stored at `addons/voidfarer_updater/voidfarer_updater.aar`. Rebuild it with `native/android_updater/build.sh` after changing the Java source. The script expects:

- `JAVA_HOME` pointing to JDK 17
- `ANDROID_HOME` pointing to an SDK with `platforms/android-34/android.jar`
- `GODOT_ANDROID_CLASSES` pointing to `classes.jar` extracted from Godot 4.3's Android library AAR

The main project still needs Godot's Android build template installed (`Project → Install Android Build Template`) because Godot 4.2+ v2 plug-ins use Gradle exports. The generated `android/` template directory is intentionally not committed.
