#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

DEFAULT_ROOT = Path(__file__).resolve().parent.parent
MARKER = "ashita-motsumono: align receive_sharing_intent JVM targets"

KTS_BLOCK = f'''// {MARKER}
subprojects {{
    if (name == "receive_sharing_intent") {{
        tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {{
            sourceCompatibility = org.gradle.api.JavaVersion.VERSION_17.toString()
            targetCompatibility = org.gradle.api.JavaVersion.VERSION_17.toString()
        }}
    }}
}}'''

GROOVY_BLOCK = f'''// {MARKER}
subprojects {{
    if (name == 'receive_sharing_intent') {{
        tasks.withType(org.gradle.api.tasks.compile.JavaCompile).configureEach {{
            sourceCompatibility = org.gradle.api.JavaVersion.VERSION_17
            targetCompatibility = org.gradle.api.JavaVersion.VERSION_17
        }}
    }}
}}'''


def _append_once(text: str, block: str) -> str:
    if MARKER in text:
        return text
    stripped = text.rstrip()
    prefix = f"{stripped}\n\n" if stripped else ""
    return f"{prefix}{block}\n"


def _write_if_changed(path: Path, text: str) -> bool:
    original = path.read_text(encoding="utf-8")
    if text == original:
        return False
    with path.open("w", encoding="utf-8", newline="\n") as output:
        output.write(text)
    return True


def configure(root: Path = DEFAULT_ROOT) -> Path:
    android = root / "android"
    kts = android / "build.gradle.kts"
    groovy = android / "build.gradle"

    if kts.exists():
        result = _append_once(kts.read_text(encoding="utf-8"), KTS_BLOCK)
        _write_if_changed(kts, result)
        return kts
    if groovy.exists():
        result = _append_once(groovy.read_text(encoding="utf-8"), GROOVY_BLOCK)
        _write_if_changed(groovy, result)
        return groovy
    raise RuntimeError("No Android root Gradle build file found")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Align receive_sharing_intent Java and Kotlin JVM targets in the "
            "generated Android project."
        )
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=DEFAULT_ROOT,
        help="Project root containing android/ (defaults to repository root).",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    configured = configure(args.root.resolve())
    print(f"Android plugin JVM compatibility applied: {configured}")


if __name__ == "__main__":
    main()
