#!/usr/bin/env python3
"""Merge validated Option A candidate rows into a dbt seed CSV (for a PR).

Upserts on the seed's natural key: existing keys are updated, new keys appended.
Prints an added/updated/unchanged summary. Writes in-place (or to --out) so the
change can be reviewed as a git diff and merged via pull request.

Usage:
    python merge_seed.py --schema country_units \
        --candidates candidates.csv \
        --seed ../../transform/seeds/ext_country_units.csv

Run validate_candidates.py FIRST — this script assumes candidates are valid.
Stdlib only.
"""
import argparse
import csv
import sys

KEYS = {
    "country_units": ["merchant", "country"],
    "brand_totals": ["merchant"],
    "operator_map": ["merchant", "country", "operator_name"],
}


def read_rows(path):
    with open(path, newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        return list(reader), (reader.fieldnames or [])


def key_of(row, keycols):
    return tuple((row.get(c) or "").strip().upper() for c in keycols)


def main() -> int:
    ap = argparse.ArgumentParser(description="Merge candidates into a seed CSV.")
    ap.add_argument("--schema", required=True, choices=sorted(KEYS.keys()))
    ap.add_argument("--candidates", required=True)
    ap.add_argument("--seed", required=True)
    ap.add_argument("--out", help="output path (default: overwrite --seed)")
    args = ap.parse_args()

    keycols = KEYS[args.schema]
    seed_rows, seed_cols = read_rows(args.seed)
    cand_rows, cand_cols = read_rows(args.candidates)

    extra = [c for c in cand_cols if c not in seed_cols]
    if extra:
        print(f"FAIL: candidate has columns not in the seed: {extra}")
        print(f"      seed columns: {seed_cols}")
        return 1

    index = {key_of(r, keycols): i for i, r in enumerate(seed_rows)}
    added, updated, unchanged = 0, 0, 0

    for cand in cand_rows:
        k = key_of(cand, keycols)
        merged = {c: (cand.get(c) if cand.get(c) not in (None, "") else "") for c in seed_cols}
        if k in index:
            existing = seed_rows[index[k]]
            # keep existing values for any columns the candidate left blank
            for c in seed_cols:
                if merged[c] == "" and existing.get(c) not in (None, ""):
                    merged[c] = existing[c]
            if {c: existing.get(c, "") for c in seed_cols} == merged:
                unchanged += 1
            else:
                seed_rows[index[k]] = merged
                updated += 1
        else:
            seed_rows.append(merged)
            index[k] = len(seed_rows) - 1
            added += 1

    out = args.out or args.seed
    with open(out, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=seed_cols)
        writer.writeheader()
        writer.writerows(seed_rows)

    print(f"Merged into {out}")
    print(f"  added:     {added}")
    print(f"  updated:   {updated}")
    print(f"  unchanged: {unchanged}")
    print(f"  total now: {len(seed_rows)}")
    print("\nReview the git diff and open a PR; every new source_url is verified at review.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
