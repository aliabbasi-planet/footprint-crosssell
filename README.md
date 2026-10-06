# Footprint Cross-Sell - Option A

A Streamlit dashboard and dbt pipeline for comparing Planet's internal footprint
with sourced external brand footprints. It shows country gaps, operator leads,
and estimated additional revenue at selected capture scenarios.

**Start here:** [Install and run the app](apps/streamlit/README.md). Both `dev` and
`optionA` contain the current app and use the same commands below.

## Requirements

- Git and **Python 3.11** (the tested local runtime).
- A browser and an authorized Snowflake login, normally using browser SSO.
- An existing Snowflake warehouse and access to the Option A marts. Installing
  Python packages does **not** create the data or grant database access.

The local app requirements are in
[`apps/streamlit/requirements.txt`](apps/streamlit/requirements.txt). They include
Streamlit, pandas, Altair, the Snowflake connector, PyArrow, and keyring for secure
local SSO caching. Direct dependencies are pinned; transitive dependencies are
resolved during installation. dbt, Snowpark, and Snowflake CLI are not required
just to view the local dashboard.

## Quick start: Windows PowerShell

Run these commands in **PowerShell**, not in the Python interpreter. Run each
line separately and stop if a command reports an error. Do not copy the `PS>`
prompt. Virtual-environment activation is not needed.

### 1. Clone and install

```powershell
git clone --branch optionA https://github.com/aliabbasi-planet/footprint-crosssell.git
Set-Location footprint-crosssell
py -3.11 -m venv .venv
& .\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\.venv\Scripts\python.exe -m pip install -r .\apps\streamlit\requirements.txt
& .\.venv\Scripts\python.exe -m pip check
```

Use `--branch dev` instead to clone `dev`. If you already have the repository and
`.venv`, do not clone or recreate them: start at the two install commands and the
`pip check` command from the repository root. If an existing uv-created venv
reports `No module named pip`, first run:

```powershell
& .\.venv\Scripts\python.exe -m ensurepip --upgrade
```

### 2. Configure your Snowflake connection

Follow the [password-free SSO setup](apps/streamlit/README.md#configure-snowflake-sso)
in the app README. The example creates a connection named `footprint-local` in
**your home directory**, not in this repository. If you already have a connection
such as `EHJCFME-DS90480`, use that exact connection name instead.

### 3. Start the app

From the **repository root**, paste the following as **one complete line**.
Replace `footprint-local` with your configured connection name; keep the semicolons.

```powershell
$env:SNOWFLAKE_DEFAULT_CONNECTION_NAME="footprint-local"; Set-Location ".\apps\streamlit"; & "..\..\.venv\Scripts\python.exe" -m streamlit run ".\streamlit_app.py" --server.address 127.0.0.1 --server.port 8501 --server.headless true
```

Wait for the startup message, leave the terminal running, then open
**http://127.0.0.1:8501** in your browser. Complete the Snowflake SSO sign-in when
prompted. The app path is `apps/streamlit/streamlit_app.py`; the venv directory is
`.venv` **with a leading dot**. Stop the server with `Ctrl+C` in its terminal.

For macOS/Linux commands, updates, health checks, and troubleshooting, see the
[full app guide](apps/streamlit/README.md).

## Verify locally without Snowflake credentials

From the repository root, after installing requirements:

```powershell
& .\.venv\Scripts\python.exe -m pip check
& .\.venv\Scripts\python.exe -m unittest discover -s apps/streamlit/tests -p "test_*.py" -v
```

The tests use explicitly synthetic fixtures, never live merchant data. They
exercise the actual app's rendering, filters, capture scenarios, optional
briefings, and error states. They do not open Snowflake sessions or generate AI
briefings. Passing them is **not** a verification of source figures or database
permissions.

## Data and scope

The current research scope is nine merchants:

- F&B: Starbucks, SSP, Burger King / King Foods.
- Hospitality: Accor, Marriott, Four Seasons.
- Retail: Luxottica, Dolce & Gabbana, Subdued.

The default data location is `DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT`. The app
requires `MART_FOOTPRINT_COVERAGE`, `MART_COUNTRY_WHITESPACE`, and
`MART_OPERATOR_OPPORTUNITIES`. `MART_MERCHANT_NARRATIVES` is optional; if it is
unavailable, the other tabs still work. Database/schema overrides are documented
in the app guide.

The revenue figures are **planning estimates**, not booked revenue or forecasts:
unserved units multiplied by Planet's per-store benchmark and a capture scenario.
Country-level estimates need sourced country counts. Internal terminal/location
counts are not necessarily comparable to published stores or hotel properties.
Source links and reporting periods support review; their presence alone does not
prove a figure has been independently verified.

## Repository layout

```text
apps/streamlit/                 Dashboard, local requirements, tests and run guide
transform/                     dbt models, seeds, snapshots and tests
  models/_legacy/              Disabled earlier implementation
agent/option_a_discovery/       Candidate validation and seed-merge helpers
.cortex/skills/option-a-discovery/  Discovery workflow instructions
sql/                           Setup and optional Snowflake feature scripts
.github/workflows/             Existing PR, deployment and provenance checks
```

`docs/` and `external-docs/` are deliberately **local-only and git-ignored**.
They are not required to install, run, or test the app. Do not force-add them,
local connection files, credentials, build outputs, or `.venv` to Git.

## Pipeline and deployment are separate

The app reads already-built tables; it does not build dbt models, research new
merchants, or call an AI model when someone opens a tab. A data owner must build
the Option A pipeline if the marts are absent. dbt development uses separate
tooling and connection configuration; do not install it into the app venv just
to view the dashboard.

The source registry gates which acquisition adapters are enabled. Provenance
validation checks required citation fields, not the truth of the cited claims.
See the [discovery helper guide](agent/option_a_discovery/README.md).

Existing GitHub workflows retain their current triggers: PR checks target
`main`; deployment targets `main` and version tags `v*`. Pushing `dev` or
`optionA` does not deploy the app or rebuild Snowflake data. PR checks include
local app installation/tests and public README checks; database-related jobs
still require repository-managed Snowflake authentication.

Local installation does not configure a hosted Streamlit deployment. The
[app guide](apps/streamlit/README.md#snowflake-hosted-deployment) explains the
separate runtime files and the account-specific deployment prerequisites.
