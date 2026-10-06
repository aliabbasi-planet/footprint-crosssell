"""Offline UI regression tests; every record below is synthetic test data.

These fixtures are not merchant research, are never loaded by the real app, and
must not be used as external evidence. No Snowflake connection is opened.
"""

from pathlib import Path
import json
import types
import unittest
from unittest.mock import Mock, patch

import pandas as pd
import streamlit as st
from streamlit.testing.v1 import AppTest


APP_PATH = Path(__file__).resolve().parents[1] / "streamlit_app.py"
SOURCE_URL = "https://example.invalid/test-fixture"


def fixture_marts():
    """Small, uppercase-column stand-ins for the four Snowflake result sets."""
    coverage = pd.DataFrame([
        {
            "merchant": merchant,
            "vertical": vertical,
            "planet_countries": 1,
            "brand_total_countries": 3,
            "country_coverage_pct": 33.3,
            "country_whitespace_count": 2,
            "planet_stores": 2,
            "brand_total_units": 20,
            "store_coverage_pct": 10.0,
            "former_only_countries": 1,
            "shared_location_stores": 0,
            "former_stores": 2,
            "brand_source_name": "Synthetic test source",
            "brand_as_of_period": "2026-01-01",
            "brand_source_tier": "A",
            "brand_source_url": SOURCE_URL,
        }
        for merchant, vertical in [
            ("Test Brand Alpha", "F&B"),
            ("Test Brand Beta", "Retail"),
        ]
    ])
    whitespace = pd.DataFrame([
        {
            "merchant": merchant,
            "country": country,
            "region": region,
            "gap_kind": gap_kind,
            "external_units": internal + gap,
            "internal_stores": internal,
            "former_planet_stores": 2 if gap_kind == "WIN_BACK" else 0,
            "gap_units": gap,
            "benchmark_per_store_eur": benchmark,
            "benchmark_basis": "Synthetic test benchmark",
            "value_full_eur": gap * benchmark,
            "value_25pct_eur": gap * benchmark * 0.25,
            "value_10pct_eur": gap * benchmark * 0.10,
            "source_name": "Synthetic test source",
            "as_of_period": "2026-01-01",
            "source_tier": "A",
            "source_url": SOURCE_URL,
        }
        for merchant, country, region, gap_kind, internal, gap, benchmark in [
            ("Test Brand Alpha", "Test Country West", "Test West", "DEPTH", 2, 10, 100),
            ("Test Brand Alpha", "Test Country East", "Test East", "WIN_BACK", 0, 8, 100),
            ("Test Brand Beta", "Test Country East", "Test East", "NEW_COUNTRY", 0, 20, 200),
        ]
    ])
    operators = pd.DataFrame([
        {
            "priority_rank": rank,
            "merchant": merchant,
            "country": country,
            "region": region,
            "operator_name": operator,
            "operator_role": "Synthetic test operator",
            "operator_is_planet_client": warm,
            "operator_served_by_planet_in": "Test Country West" if warm else None,
            "opportunity_type": "WARM_INTRO_EXISTING_OPERATOR" if warm else "NEW_OPERATOR_NEW_COUNTRY",
            "gap_status": gap_status,
            "external_units": gap,
            "internal_stores": 0,
            "gap_units": gap,
            "est_gap_value_25pct_eur": value,
            "evidence": "Synthetic fixture, not external evidence",
            "source_url": SOURCE_URL,
        }
        for rank, merchant, country, region, operator, warm, gap_status, gap, value in [
            (1, "Test Brand Alpha", "Test Country West", "Test West", "Test Operator A", True, "OPEN_GAP", 10, 250),
            (2, "Test Brand Beta", "Test Country East", "Test East", "Test Operator B", False, "OPEN_GAP", 20, 1000),
            (3, "Test Brand Alpha", "Test Country North", "Test East", "Test Operator A", True, "UNSIZED", None, None),
        ]
    ])
    narratives = pd.DataFrame([
        {
            "merchant": merchant,
            "country_whitespace_count": 2,
            "narrative": json.dumps(f"Test-only briefing for {merchant}."),
            "model_used": "test-fixture-no-ai-call",
            "generated_at": "2026-01-01T00:00:00Z",
            "grounding_prompt": "Synthetic grounding text for UI testing only.",
        }
        for merchant in coverage["merchant"]
    ])
    return {
        name: frame.rename(columns=str.upper)
        for name, frame in {
            "MART_FOOTPRINT_COVERAGE": coverage,
            "MART_COUNTRY_WHITESPACE": whitespace,
            "MART_OPERATOR_OPPORTUNITIES": operators,
            "MART_MERCHANT_NARRATIVES": narratives,
        }.items()
    }


