#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

DEFAULT_ROOT = Path(__file__).resolve().parent.parent
APP_DISPLAY_NAME = "あしたもつもの"
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)


def _android(name: str) -> str:
    return f"{{{ANDROID_NS}}}{name}"


def transform_android_manifest(text: str) -> str:
    had_declaration = text.lstrip().startswith("<?xml")
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    root = ET.fromstring(text, parser=parser)
    app = root.find("application")
    if app is None:
        raise RuntimeError("AndroidManifest.xml has no direct <application> element")

    app.set(_android("label"), APP_DISPLAY_NAME)

    ET.indent(root, space="    ")
    result = ET.tostring(
        root,
        encoding="unicode",
        short_empty_elements=True,
    )
    if had_declaration:
        result = '<?xml version="1.0" encoding="utf-8"?>\n' + result
    return result.rstrip() + "\n"


def transform_ios_info_plist(data: bytes) -> bytes:
    values = plistlib.loads(data)
    values["CFBundleDisplayName"] = APP_DISPLAY_NAME
    values["CFBundleName"] = APP_DISPLAY_NAME
    return plistlib.dumps(values, fmt=plistlib.FMT_XML, sort_keys=False)


def configure(root: Path = DEFAULT_ROOT) -> None:
    android_manifest = root / "android/app/src/main/AndroidManifest.xml"
    if not android_manifest.exists():
        raise RuntimeError("AndroidManifest.xml was not found")

    original_manifest = android_manifest.read_text(encoding="utf-8")
    updated_manifest = transform_android_manifest(original_manifest)
    if updated_manifest != original_manifest:
        android_manifest.write_text(updated_manifest, encoding="utf-8", newline="\n")

    ios_info_plist = root / "ios/Runner/Info.plist"
    if ios_info_plist.exists():
        original_plist = ios_info_plist.read_bytes()
        updated_plist = transform_ios_info_plist(original_plist)
        if updated_plist != original_plist:
            ios_info_plist.write_bytes(updated_plist)


def main() -> None:
    configure()
    print(f'Platform display name set to "{APP_DISPLAY_NAME}".')


if __name__ == "__main__":
    main()
