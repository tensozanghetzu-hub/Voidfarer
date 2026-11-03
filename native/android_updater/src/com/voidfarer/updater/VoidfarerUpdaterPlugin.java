package com.voidfarer.updater;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.lang.reflect.Method;

/**
 * Small Android bridge for user-initiated Voidfarer APK updates.
 * The game handles release checks, HTTPS downloads, and integrity verification.
 */
public final class VoidfarerUpdaterPlugin extends GodotPlugin {
    private static final String APK_MIME = "application/vnd.android.package-archive";

    public VoidfarerUpdaterPlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "VoidfarerUpdater";
    }

    /**
     * Opens Android's package installer for a downloaded APK.
     * If per-app unknown-source approval is missing, opens that settings page instead.
     *
     * @return "started", "permission_required", or "error: ..."
     */
    @UsedByGodot
    public String installApk(String path) {
        try {
            Activity activity = getActivity();
            if (activity == null) {
                return "error: Android activity is unavailable";
            }

            File apk = new File(path);
            if (!apk.isFile() || apk.length() == 0L) {
                return "error: Downloaded APK is missing or empty";
            }

            PackageManager packageManager = activity.getPackageManager();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                    && !packageManager.canRequestPackageInstalls()) {
                Intent settings = new Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:" + activity.getPackageName())
                );
                settings.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activity.startActivity(settings);
                return "permission_required";
            }

            // Godot 4.3 already bundles AndroidX FileProvider and declares the
            // applicationId.fileprovider authority for app-private files.
            // Reflection keeps this tiny plug-in free of additional dependencies.
            Class<?> providerClass = Class.forName("androidx.core.content.FileProvider");
            Method getUriForFile = providerClass.getMethod(
                    "getUriForFile",
                    Context.class,
                    String.class,
                    File.class
            );
            Uri apkUri = (Uri) getUriForFile.invoke(
                    null,
                    activity,
                    activity.getPackageName() + ".fileprovider",
                    apk
            );

            Intent install = new Intent(Intent.ACTION_INSTALL_PACKAGE);
            install.setDataAndType(apkUri, APK_MIME);
            install.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            install.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            install.putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true);

            try {
                activity.startActivity(install);
            } catch (ActivityNotFoundException ignored) {
                // Some vendor package installers only handle ACTION_VIEW.
                install = new Intent(Intent.ACTION_VIEW);
                install.setDataAndType(apkUri, APK_MIME);
                install.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                install.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activity.startActivity(install);
            }
            return "started";
        } catch (Exception exception) {
            Throwable cause = exception.getCause() == null ? exception : exception.getCause();
            String message = cause.getMessage();
            if (message == null || message.trim().isEmpty()) {
                message = cause.getClass().getSimpleName();
            }
            return "error: " + message;
        }
    }
}
