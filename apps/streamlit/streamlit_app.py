"""
Footprint & Share-of-Wallet Cross-Sell — Option A
=================================================
Streamlit-in-Snowflake dashboard. Reads the Option A marts from
<DB>.<SCHEMA> (default DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT):

    mart_footprint_coverage      portfolio coverage per merchant
    mart_country_whitespace      valued white-space per merchant x country
    mart_operator_opportunities  ranked "who to call" list
    mart_merchant_narratives     grounded AI briefings

Every external figure shown carries its source_url + as_of period (Option A:
brand-published + public-register evidence only — no scraping, no paid API).

Design: decision-first (Action Center lands first), one global filter set in the
sidebar that drives every tab, consistent colour encodings for gap-kind and
operator warmth, ranked bars for "where is the value", and a CSV download on
every table so analysts can self-serve.
"""
from __future__ import annotations

import json
import os

import altair as alt
import pandas as pd
import streamlit as st

st.set_page_config(
    page_title="Footprint Cross-Sell — Option A",
    page_icon=":material/public:",
    layout="wide",
    initial_sidebar_state="expanded",
)

# -----------------------------------------------------------------------------
# Constants — brand palette mirrors .streamlit/config.toml; encodings are reused
# across every chart and legend so a colour always means the same thing.
# -----------------------------------------------------------------------------
DB = os.getenv("FOOTPRINT_DB", "DEV_PRESENTATION_AAB")
SCHEMA = os.getenv("FOOTPRINT_SCHEMA", "CROSSSELL_FOOTPRINT")
EUR = "\u20ac"
BLUE, NAVY = "#29B5E8", "#11567F"

# gap_kind -> (display label, colour). Distinct hues + text labels (never colour alone).
GAP_KIND = {
    "NEW_COUNTRY": ("New country", "#6554C0"),
    "WIN_BACK": ("Win-back", "#FF8B00"),
    "DEPTH": ("Depth (already present)", "#36B37E"),
}
GAP_KIND_LABEL = {k: v[0] for k, v in GAP_KIND.items()}
GAP_KIND_COLOR = {v[0]: v[1] for v in GAP_KIND.values()}

# Capture scenario -> white-space value column. 25% is the default planning case;
# 100% is explicitly a ceiling, never a forecast.
CAPTURE_COLS = {
    "10% capture": "value_10pct_eur",
    "25% capture (planning case)": "value_25pct_eur",
    "100% (ceiling)": "value_full_eur",
}
CAPTURE_SHORT = {
    "10% capture": "@10%",
    "25% capture (planning case)": "@25%",
    "100% (ceiling)": "@100% ceiling",
}


# -----------------------------------------------------------------------------
# Data layer — works in SiS (get_active_session) and locally (st.connection).
# -----------------------------------------------------------------------------
def _session():
    try:
        from snowflake.snowpark.context import get_active_session

        return get_active_session()
    except Exception:
        return None


@st.cache_data(ttl=600, show_spinner="Loading Option A marts from Snowflake…")
def load(table: str) -> pd.DataFrame:
    fqtn = f"{DB}.{SCHEMA}.{table}"
    sess = _session()
    if sess is not None:
        df = sess.table(fqtn).to_pandas()
    else:
        df = st.connection("snowflake").query(f"select * from {fqtn}")
    df.columns = [c.lower() for c in df.columns]
    return df


# -----------------------------------------------------------------------------
# Formatting helpers
# -----------------------------------------------------------------------------
def eur(x) -> str:
    try:
        return f"{EUR}{float(x):,.0f}"
    except (TypeError, ValueError):
        return "—"


def eur_compact(x) -> str:
    try:
        v = float(x)
    except (TypeError, ValueError):
        return "—"
    a = abs(v)
    if a >= 1e6:
        return f"{EUR}{v / 1e6:,.2f}M"
    if a >= 1e3:
        return f"{EUR}{v / 1e3:,.0f}k"
    return f"{EUR}{v:,.0f}"


def num(x) -> str:
    try:
        return f"{int(round(float(x))):,}"
    except (TypeError, ValueError):
        return "—"


def as_text(v) -> str:
    """mart_merchant_narratives.narrative is a VARIANT; snowpark returns it as a
    JSON-encoded string. Unwrap the outer quotes so it renders as prose."""
    if v is None:
        return ""
    if isinstance(v, str):
        s = v.strip()
        if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
            try:
                return json.loads(s)
            except Exception:
                return s
        return s
    return str(v)


