# Footprint Cross-Sell — Streamlit-in-Snowflake dashboard

Reads the four Option A marts and presents coverage, valued white-space, operator
opportunities, grounded AI briefings, and a full source list. Every external
figure is shown with its `source_url` + `as_of_period`.

## Files
- `streamlit_app.py` — the app (uses `get_active_session()` in SiS; falls back to
  `st.connection("snowflake")` for local runs).
- `.streamlit/config.toml` — Snowflake brand theme.
- `environment.yml` — dependency manifest for the **warehouse-runtime** path.
- `snowflake.yml` — manifest for the **container-runtime** `snow streamlit deploy` path.

## Deploy — pick one

### A. Snowsight / git-synced Workspace (simplest, no CLI, no compute pool)
Create a Streamlit app in Snowsight (or a git-synced Workspace), point it at
`streamlit_app.py`, set the app's database/schema to where the marts live
(`DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT`) and use `environment.yml` for packages.
This matches the repo's deployment story (README §11) and works with SSO.

### B. `snow streamlit deploy` (container runtime)
Requires the Snowflake CLI and a compute pool. First resolve the pool:
```bash
snow sql --format json -q "SHOW PARAMETERS LIKE 'DEFAULT_STREAMLIT_COMPUTE_POOL' IN ACCOUNT"
snow sql --format json -q "SHOW COMPUTE POOLS"
```
Set `compute_pool` in `snowflake.yml` to that pool, then:
```bash
cd apps/streamlit
snow streamlit deploy --replace
snow sql --format json -q "SHOW STREAMLITS LIKE 'FOOTPRINT_CROSSSELL_OPTION_A' IN ACCOUNT"
```

## Local preview
```bash
# .streamlit/secrets.toml with [connections.snowflake] (account/host/user/authenticator…)
uv run streamlit run streamlit_app.py
```
Override the target schema with env vars if needed:
`FOOTPRINT_DB`, `FOOTPRINT_SCHEMA`.

## Data dependency
The app expects these marts to exist (built by the dbt pipeline):
`MART_FOOTPRINT_COVERAGE`, `MART_COUNTRY_WHITESPACE`, `MART_OPERATOR_OPPORTUNITIES`,
`MART_MERCHANT_NARRATIVES`.
