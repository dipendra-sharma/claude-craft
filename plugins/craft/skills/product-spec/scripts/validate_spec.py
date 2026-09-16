#!/usr/bin/env python3
import re
import sys
from pathlib import Path

CANONICAL_SECTIONS = {
    1: "TL;DR",
    2: "Problem & Why Now",
    3: "Goals & Success Metrics",
    4: "Non-Goals",
    5: "Users & Scenarios",
    6: "Permissions & Roles",
    7: "Existing System & Constraints",
    8: "Functional Requirements",
    9: "Edge Cases & Error Behavior",
    10: "Non-Functional Requirements",
    11: "Analytics & Tracking Events",
    12: "Acceptance Criteria",
    13: "Rollout & Migration",
    14: "Delivery Phases",
    15: "Risks, Assumptions, Dependencies, Open Questions",
    16: "References",
    17: "Visual References",
    18: "Revision History",
}

REQUIRED_SECTIONS = [1, 2, 3, 4, 8, 9, 12]
ADVISORY_SECTIONS = [5, 14, 15]

FRONTMATTER_KEYS = ["title", "id", "status", "owner", "date", "type", "surfaces", "audience"]
STATUS_VALUES = {"Draft", "In Review", "Approved", "In Progress", "Done"}
TYPE_VALUES = {"greenfield", "brownfield", "config-change"}
PRIORITIES = {"Must", "Should", "Could", "Won't"}


class Report:
    def __init__(self):
        self.errors = []
        self.warnings = []

    def error(self, check, detail):
        self.errors.append((check, detail))

    def warn(self, check, detail):
        self.warnings.append((check, detail))

    def render(self, path):
        print(f"validate_spec: {path}")
        if not self.errors and not self.warnings:
            print("  all checks passed")
            return
        for check, detail in self.errors:
            print(f"  FAIL  {check}: {detail}")
        for check, detail in self.warnings:
            print(f"  warn  {check}: {detail}")
        print(f"  {len(self.errors)} error(s), {len(self.warnings)} warning(s)")


def parse_frontmatter(text, report):
    if not text.startswith("---\n"):
        report.error("front-matter", "file must open with a YAML front-matter block")
        return {}
    end = text.find("\n---", 4)
    if end == -1:
        report.error("front-matter", "front-matter block is never closed")
        return {}
    fields = {}
    for line in text[4:end].splitlines():
        if ":" in line:
            key, _, value = line.partition(":")
            fields[key.strip()] = value.strip()
    for key in FRONTMATTER_KEYS:
        if key not in fields:
            report.error("front-matter", f"missing required key '{key}'")
    if fields.get("status") and fields["status"] not in STATUS_VALUES:
        report.error("front-matter", f"status '{fields['status']}' is not one of {sorted(STATUS_VALUES)}")
    if fields.get("type") and fields["type"] not in TYPE_VALUES:
        report.error("front-matter", f"type '{fields['type']}' is not one of {sorted(TYPE_VALUES)}")
    if fields.get("date") and not re.fullmatch(r"\d{4}-\d{2}-\d{2}", fields["date"]):
        report.error("front-matter", f"date '{fields['date']}' is not YYYY-MM-DD")
    return fields


def check_filename(path, fields, report):
    spec_id = fields.get("id")
    if not spec_id:
        return
    expected = f"SPEC-{spec_id}.md"
    if path.name != expected and not path.name.startswith("example-"):
        report.error("filename", f"file is '{path.name}' but front-matter id implies '{expected}'")


def check_sections(text, report, minimal):
    found = [(int(n), title.strip()) for n, title in re.findall(r"^## (\d+)\. (.+)$", text, re.M)]
    numbers = [n for n, _ in found]
    for number, title in found:
        canonical = CANONICAL_SECTIONS.get(number)
        if canonical is None:
            report.error("sections", f"§{number} is not a template section")
        elif title != canonical:
            report.error("sections", f"§{number} is titled '{title}', template says '{canonical}'")
    if numbers != sorted(numbers):
        report.error("sections", "sections are out of order")
    for number in REQUIRED_SECTIONS:
        if number not in numbers:
            report.error("sections", f"§{number} {CANONICAL_SECTIONS[number]} is required and missing")
    if not minimal:
        for number in ADVISORY_SECTIONS:
            if number not in numbers:
                report.warn("sections", f"§{number} {CANONICAL_SECTIONS[number]} is absent — expected unless this is a tiny change")
    return set(numbers)