def download(df: pd.DataFrame, label: str, filename: str, key: str) -> None:
    st.download_button(
        f":material/download: {label}",
        df.to_csv(index=False).encode("utf-8"),
        file_name=filename,
        mime="text/csv",
        key=key,
        width="stretch",
    )


def kpi(col, label: str, value: str, help: str | None = None) -> None:
    with col.container(border=True):
        st.metric(label, value, help=help)


def ranked_bar(
    df: pd.DataFrame,
    cat: str,
    val: str,
    title: str = "",
    height: int = 340,
    color_label_col: str | None = None,
    value_fmt: str = ",.0f",
) -> alt.Chart:
    """Horizontal ranked bar — the right encoding for 'where is the most value'."""
    tooltip = [alt.Tooltip(f"{cat}:N", title=None), alt.Tooltip(f"{val}:Q", format=value_fmt)]
    enc = dict(
        x=alt.X(f"{val}:Q", title=None, axis=alt.Axis(format="~s")),
        y=alt.Y(f"{cat}:N", sort="-x", title=None),
        tooltip=tooltip,
    )
    base = alt.Chart(df)
    if color_label_col:
        tooltip.append(alt.Tooltip(f"{color_label_col}:N", title="Gap kind"))
        enc["color"] = alt.Color(
            f"{color_label_col}:N",
            scale=alt.Scale(domain=list(GAP_KIND_COLOR), range=list(GAP_KIND_COLOR.values())),
            legend=alt.Legend(orient="bottom", title=None),
        )
        return base.mark_bar().encode(**enc).properties(height=height, title=title)
    return base.mark_bar(color=BLUE).encode(**enc).properties(height=height, title=title)


# -----------------------------------------------------------------------------
# Load marts
# -----------------------------------------------------------------------------
try:
    coverage = load("MART_FOOTPRINT_COVERAGE")
    whitespace = load("MART_COUNTRY_WHITESPACE")
    operators = load("MART_OPERATOR_OPPORTUNITIES")
    try:
        narratives = load("MART_MERCHANT_NARRATIVES")
    except Exception:
        narratives = pd.DataFrame()
except Exception as e:
    st.error(f"Could not load the Option A marts from {DB}.{SCHEMA}: {e}")
    st.info("Build the dbt pipeline (seeds + models) into this schema first, then reload.")
    st.stop()

# Derived display columns (stable, computed once)
whitespace = whitespace.copy()
whitespace["gap_kind_label"] = whitespace["gap_kind"].map(GAP_KIND_LABEL).fillna(whitespace["gap_kind"])

# -----------------------------------------------------------------------------
# Sidebar — the single, global filter set applied to every tab
# -----------------------------------------------------------------------------
with st.sidebar:
    st.markdown("### :material/filter_alt: Filters")
    all_merchants = sorted(coverage["merchant"].dropna().unique())
    sel_merchants = st.multiselect(
        "Merchant", all_merchants, default=all_merchants,
        help="Clearing this is treated as 'all merchants'.",
    )
    all_regions = sorted(
        pd.concat([whitespace.get("region"), operators.get("region")]).dropna().unique()
    )
    sel_regions = st.multiselect(
        "Region", all_regions, default=[],
        help="Empty = all regions. Applies to the white-space and operator views.",
    )
    capture = st.radio(
        "Capture scenario", list(CAPTURE_COLS), index=1,
        help="Values = un-served units x Planet's own per-store revenue. 25% is the "
             "planning case; 100% is a ceiling, not a forecast.",
    )
    warm_only = st.toggle(
        "Warm operators only", value=False,
        help="Operators Planet already serves somewhere (e.g. AmRest in Germany → Poland/Czechia).",
    )
    if st.button(":material/restart_alt: Reset filters", width="stretch"):
        st.session_state.clear()
        st.rerun()
    st.divider()
    st.caption(
        f"**Source:** `{DB}.{SCHEMA}`  \n"
        "Planet revenue to **Mar-2025**. External figures as published — see "
        "**Methodology & Sources**.  \nOption A evidence only (brand filings + public registers)."
    )

cap_col = CAPTURE_COLS[capture]
cap_short = CAPTURE_SHORT[capture]
sel_merchants = sel_merchants or all_merchants


