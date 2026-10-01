#!/usr/bin/env python3
"""Anti-fabrication validator for Option A footprint candidate rows.

Enforces the pipeline's core honesty rule: every external figure must carry a
resolvable source_url and an as_of_period, be scoped to a known PoC merchant,
and (for counts) be numeric. Run before merging candidates into a seed.

Usage:
    python validate_candidates.py --schema country_units candidates.csv
    python validate_candidates.py --schema brand_totals  candidates.csv
    python validate_candidates.py --schema operator_map  candidates.csv

Exit code 0 = all rows valid; 1 = one or more rows rejected (details printed).
Stdlib only — safe to run in CI with no dependencies.
"""
import argparse
import csv
import re
import sys

MERCHANTS = {
    "Starbucks", "SSP", "Burger King / King Foods", "Accor", "Marriott",
    "Four Seasons", "Luxottica", "Dolce & Gabbana", "Subdued",
}

REQUIRED = {
    "country_units": ["merchant", "country", "external_units", "source_url", "as_of_period", "source_tier"],
    "brand_totals": ["merchant", "unit_type", "source_url", "as_of_period", "source_tier"],
    "operator_map": ["merchant", "country", "operator_name", "source_url", "as_of_period"],
}

URL_RE = re.compile(r"^https?://[^\s]+\.[^\s]+", re.IGNORECASE)
ASOF_RE = re.compile(r"^\d{4}(-\d{2}){0,2}$")  # YYYY | YYYY-MM | YYYY-MM-DD
TIERS = {"A", "B", "C"}


def validate(schema: str, path: str) -> int:
    required = REQUIRED[schema]
    errors = []
    n = 0
    with open(path, newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        missing_cols = [c for c in required if c not in (reader.fieldnames or [])]
        if missing_cols:
            print(f"FAIL: missing required columns: {missing_cols}")
            print(f"      found: {reader.fieldnames}")
            return 1
        for i, row in enumerate(reader, start=2):  # header is line 1
            n += 1
            rid = f"row {i} ({row.get('merchant','?')}/{row.get('country','')})"

            if (row.get("merchant") or "").strip() not in MERCHANTS:
                errors.append(f"{rid}: merchant not in the 9 PoC merchants")

            url = (row.get("source_url") or "").strip()
            if not URL_RE.match(url):
                errors.append(f"{rid}: source_url missing or not a resolvable http(s) URL")

            asof = (row.get("as_of_period") or "").strip()
            if not ASOF_RE.match(asof):
                errors.append(f"{rid}: as_of_period missing or not YYYY[-MM[-DD]]")

            if "source_tier" in required:
                if (row.get("source_tier") or "").strip() not in TIERS:
                    errors.append(f"{rid}: source_tier must be one of {sorted(TIERS)}")

            if schema == "country_units":
                val = (row.get("external_units") or "").strip()
                if not val.isdigit():
                    errors.append(f"{rid}: external_units must be a positive integer")

    print(f"Validated {n} candidate row(s) against schema '{schema}'.")
    if errors:
        print(f"\nREJECTED {len(errors)} issue(s) — fix or drop these rows:")
        for e in errors:
            print(f"  - {e}")
        print("\nAnti-fabrication gate FAILED. No row without provenance may be merged.")
        return 1
    print("All rows carry provenance (source_url + as_of_period). PASS.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate Option A candidate rows.")
    ap.add_argument("--schema", required=True, choices=sorted(REQUIRED.keys()))
    ap.add_argument("candidates", help="path to candidate CSV")
    args = ap.parse_args()
    return validate(args.schema, args.candidates)


if __name__ == "__main__":
    sys.exit(main())
