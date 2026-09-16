#!/usr/bin/env python3
import subprocess
import sys


def numstat(args):
    out = subprocess.run(
        ["git", "diff", "--numstat"] + args,
        capture_output=True, text=True, check=True,
    ).stdout
    stats = {}
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        added, removed, path = parts
        if added == "-" or removed == "-":
            stats[path] = (0, 0, True)
        else:
            stats[path] = (int(added), int(removed), False)
    return stats


def merge(raw, ignoring_whitespace):
    rows = []
    for path, (added, removed, binary) in sorted(
        raw.items(), key=lambda kv: -(kv[1][0] + kv[1][1])
    ):
        signal = ignoring_whitespace.get(path, (0, 0, binary))
        rows.append({
            "path": path,
            "total": added + removed,
            "signal": signal[0] + signal[1],
            "binary": binary,
        })
    return rows


def renames(args):
    out = subprocess.run(
        ["git", "diff", "--find-renames=30%", "--summary"] + args,
        capture_output=True, text=True, check=True,
    ).stdout
    return [l.strip() for l in out.splitlines() if "rename" in l or "mode change" in l]


def main(args):
    if not args:
        print("usage: diff_report.py <git-diff-args>   e.g. main...HEAD")
        return 1
    rows = merge(numstat(args), numstat(["-w", "--ignore-blank-lines"] + args))
    total = sum(r["total"] for r in rows)
    signal = sum(r["signal"] for r in rows)
    print(f"{total} lines changed across {len(rows)} files")
    print(f"{total - signal} of them ({0 if not total else round(100 * (total - signal) / total)}%) are whitespace-only\n")
    print(f"{'total':>7} {'signal':>7}  file")
    for r in rows:
        tag = " (binary)" if r["binary"] else ""
        print(f"{r['total']:>7} {r['signal']:>7}  {r['path']}{tag}")
    detected = renames(args)
    if detected:
        print("\nlikely moves shown as rewrites:")
        for line in detected:
            print(f"  {line}")
    return 0


def self_check():
    raw = {"a.py": (10, 2, False), "b.py": (1, 1, False)}
    trimmed = {"a.py": (0, 0, False), "b.py": (1, 1, False)}
    rows = merge(raw, trimmed)
    assert [r["path"] for r in rows] == ["a.py", "b.py"]
    assert rows[0]["total"] == 12 and rows[0]["signal"] == 0
    assert rows[1]["total"] == 2 and rows[1]["signal"] == 2
    assert merge({"x.png": (0, 0, True)}, {})[0]["binary"]
    print("ok")


if __name__ == "__main__":
    if sys.argv[1:2] == ["--self-check"]:
        self_check()
    else:
        sys.exit(main(sys.argv[1:]))