def by_filters(df: pd.DataFrame, use_region: bool = True) -> pd.DataFrame:
    out = df[df["merchant"].isin(sel_merchants)] if "merchant" in df.columns else df
    if use_region and sel_regions and "region" in out.columns:
        out = out[out["region"].isin(sel_regions)]
    return out


cov_f = by_filters(coverage, use_region=False)
ws_f = by_filters(whitespace)
ops_f = by_filters(operators)
ws_gap = ws_f[ws_f["gap_units"] > 0]

# -----------------------------------------------------------------------------
# Header + portfolio KPI strip (reflects the sidebar filters)
# -----------------------------------------------------------------------------
st.title(":material/public: Footprint & Cross-Sell Intelligence")
st.caption(
    "Where do these merchants operate that Planet does not yet serve — and who runs them? "
    "Every number is traceable to a brand filing or public register."
)

sized_pipeline = float(ws_gap[cap_col].fillna(0).sum())
warm_open = int(((ops_f["operator_is_planet_client"]) & (ops_f["gap_status"] == "OPEN_GAP")).sum())
unsized_warm = int(((ops_f["operator_is_planet_client"]) & (ops_f["gap_status"] == "UNSIZED")).sum())

k = st.columns(5)
kpi(k[0], "Merchants in view", num(cov_f["merchant"].nunique()))
kpi(k[1], "Planet active locations", num(cov_f["planet_stores"].sum()),
    help="Active, de-duplicated locations per merchant, summed. A location carrying two "
         "PoC brands (e.g. an SSP-run Starbucks) counts once for each brand.")
kpi(k[2], "Countries not yet served", num(cov_f["country_whitespace_count"].sum()),
    help="Brand countries minus countries Planet already serves, summed across merchants.")
kpi(k[3], f"Sized pipeline {cap_short}", eur_compact(sized_pipeline),
    help="Only countries with a sourced unit count. Indicative planning value, not a forecast.")
kpi(k[4], "Warm plays w/ open gap", num(warm_open),
    help="Ranked operator plays where Planet already knows the operator and there is a sized gap.")

tab_action, tab_cov, tab_ws, tab_ops, tab_narr, tab_method = st.tabs(
    ["Action Center", "Coverage", "Valued White-space", "Operator Opportunities",
     "AI Briefings", "Methodology & Sources"]
)

# =============================================================================
# Action Center — decision-first: who to call, and where the value is
# =============================================================================
with tab_action:
    left, right = st.columns([1, 1], gap="large")

    with left:
        st.subheader(":material/handshake: Call these first — warm plays")
        st.caption("Operators Planet already serves, that have a sized un-served gap. Ranked by priority.")
        warm = ops_f[(ops_f["operator_is_planet_client"]) & (ops_f["gap_status"] == "OPEN_GAP")].copy()
        warm = warm.sort_values("priority_rank")
        if warm.empty:
            st.info("No warm plays with a sized gap under the current filters.")
        else:
            show = warm[[
                "priority_rank", "merchant", "country", "operator_name",
                "operator_served_by_planet_in", "gap_units", "est_gap_value_25pct_eur",
            ]].head(12)
            st.dataframe(
                show, width="stretch", hide_index=True,
                column_config={
                    "priority_rank": st.column_config.NumberColumn("#", width="small"),
                    "operator_name": st.column_config.TextColumn("Operator"),
                    "operator_served_by_planet_in": st.column_config.TextColumn("Already a Planet client in"),
                    "gap_units": st.column_config.NumberColumn("Un-served units", format="%d"),
                    "est_gap_value_25pct_eur": st.column_config.NumberColumn("Est. value @25%", format="€%.0f"),
                },
            )
        if unsized_warm:
            st.info(
                f":material/search: **{unsized_warm}** warm operator markets have no sourced unit "
                "count yet — a task for the Option A discovery agent to size.",
            )

    with right:
        st.subheader(f":material/trending_up: Biggest sized gaps {cap_short}")
        st.caption("Country-level white-space, valued with Planet's own per-store economics.")
        top = ws_gap.sort_values(cap_col, ascending=False).head(12).copy()
        if top.empty:
            st.info("No sized white-space under the current filters.")
        else:
            top["label"] = top["merchant"] + " · " + top["country"]
            st.altair_chart(
                ranked_bar(top, "label", cap_col, color_label_col="gap_kind_label",
                           value_fmt=",.0f", height=380),
                width="stretch",
            )

    st.divider()
    tot = st.columns(3)
    kpi(tot[0], f"Total sized gap {cap_short}", eur_compact(sized_pipeline),
        help="Sum of all sized country gaps in view at the chosen capture rate.")
    kpi(tot[1], "Un-served units (sized)", num(ws_gap["gap_units"].sum()))
    kpi(tot[2], "Sized country gaps", num(len(ws_gap)))

