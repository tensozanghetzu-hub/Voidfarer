package com.voidfarer.updater;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInstaller;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Method;

/**
 * Small Android bridge for user-initiated Voidfarer APK updates.
 * The game handles release checks, HTTPS downloads, and integrity verification.
 */
public final class VoidfarerUpdaterPlugin extends GodotPlugin {
    private static final String APK_MIME = "application/vnd.android.package-archive";
    static final String STATUS_ACTION_SUFFIX = ".updater.INSTALL_STATUS";

    public VoidfarerUpdaterPlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "VoidfarerUpdater";
    }

    /**
     * Installs a downloaded APK over this app.
     *
     * Android 12+ uses PackageInstaller and requests an update without user
     * action. Android may still return a confirmation intent, which the status
     * receiver opens. Older versions and session setup failures use the
     * original system-installer intent.
     *
     * If per-app unknown-source approval is missing, opens that settings page.
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

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    installWithSession(activity, apk);
                    return "started";
                } catch (Exception sessionFailure) {
                    // Some vendor installers may not support the no-user-action
                    // path. Retain the proven intent flow as a safe fallback.
                    try {
                        openSystemInstaller(activity, apk);
                        return "started";
                    } catch (Exception fallbackFailure) {
                        return "error: " + describe(sessionFailure)
                                + "; installer fallback: " + describe(fallbackFailure);
                    }
                }
            }

            openSystemInstaller(activity, apk);
            return "started";
        } catch (Exception exception) {
            return "error: " + describe(exception);
        }
    }

    private static void installWithSession(Activity activity, File apk) throws Exception {
        PackageInstaller installer = activity.getPackageManager().getPackageInstaller();
        PackageInstaller.SessionParams params = new PackageInstaller.SessionParams(
                PackageInstaller.SessionParams.MODE_FULL_INSTALL
        );
        params.setAppPackageName(activity.getPackageName());
        params.setSize(apk.length());
        params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED);

        int sessionId = installer.createSession(params);
        PackageInstaller.Session session = null;
        boolean committed = false;
        try {
            session = installer.openSession(sessionId);
            try (
                    InputStream input = new BufferedInputStream(new FileInputStream(apk));
                    OutputStream output = session.openWrite("base.apk", 0L, apk.length())
            ) {
                byte[] buffer = new byte[65536];
                int count;
                while ((count = input.read(buffer)) != -1) {
                    output.write(buffer, 0, count);
                }
                output.flush();
                session.fsync(output);
            }

            Intent statusIntent = new Intent(activity, VoidfarerUpdateReceiver.class);
            statusIntent.setAction(activity.getPackageName() + STATUS_ACTION_SUFFIX);
            statusIntent.setPackage(activity.getPackageName());
            int pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_MUTABLE;
            PendingIntent statusReceiver = PendingIntent.getBroadcast(
                    activity,
                    sessionId,
                    statusIntent,
                    pendingIntentFlags
            );
            session.commit(statusReceiver.getIntentSender());
            committed = true;
        } finally {
            if (session != null) {
                if (!committed) {
                    try {
                        session.abandon();
                    } catch (Exception ignored) {
                        // Preserve the original installation failure.
                    }
                }
                session.close();
            } else if (!committed) {
                try {
                    installer.abandonSession(sessionId);
                } catch (Exception ignored) {
                    // Preserve the original installation failure.
                }
            }
        }
    }

    private static void openSystemInstaller(Activity activity, File apk) throws Exception {
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
    }

    private static String describe(Throwable failure) {
        Throwable cause = failure.getCause() == null ? failure : failure.getCause();
        String message = cause.getMessage();
        if (message == null || message.trim().isEmpty()) {
            message = cause.getClass().getSimpleName();
        }
        return message;
    }
}
