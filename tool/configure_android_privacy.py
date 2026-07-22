#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)

BACKUP_RULES = """<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
    <exclude domain="root" path="." />
    <exclude domain="file" path="." />
    <exclude domain="database" path="." />
    <exclude domain="sharedpref" path="." />
    <exclude domain="external" path="." />
</full-backup-content>
"""

DATA_EXTRACTION_RULES = """<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup disableIfNoEncryptionCapabilities="true">
        <exclude domain="root" path="." />
        <exclude domain="file" path="." />
        <exclude domain="database" path="." />
        <exclude domain="sharedpref" path="." />
        <exclude domain="external" path="." />
    </cloud-backup>
    <device-transfer>
        <exclude domain="root" path="." />
        <exclude domain="file" path="." />
        <exclude domain="database" path="." />
        <exclude domain="sharedpref" path="." />
        <exclude domain="external" path="." />
    </device-transfer>
</data-extraction-rules>
"""


def android(name: str) -> str:
    return f"{{{ANDROID_NS}}}{name}"


def transform_manifest(text: str) -> str:
    had_declaration = text.lstrip().startswith("<?xml")
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    root = ET.fromstring(text, parser=parser)
    application = root.find("application")
    if application is None:
        raise RuntimeError("AndroidManifest.xml has no direct <application> element")

    application.set(android("allowBackup"), "false")
    application.set(android("fullBackupContent"), "@xml/backup_rules")
    application.set(android("dataExtractionRules"), "@xml/data_extraction_rules")

    ET.indent(root, space="    ")
    result = ET.tostring(
        root,
        encoding="unicode",
        short_empty_elements=True,
    )
    if had_declaration:
        result = '<?xml version="1.0" encoding="utf-8"?>\n' + result
    return result.rstrip() + "\n"


def configure(root: Path = ROOT) -> None:
    manifest = root / "android/app/src/main/AndroidManifest.xml"
    if not manifest.exists():
        raise RuntimeError("AndroidManifest.xml was not found")
    original = manifest.read_text(encoding="utf-8")
    updated = transform_manifest(original)
    if updated != original:
        manifest.write_text(updated, encoding="utf-8", newline="\n")

    xml_dir = root / "android/app/src/main/res/xml"
    xml_dir.mkdir(parents=True, exist_ok=True)
    (xml_dir / "backup_rules.xml").write_text(
        BACKUP_RULES,
        encoding="utf-8",
        newline="\n",
    )
    (xml_dir / "data_extraction_rules.xml").write_text(
        DATA_EXTRACTION_RULES,
        encoding="utf-8",
        newline="\n",
    )


def main() -> None:
    configure()
    print("Android backup and data extraction rules applied.")


if __name__ == "__main__":
    main()