class AppSmokeTests(unittest.TestCase):
    def setUp(self):
        st.cache_data.clear()
        self.addCleanup(st.cache_data.clear)
        self.marts = fixture_marts()
        self.unavailable = set()

        # Force the local connector path even if Snowpark happens to be installed.
        context = types.ModuleType("snowflake.snowpark.context")
        context.get_active_session = Mock(side_effect=RuntimeError("Offline test"))
        self.enterContext(patch.dict("sys.modules", {context.__name__: context}))
        self.enterContext(patch.dict("os.environ", {
            "FOOTPRINT_DB": "TEST_DB",
            "FOOTPRINT_SCHEMA": "TEST_SCHEMA",
        }))
        self.query = Mock(side_effect=self.query_fixture)
        self.connection = self.enterContext(patch(
            "streamlit.connection", return_value=types.SimpleNamespace(query=self.query)
        ))
        self.app = AppTest.from_file(str(APP_PATH), default_timeout=30)

    def query_fixture(self, sql):
        table_name = sql.rsplit(".", 1)[-1]
        if table_name in self.unavailable:
            raise RuntimeError("Fixture unavailable for test")
        return self.marts[table_name].copy()

    def run_app(self):
        self.app.run()
        self.assertFalse(self.app.exception, [error.message for error in self.app.exception])
        return self.app

    def select_filter(self, label, values):
        widget = next(widget for widget in self.app.multiselect if widget.label == label)
        widget.set_value(values)
        return self.run_app()

    def metric_value(self, label):
        return next(metric.value for metric in self.app.metric if metric.label == label)

    def table_with(self, column):
        return next(table.value for table in self.app.dataframe if column in table.value.columns)

    def test_all_tabs_render_without_credentials(self):
        self.run_app()
        self.assertFalse(self.app.error)
        self.assertEqual(len(self.app.tabs), 6)
        self.assertEqual(len(self.app.dataframe), 5)
        self.assertEqual(len(self.app.get("download_button")), 4)
        self.assertEqual(self.metric_value("Merchants in view"), "2")
        self.assertEqual(self.query.call_count, 4)
        self.connection.assert_called_with("snowflake")
        self.query.assert_any_call("select * from TEST_DB.TEST_SCHEMA.MART_FOOTPRINT_COVERAGE")
        self.assertTrue(any(
            item.value == "Test-only briefing for Test Brand Alpha."
            for item in self.app.markdown
        ))

    def test_merchant_filter_updates_value_and_tables(self):
        self.run_app()
        self.select_filter("Merchant", ["Test Brand Alpha"])
        self.assertEqual(self.metric_value("Merchants in view"), "1")
        self.assertEqual(self.metric_value("Sized pipeline @25%"), "\u20ac450")
        self.assertEqual(set(self.table_with("benchmark_basis")["merchant"]), {"Test Brand Alpha"})

    def test_empty_merchant_selection_means_all(self):
        self.run_app()
        self.select_filter("Merchant", [])
        self.assertEqual(self.metric_value("Merchants in view"), "2")

    def test_region_filter_updates_sized_value(self):
        self.run_app()
        self.select_filter("Region", ["Test West"])
        self.assertEqual(self.metric_value("Sized pipeline @25%"), "\u20ac250")
        self.assertEqual(set(self.table_with("benchmark_basis")["region"]), {"Test West"})

    def test_ten_percent_scenario(self):
        self.run_app()
        self.app.radio[0].set_value("10% capture")
        self.run_app()
        self.assertEqual(self.metric_value("Sized pipeline @10%"), "\u20ac580")
        self.assertIn("value_10pct_eur", self.table_with("benchmark_basis").columns)

    def test_ceiling_scenario(self):
        self.run_app()
        self.app.radio[0].set_value("100% (ceiling)")
        self.run_app()
        self.assertIn("value_full_eur", self.table_with("benchmark_basis").columns)
        self.assertEqual(self.table_with("benchmark_basis")["value_full_eur"].sum(), 5800)

    def test_gap_kind_filter(self):
        self.run_app()
        self.select_filter("Gap kind", ["Win-back"])
        self.assertEqual(set(self.table_with("benchmark_basis")["gap_kind_label"]), {"Win-back"})
        self.assertEqual(self.metric_value("Value @25%"), "\u20ac200")

    def test_warm_only_filters_operator_table(self):
        self.run_app()
        self.app.toggle[0].set_value(True)
        self.run_app()
        operators = self.table_with("evidence")
        self.assertEqual(len(operators), 2)
        self.assertTrue(operators["operator_is_planet_client"].all())

    def test_empty_filtered_results_render_information(self):
        self.run_app()
        self.select_filter("Merchant", ["Test Brand Beta"])
        self.select_filter("Region", ["Test West"])
        self.assertFalse(self.app.error)
        self.assertEqual(self.metric_value("Sized pipeline @25%"), "\u20ac0")
        self.assertTrue(any("No sized white-space" in item.value for item in self.app.info))

    def test_missing_optional_narratives_do_not_stop_app(self):
        self.unavailable.add("MART_MERCHANT_NARRATIVES")
        self.run_app()
        self.assertFalse(self.app.error)
        self.assertEqual(len(self.app.tabs), 6)
        self.assertTrue(any("Narratives not generated yet" in item.value for item in self.app.info))

    def test_required_mart_failure_shows_help(self):
        self.unavailable.add("MART_FOOTPRINT_COVERAGE")
        self.run_app()
        self.assertEqual(len(self.app.error), 1)
        self.assertIn("Could not load the Option A marts", self.app.error[0].value)
        self.assertEqual(len(self.app.tabs), 0)


if __name__ == "__main__":
    unittest.main()
