#!/usr/bin/env python3
"""
parse-firebase-results.py — Extract BENCHMARK_RESULT lines from Firebase
Test Lab output logs and produce a human-readable Markdown summary.

The benchmark Dart test prints lines of the form:
    BENCHMARK_RESULT: {"benchmark":"startup_latency_hash_ms","value":142,...}

This script:
  1. Walks the --results-dir for logcat / xctest log files
  2. Extracts all BENCHMARK_RESULT: lines
  3. Groups by benchmark name and device
  4. Computes min / avg / max per benchmark
  5. Writes a Markdown summary table to --output

Usage:
    python3 scripts/parse-firebase-results.py \\
        --results-dir benchmark/results/firebase-20260404-020000 \\
        --output      benchmark/results/firebase-20260404-020000/summary.md

    # GitHub Actions: also emits $GITHUB_STEP_SUMMARY lines
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ── Regex to find result lines ───────────────────────────────────────────────
RESULT_RE = re.compile(r'BENCHMARK_RESULT:\s*(\{.+\})')

# ── Benchmark display names ──────────────────────────────────────────────────
DISPLAY_NAMES: dict[str, str] = {
    'startup_latency_hash_ms':       'Startup latency — hash worker',
    'startup_latency_file_copy_ms':  'Startup latency — file copy',
    'throughput_10_tasks_total_ms':  'Throughput — 10 tasks total',
    'throughput_5_tasks_total_ms':   'Throughput — 5 tasks total',
    'chain_3_steps_ms':              'Chain — 3-step sequential',
    'hash_sha256_1kb_ms':            'SHA-256 hash — 1 KB file',
    'hash_sha256_100kb_ms':          'SHA-256 hash — 100 KB file',
    'hash_sha512_100kb_ms':          'SHA-512 hash — 100 KB file',
    'file_copy_500kb_ms':            'File copy — 500 KB',
}

# ── Thresholds (ms) — PASS if value < threshold ──────────────────────────────
THRESHOLDS: dict[str, int] = {
    'startup_latency_hash_ms':       5_000,
    'startup_latency_file_copy_ms':  5_000,
    'throughput_10_tasks_total_ms':  30_000,
    'throughput_5_tasks_total_ms':   20_000,
    'chain_3_steps_ms':              20_000,
    'hash_sha256_1kb_ms':            3_000,
    'hash_sha256_100kb_ms':          5_000,
    'hash_sha512_100kb_ms':          5_000,
    'file_copy_500kb_ms':            5_000,
}


def scan_file(path: Path) -> list[dict[str, Any]]:
    """Extract all BENCHMARK_RESULT JSON objects from a single log file."""
    results: list[dict[str, Any]] = []
    try:
        text = path.read_text(errors='replace')
        for m in RESULT_RE.finditer(text):
            try:
                obj = json.loads(m.group(1))
                obj.setdefault('_source_file', path.name)
                results.append(obj)
            except json.JSONDecodeError:
                pass
    except OSError:
        pass
    return results


def collect_results(results_dir: Path) -> list[dict[str, Any]]:
    """Walk results_dir and collect all benchmark result objects."""
    all_results: list[dict[str, Any]] = []
    log_extensions = {'.log', '.txt', '.xml', '.logcat'}
    for path in sorted(results_dir.rglob('*')):
        if path.is_file() and path.suffix.lower() in log_extensions:
            found = scan_file(path)
            if found:
                all_results.extend(found)
    return all_results


def summarise(all_results: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    """Group by benchmark name and compute stats per platform."""
    # keyed: (benchmark, platform) → list of values
    grouped: dict[tuple[str, str], list[int]] = defaultdict(list)
    passed: dict[tuple[str, str], list[bool]] = defaultdict(list)

    for r in all_results:
        name = r.get('benchmark', 'unknown')
        platform = r.get('platform', 'unknown')
        value = r.get('value', -1)
        ok = r.get('passed', value >= 0)
        if isinstance(value, (int, float)) and value >= 0:
            grouped[(name, platform)].append(int(value))
        passed[(name, platform)].append(bool(ok))

    summary: dict[str, dict[str, Any]] = {}
    for (name, platform), values in sorted(grouped.items()):
        key = f'{name}|{platform}'
        summary[key] = {
            'benchmark': name,
            'platform': platform,
            'min': min(values),
            'avg': round(sum(values) / len(values)),
            'max': max(values),
            'runs': len(values),
            'threshold': THRESHOLDS.get(name, 0),
            'pass_rate': round(sum(passed[(name, platform)]) / len(passed[(name, platform)]) * 100),
            'display': DISPLAY_NAMES.get(name, name),
        }
    return summary


def status_icon(row: dict[str, Any]) -> str:
    thr = row['threshold']
    if thr <= 0:
        return '➖'
    return '✅' if row['avg'] < thr else '❌'


def write_markdown(summary: dict[str, dict[str, Any]], output: Path, total_results: int) -> None:
    now = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')
    lines = [
        '# native_workmanager — Firebase Test Lab Benchmark Results',
        '',
        f'_Generated: {now} — {total_results} result(s) collected_',
        '',
    ]

    if not summary:
        lines += [
            '> **No BENCHMARK_RESULT lines found.**',
            '>',
            '> Check that `firebase_benchmark_test.dart` ran and that',
            '> logcat output was captured by Firebase Test Lab.',
        ]
        output.write_text('\n'.join(lines))
        return

    # Group by platform
    platforms: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in summary.values():
        platforms[row['platform']].append(row)

    for platform, rows in sorted(platforms.items()):
        lines += [
            f'## {platform.title()}',
            '',
            '| Benchmark | Min | Avg | Max | Threshold | Status |',
            '|-----------|----:|----:|----:|----------:|:------:|',
        ]
        for row in rows:
            thr = f"{row['threshold']} ms" if row['threshold'] > 0 else '—'
            lines.append(
                f"| {row['display']} "
                f"| {row['min']} ms "
                f"| {row['avg']} ms "
                f"| {row['max']} ms "
                f"| {thr} "
                f"| {status_icon(row)} |"
            )
        lines += [
            '',
            f'_Runs per benchmark: {rows[0]["runs"]}_',
            '',
        ]

    # Overall pass/fail
    all_pass = all(
        status_icon(r) in ('✅', '➖')
        for r in summary.values()
    )
    verdict = '✅ **All benchmarks within thresholds**' if all_pass else '❌ **One or more benchmarks exceeded thresholds**'
    lines += ['---', '', verdict, '']

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text('\n'.join(lines))


def emit_github_summary(summary: dict[str, dict[str, Any]]) -> None:
    """Append to $GITHUB_STEP_SUMMARY if running in GitHub Actions."""
    step_summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if not step_summary:
        return
    rows: list[str] = []
    for row in summary.values():
        icon = status_icon(row)
        rows.append(
            f'| {row["platform"]} | {row["display"]} '
            f'| {row["avg"]} ms | {icon} |'
        )
    content = (
        '## 📊 Benchmark Results\n\n'
        '| Platform | Benchmark | Avg | Status |\n'
        '|----------|-----------|----:|:------:|\n'
        + '\n'.join(rows)
        + '\n'
    )
    with open(step_summary, 'a') as f:
        f.write(content)


def main() -> int:
    parser = argparse.ArgumentParser(description='Parse Firebase Test Lab benchmark results')
    parser.add_argument('--results-dir', required=True, type=Path,
                        help='Directory containing downloaded FTL result files')
    parser.add_argument('--output', required=True, type=Path,
                        help='Output path for the Markdown summary')
    args = parser.parse_args()

    if not args.results_dir.exists():
        print(f'ERROR: results-dir not found: {args.results_dir}', file=sys.stderr)
        return 1

    all_results = collect_results(args.results_dir)
    print(f'Found {len(all_results)} BENCHMARK_RESULT entries in {args.results_dir}')

    summary = summarise(all_results)
    write_markdown(summary, args.output, len(all_results))
    emit_github_summary(summary)

    print(f'Summary written to: {args.output}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
