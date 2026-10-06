# Footprint Cross-Sell dashboard: install and run

This guide covers running the **Option A Streamlit app on your own computer**.
Use the same instructions on `optionA` and `dev`. The entry point is
`apps/streamlit/streamlit_app.py`, not a file at the repository root.

The dashboard reads existing Snowflake marts. It does not create them, research
new merchants, or generate AI briefings at startup. You need an authorized
Snowflake connection even though the code repository is public.

## Prerequisites

- Git and **Python 3.11**, the tested Python version.
- Internet access to install packages and reach Snowflake and your identity provider.
- A browser for SSO and the dashboard.
- An existing Snowflake connection with access to the warehouse and marts listed
  under [Data requirements](#data-requirements). Ask the data owner for the correct
  account, login name, role, and warehouse; do not guess or reuse someone else's login.

No Docker, database server, Snowflake CLI, or dbt installation is needed to run
this app against already-built marts. Snowpark is used by the Snowflake-hosted
runtime, but the local path uses the Python connector instead.

The local requirements pin Streamlit, pandas, Altair, the Snowflake connector,
PyArrow, and keyring. The connector includes the `pandas` and
`secure-local-storage` extras. These are direct dependency pins, not a complete
transitive lockfile. The commands below install their dependencies automatically.

## Windows PowerShell setup

Run each command on its own line, in order. If one fails, stop and address its
terminal error before continuing. Do not paste a `PS>` prompt or concatenate
separate commands without semicolons. These commands use the venv's Python
directly, so **activation and execution-policy changes are unnecessary**.

### 1. Clone either branch

```powershell
git clone --branch optionA https://github.com/aliabbasi-planet/footprint-crosssell.git
Set-Location footprint-crosssell
```

Use `--branch dev` instead for `dev`. If the repo is already cloned, open a
PowerShell terminal in its root instead of cloning again.

### 2. Create the venv and install requirements

Run from the repository root:

```powershell
py -3.11 --version
py -3.11 -m venv .venv
& .\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\.venv\Scripts\python.exe -m pip install -r .\apps\streamlit\requirements.txt
& .\.venv\Scripts\python.exe -m pip check
```

Expected last output: `No broken requirements found.` The folder is `.venv`, not
`venv`. If the Windows `py` launcher is unavailable, use `python --version` to
confirm Python 3.11 and then `python -m venv .venv`.

For an existing `.venv`, skip creation and run the install/check commands. Some
uv-created environments do not include pip; add it to that venv, not to system
Python:

```powershell
& .\.venv\Scripts\python.exe -m ensurepip --upgrade
```

If you already use uv, the equivalent fresh setup is:

```powershell
uv venv --python 3.11 --seed .venv
uv pip install --python .\.venv\Scripts\python.exe -r .\apps\streamlit\requirements.txt
uv pip check --python .\.venv\Scripts\python.exe
```

Use **one** setup route. Do not recreate an existing environment while its app is
running. There is no project `pyproject.toml`, so `uv sync` is not the setup command.

## Configure Snowflake SSO

Streamlit uses the **Snowflake Python connector's** connections file, not a
Snowflake CLI `config.toml` and not the VS Code extension's active connection.

If you already have a working entry in your home `.snowflake/connections.toml`,
reuse its exact section name. For example, an entry `[EHJCFME-DS90480]` means the
launch command should set `SNOWFLAKE_DEFAULT_CONNECTION_NAME` to `EHJCFME-DS90480`.
The connection name is a local label; it is not necessarily your account identifier.

For a new local connection on Windows, create the home directory if needed and
open the file. **Append a new section; do not overwrite existing connections.**

```powershell
New-Item -ItemType Directory -Force "$HOME\.snowflake" | Out-Null
notepad "$HOME\.snowflake\connections.toml"
```

Example **password-free** SSO entry:

```toml
[footprint-local]
account = "YOUR_ORGANIZATION-YOUR_ACCOUNT"
user = "YOUR_LOGIN_NAME"
authenticator = "externalbrowser"
role = "DATA_SCIENTIST"
warehouse = "DATA_SCIENCE"
database = "DEV_PRESENTATION_AAB"
schema = "CROSSSELL_FOOTPRINT"
```

Replace the account and login placeholders. The role, warehouse and database
above are this project's defaults; use the values authorized for your own
account. Include a `host` only if your administrator supplies one. Do not put
passwords, tokens, or private keys in this example or in the repository.

Use `SNOWFLAKE_DEFAULT_CONNECTION_NAME` when launching, **not**
`SNOWFLAKE_CONNECTION_NAME`. No project `.streamlit/secrets.toml` is needed for
this setup. A pre-existing `[connections.snowflake]` section in a Streamlit
secrets file can override the connector-default path; avoid conflicting settings.

`keyring` enables secure local token caching where the operating system and
Snowflake policies allow it. It does not bypass SSO or guarantee zero future
sign-ins. A Linux desktop may also need a supported OS keyring service; without
one, authentication may still work but need repeated sign-ins.

## Run on Windows

### From the repository root

After configuring the connection, copy this as **one whole line**. Change only
`footprint-local` if your connection has a different name. Keep every semicolon:

```powershell
$env:SNOWFLAKE_DEFAULT_CONNECTION_NAME="footprint-local"; Set-Location ".\apps\streamlit"; & "..\..\.venv\Scripts\python.exe" -m streamlit run ".\streamlit_app.py" --server.address 127.0.0.1 --server.port 8501 --server.headless true
```

This changes the working directory so Streamlit reads
`apps/streamlit/.streamlit/config.toml` and applies the project theme.

### Restart when your terminal is already in `apps\streamlit`

Do not repeat `Set-Location .\apps\streamlit` from inside that folder. Use:

```powershell
$env:SNOWFLAKE_DEFAULT_CONNECTION_NAME="footprint-local"; & "..\..\.venv\Scripts\python.exe" -m streamlit run ".\streamlit_app.py" --server.address 127.0.0.1 --server.port 8501 --server.headless true
```

### What to expect

1. Wait for the terminal's server-started message and URL.
2. Open **http://127.0.0.1:8501** in a normal browser. Headless mode means Streamlit
   does not open that page automatically.
3. On the first data load, a browser sign-in window may open for Snowflake SSO.
   Complete it and return to the dashboard. An already-valid session can avoid
   a new prompt.
4. **Keep the terminal open.** Closing it or stopping the process stops the app.
5. Stop the server with `Ctrl+C` in the terminal that runs it.

The app binds only to your laptop's loopback interface. Do not expose it to the
network by changing the address to `0.0.0.0` without an appropriate authentication
and access-control design.

## macOS / Linux

The following are Bash/Zsh commands, **not PowerShell**. Python 3.11 must already
be installed. The local setup has been verified on Windows; these equivalent
commands are provided for other systems, not a claim of cross-platform testing.

```bash
git clone --branch optionA https://github.com/aliabbasi-planet/footprint-crosssell.git
cd footprint-crosssell
python3.11 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -r apps/streamlit/requirements.txt
.venv/bin/python -m pip check
```

Create `~/.snowflake/` if it does not exist, and use a text editor to add the
password-free connection section above to `~/.snowflake/connections.toml`.
Keep the file private to your user. Then, from the repository root:

```bash
cd apps/streamlit
SNOWFLAKE_DEFAULT_CONNECTION_NAME=footprint-local ../../.venv/bin/python -m streamlit run streamlit_app.py --server.address 127.0.0.1 --server.port 8501 --server.headless true
```

Open http://127.0.0.1:8501 and complete SSO when requested. If you are already in
`apps/streamlit`, omit the `cd` line when restarting.

## Data requirements

Default location: **`DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT`**.

| Mart | Required? | Purpose |
|---|---|---|
| `MART_FOOTPRINT_COVERAGE` | Yes | Merchant footprint and coverage |
| `MART_COUNTRY_WHITESPACE` | Yes | Country gaps and estimated values |
| `MART_OPERATOR_OPPORTUNITIES` | Yes | Operator leads and relationship context |
| `MART_MERCHANT_NARRATIVES` | No | Pre-generated AI briefings |

Your configured Snowflake role needs access to these objects and a usable query
warehouse. Ask the data owner to provision access or build missing marts; the
app does not create permissions, schemas or data. A dbt build is a separate data
engineering operation and can run AI generation and incur Snowflake charges.

To read equivalent marts in a different location, set these **non-secret**
variables before launching (and replace the example names):

```powershell
$env:FOOTPRINT_DB="YOUR_DATABASE"
$env:FOOTPRINT_SCHEMA="YOUR_SCHEMA"
```

Bash/Zsh equivalents:

```bash
export FOOTPRINT_DB="YOUR_DATABASE"
export FOOTPRINT_SCHEMA="YOUR_SCHEMA"
```

Restart the server after changing connection settings or target variables.
Loading/rerunning the app may query Snowflake and use warehouse credits. The
cached UI does not itself rebuild the marts or call an AI model.

## Verify the installation

From the repository root, these commands require no Snowflake login:

```powershell
& .\.venv\Scripts\python.exe -m pip check
& .\.venv\Scripts\python.exe -c "import streamlit, pandas, altair, snowflake.connector, pyarrow, keyring; print('All app imports OK')"
& .\.venv\Scripts\python.exe -m unittest discover -s apps/streamlit/tests -p "test_*.py" -v
```

On macOS/Linux replace `& .\.venv\Scripts\python.exe` with `.venv/bin/python`.
The tests use synthetic fixtures and mock Snowflake access. They check the
actual app's rendering and filters, including empty/error states, but do not
validate live figures, sources, database permissions or SSO. Streamlit may log
`missing ScriptRunContext` or `No runtime found` during these headless tests;
those messages alone are not a failed test. Check the final test result.

While the app is running, use a **second terminal** to check server health:

```powershell
curl.exe --fail --show-error --max-time 5 http://127.0.0.1:8501/_stcore/health
```

Use `curl` rather than `curl.exe` on macOS/Linux. The expected body is `ok`.
This confirms the web server is reachable; it does **not** prove Snowflake data
loaded. Open the dashboard and check its visible content too.

## Troubleshooting

| Symptom | What to do |
|---|---|
| `ERR_CONNECTION_REFUSED` | The browser cannot reach a listening server. Check the terminal first; wait for startup and keep it running. Use the printed host/port. If startup failed, report that terminal error, not only the browser message. |
| `File does not exist: streamlit_app.py` | The entry point is in `apps/streamlit`. Use the root launch command above. |
| `Set-Location ... accepts argument '='` | Multiple commands were concatenated without separators. Copy the single-line launch command with every `;` intact. |
| `venv\Scripts\python.exe` is not recognized | The folder is `.venv` with a leading dot. Check your working directory and complete the install step. |
| `streamlit` is not recognized / imports missing | Use the explicit `.venv` Python commands rather than a globally installed `streamlit`. Reinstall from `requirements.txt` and run `pip check`. |
| `No module named pip` in an existing venv | Run that venv's Python with `-m ensurepip --upgrade`, then install requirements. |
| Port 8501 already in use | Stop your previous app instance, or choose `--server.port 8502` and open `http://127.0.0.1:8502`. Do not assume the port changes automatically. |
| `keyring` missing warning | Reinstall the requirements into the same `.venv` and restart. The secure-local-storage extra and keyring are included. OS keyring or SSO policy issues can still cause repeat sign-ins. |
| Connection entry not found / wrong account | Check the section name in your home `connections.toml` and `SNOWFLAKE_DEFAULT_CONNECTION_NAME`; an IDE connection or CLI config alone is not sufficient. Restart after changes. |
| Database, schema or mart unavailable | Check the configured role and target names with the data owner. Installing more Python packages does not solve missing data or access. |
| Repeated `use_container_width` warnings | Update to the current app; it uses `width="stretch"`. Restart after updating dependencies. |
| SSO request appears to hang | Finish sign-in in your existing browser windows. If there is no prompt, inspect the terminal locally. Do not paste the long authentication URL or tokens into tickets or public logs. |

Before updating an existing checkout, stop its app, preserve your own edits, and
run `git pull --ff-only` on the branch you use. Re-run the requirements install,
`pip check`, and offline tests before restarting. Do not use a hard reset to
resolve a divergent checkout, particularly if it predates the documentation
history cleanup.

## Files and privacy

- `streamlit_app.py`: dashboard and SiS/local connection selection.
- `requirements.txt`: local Python dependencies, including SSO-cache support.
- `tests/test_app.py`: offline tests; fixtures are not external research data.
- `.streamlit/config.toml`: project theme.
- `environment.yml`: separate Snowflake warehouse-runtime package specification.
- `snowflake.yml`: separate Snowflake container-runtime deployment manifest.

`.venv/`, local Streamlit secrets, `docs/`, and `external-docs/` are git-ignored.
The private document folders are not part of installation or test requirements.
Never commit connection credentials, authentication URLs, cached tokens or keys.

## Snowflake-hosted deployment

Running `streamlit run` locally does **not** deploy the app to Snowflake.

The existing `snowflake.yml` describes the container-runtime deployment and
still has an account-specific `compute_pool` placeholder. Do not run it as-is:
a deployment owner must resolve the pool and privileges, confirm available
runtime/package versions support the app, verify all listed artifacts, and then
use the Snowflake deployment workflow. The local `requirements.txt` is not in
its artifacts list; adding a pip dependency file to those artifacts introduces
additional package-resolution and external-access requirements.

`environment.yml` is for the separate Snowflake warehouse-runtime route. It is
not read by local `pip`, `uv`, or `streamlit run`. This local installation guide
does not claim a hosted deployment has been executed or verified.