# =============================================================================
# Coverage — how much of each brand does Planet actually touch?
# =============================================================================
with tab_cov:
    st.subheader("Coverage vs the brand's published footprint")
    st.caption(
        "Country coverage is the comparable measure. Store coverage can exceed 100% for "
        "hospitality/retail because Planet's grain is per-terminal/location while brand totals "
        "are properties/boutiques."
    )
    if cov_f.empty:
        st.info("No merchants match the current filters.")
    else:
        chart_df = cov_f[["merchant", "country_coverage_pct"]].sort_values(
            "country_coverage_pct", ascending=False
        )
        st.altair_chart(
            alt.Chart(chart_df)
            .mark_bar(color=BLUE)
            .encode(
                x=alt.X("country_coverage_pct:Q", title="Country coverage %"),
                y=alt.Y("merchant:N", sort="-x", title=None),
                tooltip=[alt.Tooltip("merchant:N"), alt.Tooltip("country_coverage_pct:Q", format=".1f")],
            )
            .properties(height=320),
            width="stretch",
        )

        show = cov_f[[
            "merchant", "vertical", "planet_countries", "brand_total_countries", "country_coverage_pct",
            "country_whitespace_count", "planet_stores", "brand_total_units", "store_coverage_pct",
            "former_only_countries", "shared_location_stores", "former_stores",
            "brand_source_name", "brand_as_of_period", "brand_source_tier", "brand_source_url",
        ]].sort_values("country_whitespace_count", ascending=False)
        st.dataframe(
            show, width="stretch", hide_index=True,
            column_config={
                "merchant": st.column_config.TextColumn("Merchant"),
                "vertical": st.column_config.TextColumn("Vertical"),
                "planet_countries": st.column_config.NumberColumn("Planet countries"),
                "brand_total_countries": st.column_config.NumberColumn("Brand countries"),
                "country_coverage_pct": st.column_config.NumberColumn("Country cov %", format="%.1f%%"),
                "country_whitespace_count": st.column_config.NumberColumn("Countries not served"),
                "planet_stores": st.column_config.NumberColumn("Planet locations"),
                "brand_total_units": st.column_config.NumberColumn("Brand units"),
                "store_coverage_pct": st.column_config.NumberColumn("Store cov %", format="%.1f%%"),
                "former_only_countries": st.column_config.NumberColumn("Win-back countries"),
                "shared_location_stores": st.column_config.NumberColumn("Shared locations"),
                "former_stores": st.column_config.NumberColumn("Decommissioned terminals"),
                "brand_source_name": st.column_config.TextColumn("Brand source"),
                "brand_as_of_period": st.column_config.TextColumn("As of"),
                "brand_source_tier": st.column_config.TextColumn("Tier", width="small"),
                "brand_source_url": st.column_config.LinkColumn("Link", display_text="open"),
            },
        )
        download(show, "Download coverage (CSV)", "footprint_coverage.csv", key="dl_cov")

