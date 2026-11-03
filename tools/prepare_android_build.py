#!/usr/bin/env python3
"""Apply Voidfarer's local Gradle settings after installing Godot's Android template."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
PROPERTIES = ROOT / "android" / "build" / "gradle.properties"
BUILD_GRADLE = ROOT / "android" / "build" / "build.gradle"
PROJECT = ROOT / "project.godot"
UPDATER_PLUGIN = "res://addons/voidfarer_updater/plugin.cfg"

if not PROPERTIES.is_file() or not BUILD_GRADLE.is_file():
    sys.exit("Install Godot 4.3's Android build template first (Project → Install Android Build Template).")


def set_property(text: str, key: str, value: str) -> str:
    lines = text.splitlines()
    prefix = key + "="
    replacement = key + "=" + value
    for index, line in enumerate(lines):
        if line.startswith(prefix):
            lines[index] = replacement
            break
    else:
        lines.append(replacement)
    return "\n".join(lines) + "\n"


properties = PROPERTIES.read_text(encoding="utf-8")
settings = {
    "android.enableJetifier": "false",
    "android.useAndroidX": "true",
    "org.gradle.jvmargs": "-Xmx512m -XX:MaxMetaspaceSize=384m -Dfile.encoding=UTF-8",
    "org.gradle.daemon": "false",
    "org.gradle.workers.max": "1",
    "kotlin.compiler.execution.strategy": "in-process",
}
for key, value in settings.items():
    properties = set_property(properties, key, value)
PROPERTIES.write_text(properties, encoding="utf-8")

text = BUILD_GRADLE.read_text(encoding="utf-8")
start = text.index("    signingConfigs {")
end = text.index("    buildTypes {", start)
segment = text[start:end]
for section in ("debug", "release"):
    marker = f"        {section} {{\n"
    position = segment.index(marker) + len(marker)
    following = segment[position:position + 220]
    additions = []
    for key in ("enableV1Signing", "enableV2Signing", "enableV3Signing"):
        if key not in following:
            additions.append(f"            {key} true\n")
    if additions:
        segment = segment[:position] + "".join(additions) + segment[position:]
text = text[:start] + segment + text[end:]
BUILD_GRADLE.write_text(text, encoding="utf-8")

# Godot 4.3 can crash when an enabled editor add-on is loaded during a clean
# headless first import. Enable this export-only add-on after template setup.
project_text = PROJECT.read_text(encoding="utf-8")
section_marker = "[editor_plugins]\n"
section_start = project_text.index(section_marker) + len(section_marker)
section_end = project_text.find("\n[", section_start)
if section_end == -1:
    section_end = len(project_text)
section = project_text[section_start:section_end]
lines = section.splitlines()
for index, line in enumerate(lines):
    if line.startswith("enabled=PackedStringArray("):
        if UPDATER_PLUGIN not in line:
            closing = line.rfind(")")
            prefix = line[:closing].rstrip()
            separator = "" if prefix.endswith("(") else ", "
            lines[index] = f'{prefix}{separator}"{UPDATER_PLUGIN}")'
        break
else:
    lines.append(f'enabled=PackedStringArray("{UPDATER_PLUGIN}")')
trailing_newlines = section[len(section.rstrip("\n")):]
project_text = project_text[:section_start] + "\n".join(lines) + trailing_newlines + project_text[section_end:]
PROJECT.write_text(project_text, encoding="utf-8")

print("Android export prepared: updater plug-in enabled, constrained Gradle, AndroidX, v1/v2/v3 signing.")
