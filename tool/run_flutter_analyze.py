from __future__ import annotations

from collections import deque
from pathlib import Path
import subprocess
import sys


MAX_FAILURE_LINES = 200
DIAGNOSTIC_PATH = Path('build/diagnostics/flutter-analyze.txt')


def main() -> int:
    completed = subprocess.run(
        ['flutter', 'analyze', '--no-fatal-infos'],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    output = completed.stdout
    lines = output.splitlines()
    if completed.returncode == 0:
        print(output, end='')
        return 0

    DIAGNOSTIC_PATH.parent.mkdir(parents=True, exist_ok=True)
    DIAGNOSTIC_PATH.write_text(output, encoding='utf-8')
    print(
        f'flutter analyze failed; full output saved to {DIAGNOSTIC_PATH}; '
        f'showing the last {MAX_FAILURE_LINES} lines:',
        file=sys.stderr,
    )
    for line in deque(lines, maxlen=MAX_FAILURE_LINES):
        print(line, file=sys.stderr)
    return completed.returncode


if __name__ == '__main__':
    raise SystemExit(main())
