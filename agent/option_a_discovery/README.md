# Option A Footprint Discovery Agent

A compliance-bounded research agent that gathers external footprint evidence for
the 9 PoC merchants from **Option A sources only** (brand-published disclosures +
public registers) and proposes a **provenance-complete seed update as a pull
request**. It never writes to Snowflake and never emits a figure without a source.

## Why it is built this way
- **Seeds, not direct writes.** The system-of-record for external data is the
  version-controlled `transform/seeds/ext_*.csv`. The agent proposes changes to
  those files via PR, so a human verifies every `source_url` before it reaches a
  mart. This *is* the anti-fabrication control.
- **Licence gate.** The agent reads `transform/seeds/external_source_registry.csv`
  and only uses tiers marked `enabled=true` (Option A today). Google Places (B),
  Marketplace POI (C) and scraping (D/E) stay off until Legal + licence sign-off.

## Files
| File | Purpose |
|---|---|
| `../../.cortex/skills/option-a-discovery/SKILL.md` | The agent's operating procedure (load this skill to run it) |
| `sources.yml` | Per-merchant Tier-A/Tier-B source playbook + seed schemas |
| `validate_candidates.py` | Anti-fabrication gate: rejects any row missing source_url / as_of_period / numeric count / known merchant |
| `merge_seed.py` | Upserts validated candidates into a seed CSV for review |

## Secrets (store before running register lookups)
```bash
cortex secret store COMPANIES_HOUSE_API_KEY   # free: developer.company-information.service.gov.uk
cortex secret store SEC_EDGAR_UA              # a contact string for the EDGAR User-Agent header
```
Tier-A filing research works with web_fetch alone; the register steps use these.

## Run it
1. Load the skill (`option-a-discovery`) and tell the agent which merchant(s) /
   dimension to refresh. It can fan out one research subagent per merchant.
2. The agent drafts a candidate CSV, then runs the gate:
   ```bash
   python agent/option_a_discovery/validate_candidates.py --schema country_units candidates.csv
   ```
3. On PASS, merge into the seed:
   ```bash
   python agent/option_a_discovery/merge_seed.py --schema country_units \
       --candidates candidates.csv --seed transform/seeds/ext_country_units.csv
   ```
4. Commit and open a PR: `data(option-a): refresh <merchant> footprint <as_of>`.
   The PR check re-runs the validator; review verifies each source_url; merge to
   `main` deploys to UAT via the dbt pipeline.

## Extending to Option B/C (when licensed)
Flip the registry row to `enabled=true`, add the tier to
`vars.enabled_source_tiers`, implement the matching adapter model
(`ext_google_places.sql` / `ext_marketplace_poi.sql`), and widen the skill's
allowed tools. The seed/PR flow and the anti-fabrication rule do not change.
