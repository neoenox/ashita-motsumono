#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

DEFAULT_ROOT = Path(__file__).resolve().parent.parent

KTS_SIGNING_CONFIG = '''
    signingConfigs {
        create("release") {
            val props = java.util.Properties()
            val propsFile = rootProject.file("key.properties")
            if (propsFile.exists()) {
                props.load(propsFile.inputStream())
            } else {
                props["storeFile"] = System.getenv("KEYSTORE_PATH") ?: ""
                props["storePassword"] = System.getenv("KEYSTORE_STORE_PASSWORD") ?: ""
                props["keyAlias"] = System.getenv("KEYSTORE_KEY_ALIAS") ?: ""
                props["keyPassword"] = System.getenv("KEYSTORE_KEY_PASSWORD") ?: ""
            }
            val storeFilePath = props.getProperty("storeFile") ?: ""
            if (storeFilePath.isNotEmpty()) {
                val keystoreFile = rootProject.file(storeFilePath)
                if (keystoreFile.exists()) {
                    storeFile = keystoreFile
                    storePassword = props.getProperty("storePassword")
                    keyAlias = props.getProperty("keyAlias")
                    keyPassword = props.getProperty("keyPassword")
                }
            }
        }
    }

'''

KTS_RELEASE_ENFORCEMENT = '''
            // Play release signing enforcement: begin
            val releaseSigning = signingConfigs.getByName("release")
            if (releaseSigning.storeFile != null) {
                signingConfig = releaseSigning
            }
            // Play release signing enforcement: end
'''

GROOVY_SIGNING_CONFIG = '''
    signingConfigs {
        release {
            def props = new Properties()
            def propsFile = rootProject.file('key.properties')
            if (propsFile.exists()) {
                props.load(propsFile.newInputStream())
            } else {
                props['storeFile'] = System.getenv('KEYSTORE_PATH') ?: ''
                props['storePassword'] = System.getenv('KEYSTORE_STORE_PASSWORD') ?: ''
                props['keyAlias'] = System.getenv('KEYSTORE_KEY_ALIAS') ?: ''
                props['keyPassword'] = System.getenv('KEYSTORE_KEY_PASSWORD') ?: ''
            }
            def storeFilePath = props.getProperty('storeFile') ?: ''
            if (storeFilePath) {
                def keystoreFile = rootProject.file(storeFilePath)
                if (keystoreFile.exists()) {
                    storeFile keystoreFile
                    storePassword props.getProperty('storePassword')
                    keyAlias props.getProperty('keyAlias')
                    keyPassword props.getProperty('keyPassword')
                }
            }
        }
    }

'''

GROOVY_RELEASE_ENFORCEMENT = '''
            // Play release signing enforcement: begin
            def releaseSigning = signingConfigs.release
            if (releaseSigning.storeFile != null) {
                signingConfig releaseSigning
            }
            // Play release signing enforcement: end
'''


def _matching_brace(text: str, open_index: int) -> int:
    depth = 0
    quote: str | None = None
    escaped = False
    line_comment = False
    block_comment = False
    index = open_index

    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""
        if line_comment:
            if char == "\n":
                line_comment = False
            index += 1
            continue
        if block_comment:
            if char == "*" and next_char == "/":
                block_comment = False
                index += 2
            else:
                index += 1
            continue
        if quote in ('"""', "'''"):
            if text.startswith(quote, index):
                quote = None
                index += 3
            else:
                index += 1
            continue
        if quote is not None:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            index += 1
            continue
        if char == "/" and next_char == "/":
            line_comment = True
            index += 2
            continue
        if char == "/" and next_char == "*":
            block_comment = True
            index += 2
            continue
        if text.startswith('"""', index) or text.startswith("'''", index):
            quote = text[index : index + 3]
            index += 3
            continue
        if char in ('"', "'"):
            quote = char
            index += 1
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    raise RuntimeError("Unbalanced Gradle braces")