def collect_requirements(text, report):
    reqs = {}
    seen = []
    for match in re.finditer(r"^- \*\*(FR-\d+)\*\* — (.+)$", text, re.M):
        rid, rest = match.group(1), match.group(2)
        seen.append(rid)
        priority = None
        found = re.search(r"\*(Must|Should|Could|Won't)\*", rest)
        if found:
            priority = found.group(1)
        else:
            report.error("moscow", f"{rid} has no MoSCoW priority")
        reqs[rid] = priority
    for prefix in ("EC", "NFR", "AE"):
        for match in re.finditer(rf"^- \*\*({prefix}-\d+)\*\* — ", text, re.M):
            seen.append(match.group(1))
            reqs[match.group(1)] = None
    for rid in sorted({r for r in seen if seen.count(r) > 1}, key=sort_key):
        report.error("ids", f"{rid} is defined {seen.count(rid)} times — IDs are never reused")
    return reqs


def check_id_sequences(reqs, report):
    by_prefix = {}
    for rid in reqs:
        prefix, number = rid.rsplit("-", 1)
        by_prefix.setdefault(prefix, []).append(int(number))
    for prefix, numbers in by_prefix.items():
        duplicates = {n for n in numbers if numbers.count(n) > 1}
        if duplicates:
            report.error("ids", f"{prefix} numbers reused: {sorted(duplicates)}")
        expected = list(range(1, len(set(numbers)) + 1))
        if sorted(set(numbers)) != expected:
            report.warn("ids", f"{prefix} numbering has gaps: {sorted(set(numbers))} — fine after a revision, otherwise check")


def check_acceptance_coverage(text, reqs, report):
    criteria = re.findall(r"\*\*AC-((?:FR|EC|NFR)-\d+)\.(\d+)\*\*", text)
    covered = {rid for rid, _ in criteria}
    for rid in covered:
        if rid not in reqs:
            report.error("acceptance", f"AC-{rid}.x refers to {rid}, which is not defined")
    needs = set()
    for rid, priority in reqs.items():
        if rid.startswith("EC-") or rid.startswith("NFR-"):
            needs.add(rid)
        elif rid.startswith("FR-") and priority == "Must":
            needs.add(rid)
    for rid in sorted(needs - covered, key=sort_key):
        report.error("acceptance", f"{rid} has no acceptance criterion")
    for rid, priority in reqs.items():
        if rid.startswith("FR-") and priority in ("Should", "Could") and rid not in covered:
            report.warn("acceptance", f"{rid} ({priority}) has no acceptance criterion — a phase cannot mark it done")
    return covered


def sort_key(rid):
    prefix, number = rid.rsplit("-", 1)
    return (prefix, int(number))


def check_phases(text, reqs, covered, sections, report):
    if 14 not in sections:
        return
    phases = re.findall(r"^- \*\*Phase [^:]+:\*\* covers ([^·]+)·(.*)$", text, re.M)
    if not phases:
        report.error("phases", "§14 is present but no phase lines were parsed")
        return
    placements = []
    for covers, rest in phases:
        placements += re.findall(r"(?:FR|EC|NFR|AE)-\d+", covers)
        for referenced in re.findall(r"AC-((?:FR|EC|NFR)-\d+)", rest):
            if referenced not in covered:
                report.error("phases", f"done-when cites AC-{referenced}.x, which does not exist")
    buildable = {rid for rid, priority in reqs.items() if priority != "Won't"}
    for rid in sorted(buildable - set(placements), key=sort_key):
        report.error("phases", f"{rid} is in no delivery phase")
    duplicated = {rid for rid in placements if placements.count(rid) > 1}
    for rid in sorted(duplicated, key=sort_key):
        report.error("phases", f"{rid} appears in more than one phase")


