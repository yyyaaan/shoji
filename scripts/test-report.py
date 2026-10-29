#!/usr/bin/env python3
"""Markdown test report from an Xcode result bundle; CI posts it on pull requests (ci.yml).

Usage: scripts/test-report.py build/TestResults.xcresult
"""
import json
import os
import subprocess
import sys

# CI finds its earlier comment by this first line and updates it instead of adding another.
MARKER = "<!-- shoji-test-report -->"


def results(kind, bundle):
    output = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", kind, "--path", bundle, "--compact"],
        check=True, capture_output=True, text=True,
    ).stdout
    return json.loads(output)


def suites(nodes):
    for node in nodes:
        if node.get("nodeType") == "Test Suite":
            yield node
        else:
            yield from suites(node.get("children", []))


def cases(node):
    if node.get("nodeType") == "Test Case":
        yield node
    for child in node.get("children", []):
        yield from cases(child)


def report(bundle):
    summary = results("summary", bundle)
    tree = results("tests", bundle)
    total, failed, skipped = summary["totalTestCount"], summary["failedTests"], summary["skippedTests"]

    rows, failures = [], []
    for suite in suites(tree["testNodes"]):
        tests = list(cases(suite))
        broken = [test for test in tests if test.get("result") == "Failed"]
        rows.append(f"| {'❌' if broken else '✅'} | {suite['name']} | {len(tests)} | {len(broken) or ''} |")
        for test in broken:
            messages = [child["name"] for child in test.get("children", []) if child.get("nodeType") == "Failure Message"]
            failures.append((suite["name"], test["name"], messages))

    headline = f"❌ {failed} of {total} tests failed" if failed else f"✅ All {total} tests passed"
    if skipped:
        headline += f" ({skipped} skipped)"
    details = [f"{len(rows)} suites", f"{summary['finishTime'] - summary['startTime']:.1f} s"]
    if sha := os.environ.get("GITHUB_SHA"):
        details.append(f"`{sha[:7]}`")

    lines = [MARKER, f"### {headline}", f"<sub>{' · '.join(details)}</sub>", ""]
    for suite, test, messages in failures:
        lines += [f"**{suite} › {test}**", "```", *(messages or ["(no message)"]), "```", ""]
    lines += [
        f"<details{' open' if failed else ''}><summary>Suites</summary>",
        "",
        "| | Suite | Tests | Failed |",
        "|---|---|---:|---:|",
        *rows,
        "",
        "</details>",
    ]
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    sys.stdout.write(report(sys.argv[1]))
