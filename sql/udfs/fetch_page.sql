-- ============================================================================
-- fetch_page.sql — Python UDF that fetches a web page and returns its text.
-- Requires the CROSSSELL_WEB_ACCESS external access integration (admin setup).
-- ============================================================================
CREATE OR REPLACE FUNCTION DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.FETCH_PAGE(url STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'fetch'
EXTERNAL_ACCESS_INTEGRATIONS = (CROSSSELL_WEB_ACCESS)
PACKAGES = ('requests')
AS
$$
import requests

def fetch(url: str) -> str:
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (compatible; PlanetFootprintPoC/1.0)',
            'Accept': 'text/html,application/json',
        }
        resp = requests.get(url, headers=headers, timeout=15, allow_redirects=True)
        resp.raise_for_status()
        # Truncate to 500KB to stay within Snowflake string limits
        return resp.text[:500000]
    except Exception as e:
        return f'ERROR: {type(e).__name__}: {str(e)[:200]}'
$$;
