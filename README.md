# Footprint Cross-Sell — Native Snowflake PoC

Quantifies **cross-sell footprint** and **share-of-wallet** for Planet merchants using **Snowflake-native features only** (dbt Projects on Snowflake · Cortex · Streamlit · Tasks). No AWS / Bedrock / n8n.

This is a **monorepo**: dbt transformations, the Streamlit dashboard, setup SQL, CI/CD, and docs live together and ship as one unit.

## Start here
- **The plan:** [`docs/CrossSell_PoC_Native_Snowflake_Plan.md`](docs/CrossSell_PoC_Native_Snowflake_Plan.md)
- **Feasibility evidence:** [`docs/feasibility_evidence.md`](docs/feasibility_evidence.md)

## Layout
```
docs/            plan, evidence, model cards
transform/       dbt project (Core-compatible + Snowflake-native)
apps/streamlit/  Streamlit-in-Snowflake dashboard
sql/setup/       sandbox schemas, deploy DBT PROJECT, schedule Task
.github/         CI/CD workflows
```

## PoC scope
9 seed merchants across F&B (Starbucks, SSP, Burger King), Hospitality (Accor, Marriott, Four Seasons), Retail (Luxottica, Dolce & Gabbana, Subdued). All confirmed present in `DIM_CCL_CUSTOMER`.

Outputs (in `DEV_PRESENTATION_AAB.FOOTPRINT`):
- `mart_merchant_footprint` — served locations/volume by brand × country × product
- `mart_share_of_wallet` — product-portfolio share + DCC penetration per brand
- `mart_crosssell_opportunities` — scored, rule-based product gaps
- `mart_crosssell_narratives` — Cortex-written commercial narratives

## Quickstart
```bash
# 1. sandbox schemas
#    run sql/setup/00_sandbox_setup.sql in Snowflake

# 2a. native path (recommended)
cd transform
snow dbt deploy footprint_crosssell --database DEV_PRESENTATION_AAB --schema FOOTPRINT
snow sql -q "EXECUTE DBT PROJECT DEV_PRESENTATION_AAB.FOOTPRINT.FOOTPRINT_CROSSSELL args='build'"

# 2b. portable path (dbt Core)
pip install dbt-snowflake
cd transform && dbt deps && dbt build --target dev
```

See the plan doc §11 for the git-synced Workspace deployment (no local CLI required) and remote-push instructions.