def check_metrics(text, report):
    metrics = re.findall(r"^\s*- \*\*Metric:\*\*(.+)$", text, re.M)
    if not metrics:
        report.error("metrics", "§3 has no '**Metric:**' line")
    for metric in metrics:
        label = metric.strip()[:60]
        if "source:" not in metric:
            report.error("metrics", f"metric has no source — '{label}'")
        if "target" not in metric:
            report.error("metrics", f"metric has no target — '{label}'")
        if not re.search(r"\bby\b|\bwithin\b|\bthrough\b", metric):
            report.warn("metrics", f"metric may have no deadline — '{label}'")


def check_hygiene(text, report):
    if text.count("```") % 2:
        report.error("markdown", "unbalanced code fences")
    if re.search(r"\bN/?A\b", text):
        report.error("hygiene", "contains 'N/A' — omit the section instead")
    placeholders = [p for p in re.findall(r"<[a-z][^>\n]{0,60}>", text) if not p.startswith(("<http", "<mailto"))]
    if placeholders:
        report.error("hygiene", f"unfilled placeholders left: {sorted(set(placeholders))[:5]}")
    if "How to use this template" in text or "Delete this blockquote" in text:
        report.error("hygiene", "the template's how-to blockquote was not deleted")
    for hint in re.findall(r"^\*[A-Z][^\n]{40,}\*$", text, re.M):
        report.warn("hygiene", f"possible leftover template hint — '{hint[:60]}...'")


def check_images(text, report):
    for alt, target in re.findall(r"!\[([^\]]*)\]\(([^)]+)\)", text):
        if target.startswith(("/", "~", "file://", "http")):
            report.error("images", f"'{target}' is not a relative path — copy it into spec-assets/")
        elif not target.startswith("spec-assets/"):
            report.warn("images", f"'{target}' is outside spec-assets/")
        if not alt.strip():
            report.warn("images", f"'{target}' has no alt text")


def check_implementation_leakage(text, report):
    patterns = [
        (r"\bimport \w+", "an import statement"),
        (r"\b(SELECT|CREATE TABLE|INSERT INTO)\b", "SQL"),
        (r"\b(class|def|function|const|var)\s+\w+\s*[({:=]", "a code declaration"),
        (r"(?<![\w/`])(?:src|lib|app)/[\w./-]+", "a source path"),
        (r"[\w/-]+\.(?:py|ts|tsx|js|kt|java|swift|dart|go|rb|sql)\b", "a source filename"),
    ]
    lines = text.splitlines()
    for pattern, label in patterns:
        for match in re.finditer(pattern, text):
            number = text[: match.start()].count("\n") + 1
            if "http" in lines[number - 1]:
                continue
            report.warn("what-not-how", f"line {number} looks like {label}: '{match.group(0)[:40]}'")


def validate(path, minimal=False):
    text = path.read_text()
    report = Report()
    fields = parse_frontmatter(text, report)
    check_filename(path, fields, report)
    sections = check_sections(text, report, minimal)
    reqs = collect_requirements(text, report)
    if not reqs:
        report.error("requirements", "no FR/EC/NFR/AE requirements were parsed — check the bullet format")
    check_id_sequences(reqs, report)
    covered = check_acceptance_coverage(text, reqs, report)
    check_phases(text, reqs, covered, sections, report)
    check_metrics(text, report)
    check_hygiene(text, report)
    check_images(text, report)
    check_implementation_leakage(text, report)
    report.render(path)
    return not report.errors


def main():
    args = [a for a in sys.argv[1:] if a != "--minimal"]
    minimal = "--minimal" in sys.argv[1:]
    if not args:
        print("usage: validate_spec.py [--minimal] <spec.md> [more.md ...]", file=sys.stderr)
        return 2
    results = [validate(Path(arg), minimal) for arg in args]
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
