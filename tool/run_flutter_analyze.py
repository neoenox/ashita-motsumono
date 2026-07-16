from __future__ import annotations

from collections import deque
import subprocess
import sys


MAX_FAILURE_LINES = 200


def main() -> int:
    completed = subprocess.run(
        ['flutter', 'analyze', '--no-fatal-infos'],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    lines = completed.stdout.splitlines()
    if completed.returncode == 0:
        print(completed.stdout, end='')
        return 0

    print(
        f'flutter analyze failed; showing the last {MAX_FAILURE_LINES} lines:',
        file=sys.stderr,
    )
    for line in deque(lines, maxlen=MAX_FAILURE_LINES):
        print(line, file=sys.stderr)
    return completed.returncode


if __name__ == '__main__':
    raise SystemExit(main())