def _block(
    text: str,
    name: str,
    start: int = 0,
    end: int | None = None,
) -> tuple[int, int, int]:
    limit = len(text) if end is None else end
    match = re.search(
        rf"(?m)^[ \t]*{re.escape(name)}(?:\([^\n]*\))?\s*\{{",
        text[start:limit],
    )
    if match is None:
        raise RuntimeError(f"Gradle block not found: {name}")
    block_start = start + match.start()
    open_index = text.find("{", block_start, start + match.end())
    close_index = _matching_brace(text, open_index)
    return block_start, open_index, close_index


def _remove_marker_block(text: str) -> str:
    return re.sub(
        r"(?ms)^\s*// Play release signing enforcement: begin.*?"
        r"^\s*// Play release signing enforcement: end\s*\n?",
        "",
        text,
    )


def transform_kts(text: str) -> str:
    text = _remove_marker_block(text)
    _, android_open, android_close = _block(text, "android")
    android_body = text[android_open + 1 : android_close]
    if not re.search(r"(?m)^\s*signingConfigs\s*\{", android_body):
        build_start, _, _ = _block(text, "buildTypes", android_open, android_close)
        text = text[:build_start] + KTS_SIGNING_CONFIG + text[build_start:]

    _, android_open, android_close = _block(text, "android")
    _, build_open, build_close = _block(text, "buildTypes", android_open, android_close)
    _, release_open, release_close = _block(text, "release", build_open, build_close)
    release_body = text[release_open + 1 : release_close]
    release_body = re.sub(
        r"(?ms)^\s*signingConfig\s*=\s*signingConfigs\.findByName\(\"release\"\)"
        r"\?\.takeIf\s*\{.*?^\s*\?:\s*signingConfigs\.getByName\(\"debug\"\)\s*\n?",
        "",
        release_body,
    )
    release_body = re.sub(
        r"(?m)^\s*signingConfig\s*=\s*signingConfigs\.getByName\(\"debug\"\)\s*\n?",
        "",
        release_body,
    )
    release_body = KTS_RELEASE_ENFORCEMENT + release_body.lstrip("\n")
    return text[: release_open + 1] + release_body + text[release_close:]


def transform_groovy(text: str) -> str:
    text = _remove_marker_block(text)
    _, android_open, android_close = _block(text, "android")
    android_body = text[android_open + 1 : android_close]
    if not re.search(r"(?m)^\s*signingConfigs\s*\{", android_body):
        build_start, _, _ = _block(text, "buildTypes", android_open, android_close)
        text = text[:build_start] + GROOVY_SIGNING_CONFIG + text[build_start:]

    _, android_open, android_close = _block(text, "android")
    _, build_open, build_close = _block(text, "buildTypes", android_open, android_close)
    _, release_open, release_close = _block(text, "release", build_open, build_close)
    release_body = text[release_open + 1 : release_close]
    release_body = re.sub(
        r"(?m)^\s*signingConfig\s+signingConfigs\.debug\s*\n?",
        "",
        release_body,
    )
    release_body = GROOVY_RELEASE_ENFORCEMENT + release_body.lstrip("\n")
    return text[: release_open + 1] + release_body + text[release_close:]


def configure(root: Path = DEFAULT_ROOT) -> Path:
    kts = root / "android/app/build.gradle.kts"
    groovy = root / "android/app/build.gradle"
    if kts.exists():
        result = transform_kts(kts.read_text(encoding="utf-8"))
        kts.write_text(result, encoding="utf-8", newline="\n")
        return kts
    if groovy.exists():
        result = transform_groovy(groovy.read_text(encoding="utf-8"))
        groovy.write_text(result, encoding="utf-8", newline="\n")
        return groovy
    raise RuntimeError("No android/app Gradle build file found")


def main() -> None:
    path = configure()
    print(f"Android release signing enforcement applied: {path}")


if __name__ == "__main__":
    main()
