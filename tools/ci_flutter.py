"""Run Flutter checks without losing their exit status; annotate failures in GitHub."""
import os
from pathlib import Path
import re
import subprocess
import sys


def escape(text):
    return text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')


def main():
    mode = sys.argv[1]
    report = Path(os.environ.get('RUNNER_TEMP', '/tmp')) / 'fonix-analysis.txt'
    commands = {
        'analyze': ['flutter', 'analyze', '--write', str(report)],
        'test': ['flutter', 'test', '--reporter', 'expanded'],
        'build': ['flutter', 'build', 'apk', '--debug'],
    }
    if mode not in commands:
        raise SystemExit('Expected analyze, test or build')
    if mode == 'analyze' and report.exists():
        report.unlink()
    result = subprocess.run(commands[mode], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(result.stdout, end='', flush=True)
    if result.returncode:
        annotations = 0
        if mode == 'analyze' and report.exists():
            for line in report.read_text().splitlines():
                match = re.match(r'^\[(error|warning|info)\] (.+) \((.+):(\d+):(\d+)\)$', line)
                if not match:
                    continue
                severity, message, file, row, column = match.groups()
                level = 'error' if severity == 'error' else 'warning'
                file = escape(file).replace(':', '%3A').replace(',', '%2C')
                print(f'::{level} file={file},line={row},col={column}::{escape(message)}')
                annotations += 1
        if not annotations:
            # Test fixtures and compiler diagnostics only; no runtime recordings or credentials.
            tail = '\n'.join(result.stdout.splitlines()[-65:])[-14000:]
            print(f'::error title=Flutter {mode} failed::{escape(tail)}')
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