# =============================================================================
# Valued White-space
# =============================================================================
with tab_ws:
    st.subheader(f"Un-served units, valued with Planet's own per-store economics ({cap_short})")
    kinds = st.multiselect(
        "Gap kind", list(GAP_KIND_LABEL.values()), default=[],
        help="New country = never served · Win-back = only decommissioned terminals · "
             "Depth = served, more units to win. Empty = all.",
    )
    view = ws_gap.copy()
    if kinds:
        view = view[view["gap_kind_label"].isin(kinds)]
    view = view.sort_values(cap_col, ascending=False)

    if view.empty:
        st.info("No sized white-space matches the current filters.")
    else:
        m = st.columns(3)
        kpi(m[0], "Country rows", num(len(view)))
        kpi(m[1], "Un-served units", num(view["gap_units"].sum()))
        kpi(m[2], f"Value {cap_short}", eur_compact(view[cap_col].sum()))

        top = view.head(15).copy()
        top["label"] = top["merchant"] + " · " + top["country"]
        st.altair_chart(
            ranked_bar(top, "label", cap_col, title=f"Top countries by value {cap_short}",
                       color_label_col="gap_kind_label", height=420),
            width="stretch",
        )

        show = view[[
            "merchant", "country", "region", "gap_kind_label", "external_units", "internal_stores",
            "former_planet_stores", "gap_units", "benchmark_per_store_eur", "benchmark_basis",
            cap_col, "source_name", "as_of_period", "source_tier", "source_url",
        ]]
        st.dataframe(
            show, width="stretch", hide_index=True,
            column_config={
                "merchant": st.column_config.TextColumn("Merchant"),
                "country": st.column_config.TextColumn("Country"),
                "region": st.column_config.TextColumn("Region"),
                "gap_kind_label": st.column_config.TextColumn("Gap kind"),
                "external_units": st.column_config.NumberColumn("Brand units"),
                "internal_stores": st.column_config.NumberColumn("Planet now"),
                "former_planet_stores": st.column_config.NumberColumn("Former terminals"),
                "gap_units": st.column_config.NumberColumn("Un-served units"),
                "benchmark_per_store_eur": st.column_config.NumberColumn("Benchmark/store", format="€%.0f"),
                "benchmark_basis": st.column_config.TextColumn("Benchmark basis"),
                cap_col: st.column_config.NumberColumn(f"Value {cap_short}", format="€%.0f"),
                "source_name": st.column_config.TextColumn("Source"),
                "as_of_period": st.column_config.TextColumn("As of"),
                "source_tier": st.column_config.TextColumn("Tier", width="small"),
                "source_url": st.column_config.LinkColumn("Link", display_text="open"),
            },
        )
        download(show, "Download white-space (CSV)", "country_whitespace.csv", key="dl_ws")

# =============================================================================
# Operator Opportunities — the ranked "who to call" list
# =============================================================================
with tab_ops:
    st.subheader("Who runs each brand where — and does Planet already have the relationship?")
    ov = ops_f.copy()
    if warm_only:
        ov = ov[ov["operator_is_planet_client"]]
    ov = ov.sort_values("priority_rank")

    k2 = st.columns(4)
    kpi(k2[0], "Operator × country rows", num(len(ov)))
    kpi(k2[1], "Warm plays w/ open gap", num(warm_open))
    kpi(k2[2], "Unsized (agent task)", num(int((ops_f["gap_status"] == "UNSIZED").sum())),
        help="Operator known, but the brand's unit count for that country is not yet sourced.")
    kpi(k2[3], "Est. value @25% (shown)", eur_compact(ov["est_gap_value_25pct_eur"].fillna(0).sum()))

    if ov.empty:
        st.info("No operators match the current filters.")
    else:
        by_type = (
            ov[ov["est_gap_value_25pct_eur"] > 0]
            .groupby("opportunity_type", as_index=False)["est_gap_value_25pct_eur"].sum()
        )
        if not by_type.empty:
            st.altair_chart(
                ranked_bar(by_type, "opportunity_type", "est_gap_value_25pct_eur",
                           title="Est. value @25% by opportunity type", height=240),
                width="stretch",
            )

        show = ov[[
            "priority_rank", "merchant", "country", "operator_name", "operator_role",
            "operator_is_planet_client", "operator_served_by_planet_in", "opportunity_type",
            "gap_status", "external_units", "internal_stores", "gap_units",
            "est_gap_value_25pct_eur", "evidence", "source_url",
        ]]
        st.dataframe(
            show, width="stretch", hide_index=True,
            column_config={
                "priority_rank": st.column_config.NumberColumn("#", width="small"),
                "merchant": st.column_config.TextColumn("Merchant"),
                "country": st.column_config.TextColumn("Country"),
                "operator_name": st.column_config.TextColumn("Operator"),
                "operator_role": st.column_config.TextColumn("Role"),
                "operator_is_planet_client": st.column_config.CheckboxColumn("Warm?"),
                "operator_served_by_planet_in": st.column_config.TextColumn("Planet client in"),
                "opportunity_type": st.column_config.TextColumn("Opportunity type"),
                "gap_status": st.column_config.TextColumn("Gap status"),
                "external_units": st.column_config.NumberColumn("Brand units"),
                "internal_stores": st.column_config.NumberColumn("Planet now"),
                "gap_units": st.column_config.NumberColumn("Un-served units"),
                "est_gap_value_25pct_eur": st.column_config.NumberColumn("Est. value @25%", format="€%.0f"),
                "evidence": st.column_config.TextColumn("Evidence", width="medium"),
                "source_url": st.column_config.LinkColumn("Link", display_text="open"),
            },
        )
        download(show, "Download operators (CSV)", "operator_opportunities.csv", key="dl_ops")

