#!/usr/bin/env python3
"""Static regressions for the built Android updater bridge.

These checks complement, but do not replace, an on-device PackageInstaller test.
Run with JDK's javap on PATH after native/android_updater/build.sh.
"""

from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
AAR = ROOT / "addons" / "voidfarer_updater" / "voidfarer_updater.aar"
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
failures: list[str] = []


def check(condition: bool, message: str) -> None:
    if condition:
        print(f"PASS: {message}")
    else:
        failures.append(message)
        print(f"FAIL: {message}")


def javap(jar: Path, android_jar: Path, class_name: str) -> str:
    executable = shutil.which("javap")
    if executable is None:
        raise RuntimeError("javap is required; put a JDK on PATH")
    return subprocess.run(
        [
            executable,
            "-classpath",
            f"{jar}:{android_jar}",
            "-c",
            "-p",
            class_name,
        ],
        check=True,
        capture_output=True,
        text=True,
    ).stdout


if not AAR.is_file():
    raise SystemExit(f"Build the updater AAR first: {AAR}")

with tempfile.TemporaryDirectory() as temporary:
    work = Path(temporary)
    with zipfile.ZipFile(AAR) as archive:
        manifest = ET.fromstring(archive.read("AndroidManifest.xml"))
        classes = archive.read("classes.jar")
        (work / "classes.jar").write_bytes(classes)

    with zipfile.ZipFile(work / "classes.jar") as jar:
        names = set(jar.namelist())
    check(
        "com/voidfarer/updater/VoidfarerUpdaterPlugin.class" in names
        and "com/voidfarer/updater/VoidfarerUpdateReceiver.class" in names,
        "AAR contains both the Godot bridge and install-status receiver",
    )

    permissions = {
        node.get(ANDROID_NS + "name")
        for node in manifest.findall("uses-permission")
    }
    check(
        "android.permission.UPDATE_PACKAGES_WITHOUT_USER_ACTION" in permissions,
        "manifest declares Android's no-user-action update permission",
    )
    receivers = manifest.findall("./application/receiver")
    matching_receivers = [
        node
        for node in receivers
        if str(node.get(ANDROID_NS + "name", "")).endswith("VoidfarerUpdateReceiver")
    ]
    check(
        len(matching_receivers) == 1
        and matching_receivers[0].get(ANDROID_NS + "exported") == "false",
        "install-status receiver is declared exactly once and is not exported",
    )

    android_jar = Path(
        __import__("os").environ.get("ANDROID_HOME", "")
    ) / "platforms" / "android-34" / "android.jar"
    if not android_jar.is_file():
        raise SystemExit(f"Android API 34 android.jar not found: {android_jar}")
    plugin = javap(work / "classes.jar", android_jar, "com.voidfarer.updater.VoidfarerUpdaterPlugin")
    receiver = javap(work / "classes.jar", android_jar, "com.voidfarer.updater.VoidfarerUpdateReceiver")

    check(
        re.search(r"iconst_2\s+.*?setRequireUserAction:\(I\)V", plugin, re.S) is not None,
        "Android 12+ session explicitly requests USER_ACTION_NOT_REQUIRED",
    )
    check(
        "PackageInstaller$Session.commit" in plugin
        and "openWrite" in plugin
        and "fsync" in plugin,
        "updater streams, syncs, and commits a PackageInstaller session",
    )
    check(
        "int 167772160" in plugin
        and "PendingIntent.getBroadcast" in plugin
        and "VoidfarerUpdateReceiver" in plugin,
        "mutable status PendingIntent targets the explicit app receiver",
    )
    check(
        "PackageInstaller$Session.abandon" in plugin
        and "PackageInstaller.abandonSession" in plugin,
        "uncommitted sessions are abandoned without leaking staged APKs",
    )
    check(
        "getParcelableExtra" in receiver
        and "Context.startActivity" in receiver,
        "receiver opens Android's confirmation when user action is still required",
    )
    check(
        "android.intent.action.INSTALL_PACKAGE" in plugin
        and "android.intent.action.VIEW" in plugin
        and "FileProvider" in plugin,
        "legacy system-installer fallback remains available",
    )

if failures:
    raise SystemExit(f"Android updater regressions failed: {failures}")
print("ALL ANDROID UPDATER STATIC CHECKS PASSED")
