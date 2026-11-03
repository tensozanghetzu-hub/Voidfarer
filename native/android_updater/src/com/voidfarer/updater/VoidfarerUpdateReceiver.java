package com.voidfarer.updater;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInstaller;
import android.util.Log;
import android.widget.Toast;

/** Receives PackageInstaller results and opens Android's fallback confirmation. */
public final class VoidfarerUpdateReceiver extends BroadcastReceiver {
    private static final String TAG = "VoidfarerUpdater";

    @Override
    public void onReceive(Context context, Intent intent) {
        String expectedAction = context.getPackageName()
                + VoidfarerUpdaterPlugin.STATUS_ACTION_SUFFIX;
        if (!expectedAction.equals(intent.getAction())) {
            return;
        }

        int status = intent.getIntExtra(
                PackageInstaller.EXTRA_STATUS,
                PackageInstaller.STATUS_FAILURE
        );
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            Intent confirmation = (Intent) intent.getParcelableExtra(Intent.EXTRA_INTENT);
            if (confirmation == null) {
                showFailure(context, "Android did not provide its confirmation screen.", null);
                return;
            }
            try {
                confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(confirmation);
            } catch (Exception failure) {
                showFailure(context, "Android's confirmation screen could not be opened.", failure);
            }
            return;
        }

        if (status == PackageInstaller.STATUS_SUCCESS
                || status == PackageInstaller.STATUS_FAILURE_ABORTED) {
            // Success normally replaces and restarts the app. Aborted means the
            // user canceled; never reopen the installer against that choice.
            return;
        }

        String message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE);
        showFailure(context, message, null);
    }

    private static void showFailure(Context context, String message, Exception failure) {
        String detail = message == null ? "" : message.trim();
        if (detail.isEmpty() && failure != null) {
            detail = failure.getClass().getSimpleName();
        }
        if (detail.isEmpty()) {
            detail = "Unknown Android installer error";
        }
        Log.e(TAG, "Update installation failed: " + detail, failure);
        Toast.makeText(
                context,
                "Voidfarer update was not installed. Return to Updates and try again.",
                Toast.LENGTH_LONG
        ).show();
    }
}