# =============================================================================
# AI Briefings
# =============================================================================
with tab_narr:
    st.subheader("AI commercial briefings")
    st.caption(
        "Generated with Cortex AI_COMPLETE, grounded strictly on the mart figures above — "
        "the model is instructed to invent no locations, operators, or numbers."
    )
    if narratives.empty:
        st.info("Narratives not generated yet. Build mart_merchant_narratives (Cortex AI_COMPLETE).")
    else:
        narr = narratives[narratives["merchant"].isin(sel_merchants)].sort_values("merchant")
        if narr.empty:
            st.info("No briefings match the current merchant filter.")
        for _, row in narr.iterrows():
            title = f"{row['merchant']} — {num(row.get('country_whitespace_count', 0))} countries not served"
            with st.expander(title):
                st.markdown(as_text(row.get("narrative", "")))
                st.caption(
                    f"Model: {row.get('model_used', 'n/a')} · generated {row.get('generated_at', '')}"
                )
                with st.popover(":material/policy: Grounding facts"):
                    st.text(as_text(row.get("grounding_prompt", "")))

# =============================================================================
# Methodology & Sources
# =============================================================================
with tab_method:
    st.markdown(
        """
        ### How these numbers are built (Option A)
        - **Internal footprint** — Planet's own `DIM_CCL_CUSTOMER`, resolved to each merchant with
          audited matching (`int_brand_resolution`: include / sub-brand / exclude rules, country-scoped,
          across brand + customer_name + account). Sub-brands roll up (Sheraton → Marriott, Ibis → Accor,
          Óticas Carol / Sunglass Hut → EssilorLuxottica); false positives are excluded
          (Dolce-by-Wyndham, "passport" → SSP, parking operators → hotels). Decommissioned / test
          terminals are excluded from served counts and surfaced as **win-back**.
        - **Value** — Planet's *own* trailing-12-month realised revenue per store
          (`int_value_benchmark`), never an external estimate. White-space value =
          un-served units × per-store benchmark at **10% / 25% / 100%** capture. 25% is the planning
          case; 100% is a ceiling.
        - **External footprint** — brand-published filings / directories + public registers only. Every
          row carries `source_url` + `as_of_period` + a confidence tier (A / B / C). Google Places,
          Marketplace and scraping are **parked** behind a licence registry pending Legal sign-off.
        - **Honesty rails** — *sized* (sourced unit count) is kept distinct from *unsized* (operator known,
          count not yet sourced → a discovery-agent task). Russia and Belarus are excluded (sanctions).
          D&G's brand total is from an undated source (tier C).
        """
    )
    st.subheader("External sources used")
    cols = ["merchant", "source_name", "source_url", "as_of_period", "source_tier"]
    cov_src = coverage.rename(columns={
        "brand_source_name": "source_name", "brand_source_url": "source_url",
        "brand_as_of_period": "as_of_period", "brand_source_tier": "source_tier",
    })[cols]
    srcs = (
        pd.concat([whitespace[cols], cov_src], ignore_index=True)
        .dropna(subset=["source_url"])
        .drop_duplicates()
        .sort_values(["merchant", "source_tier"])
    )
    st.dataframe(
        srcs, width="stretch", hide_index=True,
        column_config={
            "merchant": st.column_config.TextColumn("Merchant"),
            "source_name": st.column_config.TextColumn("Source"),
            "source_url": st.column_config.LinkColumn("Link", display_text="open"),
            "as_of_period": st.column_config.TextColumn("As of"),
            "source_tier": st.column_config.TextColumn("Tier", width="small"),
        },
    )
    st.caption(
        "Tier A = brand-published or regulatory filing · B = reputable compilation citing the brand · "
        "C = undated or weak (refresh before external use)."
    )
    download(srcs, "Download sources (CSV)", "option_a_sources.csv", key="dl_src")
