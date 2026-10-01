-- ============================================================================
-- scrape_store_locator.sql — Python UDTF that fetches a store-locator API
-- endpoint and returns structured location rows. For API endpoints that return
-- JSON, it parses directly. For HTML endpoints, it returns raw text for Cortex.
-- ============================================================================
CREATE OR REPLACE FUNCTION DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.SCRAPE_STORE_LOCATOR(
    brand STRING, url STRING, scrape_method STRING
)
RETURNS TABLE (
    brand_name   STRING,
    country      STRING,
    city         STRING,
    address      STRING,
    store_name   STRING,
    latitude     FLOAT,
    longitude    FLOAT,
    source_url   STRING,
    raw_content  STRING
)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'StoreLocatorScraper'
EXTERNAL_ACCESS_INTEGRATIONS = (CROSSSELL_WEB_ACCESS)
PACKAGES = ('requests')
AS
$$
import requests
import json

class StoreLocatorScraper:
    def __init__(self):
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (compatible; PlanetFootprintPoC/1.0)',
            'Accept': 'application/json, text/html',
        }

    def process(self, brand: str, url: str, scrape_method: str):
        if not url or scrape_method == 'CORTEX_INTEL':
            # No URL or Cortex-only brand — yield a marker row for Cortex processing
            yield (brand, None, None, None, None, None, None, None, f'CORTEX_INTEL_REQUIRED:{brand}')
            return

        try:
            resp = requests.get(url, headers=self.headers, timeout=20, allow_redirects=True)
            resp.raise_for_status()
            content = resp.text[:500000]

            if scrape_method == 'API':
                self._parse_api_response(brand, url, content)
                # Try JSON parse
                try:
                    data = json.loads(content)
                    yield from self._extract_from_json(brand, url, data)
                    return
                except json.JSONDecodeError:
                    pass

            # HTML or failed JSON — return raw for Cortex extraction
            yield (brand, None, None, None, None, None, None, url, content[:100000])

        except Exception as e:
            yield (brand, None, None, None, None, None, None, url, f'ERROR: {type(e).__name__}: {str(e)[:200]}')

    def _extract_from_json(self, brand, url, data):
        stores = []
        # Common JSON patterns for store locators
        if isinstance(data, dict):
            for key in ('stores', 'results', 'locations', 'hotels', 'data', 'result', 'items'):
                if key in data and isinstance(data[key], list):
                    stores = data[key]
                    break
            if not stores and 'result' in data and isinstance(data['result'], dict):
                for key in ('stores', 'results', 'locations'):
                    if key in data['result'] and isinstance(data['result'][key], list):
                        stores = data['result'][key]
                        break
        elif isinstance(data, list):
            stores = data

        for s in stores[:500]:  # cap at 500 per call
            yield (
                brand,
                self._get(s, 'country', 'countryCode', 'country_code', 'countryName'),
                self._get(s, 'city', 'locality', 'town'),
                self._get(s, 'address', 'streetAddress', 'street', 'addressLine1', 'formattedAddress'),
                self._get(s, 'name', 'storeName', 'store_name', 'title', 'hotelName'),
                self._get_float(s, 'latitude', 'lat', 'geo.lat'),
                self._get_float(s, 'longitude', 'lng', 'lon', 'geo.lng'),
                url,
                None
            )

    @staticmethod
    def _get(d, *keys):
        for k in keys:
            if '.' in k:
                parts = k.split('.')
                v = d
                for p in parts:
                    if isinstance(v, dict):
                        v = v.get(p)
                    else:
                        v = None
                        break
                if v is not None:
                    return str(v)
            elif isinstance(d, dict) and k in d and d[k] is not None:
                return str(d[k])
        return None

    @staticmethod
    def _get_float(d, *keys):
        for k in keys:
            if '.' in k:
                parts = k.split('.')
                v = d
                for p in parts:
                    if isinstance(v, dict):
                        v = v.get(p)
                    else:
                        v = None
                        break
            elif isinstance(d, dict):
                v = d.get(k)
            else:
                v = None
            if v is not None:
                try:
                    return float(v)
                except (ValueError, TypeError):
                    continue
        return None
$$;
