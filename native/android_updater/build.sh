#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
ANDROID_HOME=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
GODOT_ANDROID_CLASSES=${GODOT_ANDROID_CLASSES:-}
JAVA_HOME=${JAVA_HOME:-}

if [[ -z "$ANDROID_HOME" || -z "$GODOT_ANDROID_CLASSES" || -z "$JAVA_HOME" ]]; then
    echo "Set ANDROID_HOME, GODOT_ANDROID_CLASSES, and JAVA_HOME first." >&2
    exit 1
fi

ANDROID_JAR="$ANDROID_HOME/platforms/android-34/android.jar"
JAVAC="$JAVA_HOME/bin/javac"
JAR="$JAVA_HOME/bin/jar"
for required in "$ANDROID_JAR" "$GODOT_ANDROID_CLASSES" "$JAVAC" "$JAR"; do
    if [[ ! -f "$required" ]]; then
        echo "Required file not found: $required" >&2
        exit 1
    fi
done

WORK="$SCRIPT_DIR/build"
rm -rf "$WORK"
mkdir -p "$WORK/classes" "$WORK/aar/res"
trap 'rm -rf "$WORK"' EXIT

"$JAVAC" -source 8 -target 8 -Xlint:-options \
    -cp "$ANDROID_JAR:$GODOT_ANDROID_CLASSES" \
    -d "$WORK/classes" \
    "$SCRIPT_DIR"/src/com/voidfarer/updater/*.java

"$JAR" cf "$WORK/aar/classes.jar" -C "$WORK/classes" .
cp "$SCRIPT_DIR/AndroidManifest.xml" "$WORK/aar/AndroidManifest.xml"
touch "$WORK/aar/R.txt"

mkdir -p "$PROJECT_DIR/addons/voidfarer_updater"
(
    cd "$WORK/aar"
    "$JAR" cf "$PROJECT_DIR/addons/voidfarer_updater/voidfarer_updater.aar" .
)

echo "Built addons/voidfarer_updater/voidfarer_updater.aar"
