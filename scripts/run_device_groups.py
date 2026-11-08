#!/usr/bin/env python3
"""Run example/integration_test/device_integration_test.dart group by group on one device.

The full file hangs when run in one go (see CONTRIBUTING / project notes), so each group is a
separate `flutter test --plain-name` with its own timeout. A failed group is retried once; a
group that passes on retry is reported as FLAKY (green but visible).

Usage: scripts/run_device_groups.py <flutter-device-id> [--only "Group A,Group B"] [--timeout 900]
Exit code is non-zero if any group failed twice.
"""
import argparse, os, subprocess, sys, time

# Android-only/iOS-only groups simply report "no tests" on the other platform; that is not a failure.
GROUPS = ['issue_84:', 'Trigger Types', 'ExistingPolicy', 'Constraints', 'All Workers',
          'TLS Certificate Pinning', 'Task Chains', 'Tags', 'Cancellation',
          'Events and Progress Streams', 'DartWorker Constraint and Delay Enforcement',
          'Custom Native Workers', 'New v1.1 Features', 'Tag utilities', 'Error resilience',
          'Task status lifecycle', 'Trigger type acceptance', 'Battery restriction diagnostics',
          'Issue #62', 'Issue #36', 'Concurrent tasks', 'Chain data flow', 'Issue #38/#39',
          'Issue #57', 'v1_5_0']


def run(group, device, timeout, cwd):
    try:
        r = subprocess.run(
            ['flutter', 'test', 'integration_test/device_integration_test.dart', '-d', device,
             '--plain-name', group], cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return 'timeout', f'timeout after {timeout}s'
    out = r.stdout + r.stderr
    if 'All tests passed' in out:
        return 'pass', ''
    if 'No tests ran' in out or ('+0' in out and 'Some tests failed' not in out and '[E]' not in out):
        return 'none', 'no tests for this platform'
    fails = [l.strip()[-160:] for l in out.splitlines() if '[E]' in l or 'Some tests failed' in l]
    return 'fail', ' | '.join(fails[-2:]) or 'unknown failure'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('device')
    ap.add_argument('--only', default='')
    ap.add_argument('--timeout', type=int, default=900)
    a = ap.parse_args()
    groups = [g for g in a.only.split(',') if g] or GROUPS
    cwd = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'example')
    rows, failed = [], False
    for g in groups:
        t = time.time()
        status, note = run(g, a.device, a.timeout, cwd)
        if status in ('fail', 'timeout'):
            status2, note2 = run(g, a.device, a.timeout, cwd)
            if status2 == 'pass':
                status, note = 'FLAKY', f'failed once ({note}), passed on retry'
            else:
                status, note, failed = 'FAIL', note2 or note, True
        rows.append((g, status, int(time.time() - t), note))
        print(f'{g}: {status} ({int(time.time() - t)}s) {note}', flush=True)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a') as f:
            f.write(f'### Device tests on `{a.device}`\n\n| group | result | s | note |\n|---|---|---|---|\n')
            for g, s, secs, n in rows:
                f.write(f'| {g} | {s} | {secs} | {n} |\n')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
