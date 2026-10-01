# Footprint Cross-Sell — Native Snowflake PoC (Option A)

Quantifies **cross-sell footprint** and **share-of-wallet white-space** for 9 Planet
merchants using **Snowflake-native features only** (dbt · Cortex · Streamlit · Tasks).
No AWS / Bedrock / scraping.

This is a **monorepo**: dbt transformations, the Streamlit dashboard, the Option A
discovery agent, setup SQL, CI/CD, and docs ship as one unit.

## What this answers
For each merchant: **where does the brand operate that Planet does not yet serve, who
runs it there, and what is that gap worth** — valued with Planet's *own* realised
per-store economics. Every external number is traceable to a `source_url` + `as_of`.

## Merchants
F&B: Starbucks · SSP · Burger King / King Foods —
Hospitality: Accor · Marriott · Four Seasons —
Retail: Luxottica · Dolce & Gabbana · Subdued

## Architecture
```
seeds (source-of-truth, provenance)        external_source_registry  ← licence gate
  brand_resolution_rules                       (A active · B/C/D/E parked)
  ext_brand_totals / ext_country_units / ext_operator_map / dim_country_region
        │
staging (views)   stg_ccl_customer (clean passthrough), stg_ccl_revenue, …
        │
intermediate (tables)
  int_brand_resolution    ← MATCHING FIX (include−exclude+subbrands across fields)
  int_internal_footprint · int_value_benchmark
  int_external_footprint  ← unions only registry-ENABLED tiers (var: enabled_source_tiers)
        │
external adapters          ext_option_a_filings · ext_option_a_operators   (ACTIVE)
                           ext_google_places · ext_marketplace_poi          (PARKED)
        │
marts (tables)   mart_footprint_coverage · mart_country_whitespace ·
                 mart_operator_opportunities · mart_merchant_narratives (grounded AI_COMPLETE)
        │
serving          Streamlit-in-Snowflake  +  (optional) semantic view → Cortex Analyst
```

### The matching fix (`int_brand_resolution`)
The legacy model matched `BRAND ILIKE pattern` only — producing false positives
(Dolce→"Dolce by Wyndham", "passport"→SSP) and false negatives (sub-brands missed).
The new model matches **brand + customer_name + account** with include / exclude /
sub-brand rules (`brand_resolution_rules` seed). Verified on live data: Marriott
48→**59** countries, Accor 41→**66**, Luxottica 342→**1,978** stores; SSP correctly
loses "passport". Guarded by the `assert_no_excluded_brands` test.

### Licence / compliance extensibility
`external_source_registry.csv` + the `enabled_source_tiers` var gate every external
source. Option A is on. To add Google Places (B) or Marketplace POI (C) once Legal +
licence land: flip the registry row to `enabled=true`, add the tier to the var, and
fill the pre-built adapter stub — **no rework** downstream.

## Layout
```
transform/        dbt project (staging → intermediate → external → marts, seeds, snapshots, tests)
  models/_legacy/   superseded scraping/eligibility design (disabled; reactivates under Option D/E)
apps/streamlit/   Streamlit-in-Snowflake dashboard (coverage / white-space / operators / AI / sources)
agent/option_a_discovery/  compliance-bounded discovery agent (validator + merge scripts)
.cortex/skills/option-a-discovery/  the agent's SOP (load as a skill)
sql/dmf/          Data Metric Functions (observability)
sql/semantic/     optional semantic view for Cortex Analyst
.github/          CI/CD (pr-checks, deploy, agent-discovery)
docs/             plan, Option A investigation, evidence
```

## Quickstart
```bash
# dbt (local dev build). Developed on dbt Fusion 2.0; CI uses dbt-core >= 1.9.
cd transform
dbt deps
dbt build --target dev            # seeds + models + snapshots + tests (Option A only)

# anti-fabrication gate (also runs in CI)
python ../agent/option_a_discovery/validate_candidates.py --schema country_units seeds/ext_country_units.csv

# dashboard: deploy via Snowsight / Workspace (environment.yml) or `snow streamlit deploy`
#   see apps/streamlit/README.md

# optional, after the marts exist:
#   sql/dmf/footprint_dmfs.sql           -> table-level observability
#   sql/semantic/footprint_semantic_view.sql -> Cortex Analyst
```

## CI/CD
- **PR checks** (`pr-checks.yml`): dbt compile · sqlfluff (advisory) · **provenance gate** ·
  ruff · docs gate. Write-free.
- **Deploy** (`deploy.yml`): provenance gate → `dbt build` on **main → UAT**, **tag `v*` → PROD**
  (protected environment, key-pair JWT).
- **Agent discovery** (`agent-discovery.yml`): on-demand candidate validation + a quarterly
  provenance health check.

## Discovery agent
Runs in Cortex Code (load the `option-a-discovery` skill). It researches Option A sources
only, enforces that every figure has a `source_url` + `as_of`, and opens a **seed-update
PR** — never a direct write. See `agent/option_a_discovery/README.md`.

## Honest boundaries
Option A yields **where + who + how-much** (country counts, operators, Planet-benchmarked
value) — not site-level inventory. Internal counts are per-terminal/location (UID) and can
exceed brand published store/property counts, so **country coverage and white-space are the
comparable measures**; store-coverage % is directional for hospitality/retail. Site-level
precision needs the licensed/geocoded tiers (B/C), which are parked pending Legal.

## Docs
- Plan: [`docs/CrossSell_PoC_Native_Snowflake_Plan.md`](docs/CrossSell_PoC_Native_Snowflake_Plan.md)
- Option A investigation: [`docs/OptionA_Footprint_Gap_Investigation.md`](docs/OptionA_Footprint_Gap_Investigation.md)
- Legal/Risk: [`docs/aws_external_data_acquisition_legal_risk_report.md`](docs/aws_external_data_acquisition_legal_risk_report.md)
