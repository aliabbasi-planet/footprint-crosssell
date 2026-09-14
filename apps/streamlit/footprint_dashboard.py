# Footprint Cross-Sell — Streamlit-in-Snowflake dashboard
# Reads the marts in DEV_PRESENTATION_AAB.FOOTPRINT. Deploy via Snowsight or `snow streamlit deploy`.
import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Footprint Cross-Sell", layout="wide")
session = get_active_session()

DB = "DEV_PRESENTATION_AAB"
SCHEMA = "FOOTPRINT"

st.title("Footprint & Share-of-Wallet — Cross-Sell PoC")
st.caption("Native Snowflake PoC · 9 seed merchants · internal ground-truth only")


@st.cache_data(ttl=600)
def load(table: str):
    return session.table(f"{DB}.{SCHEMA}.{table}").to_pandas()


sow = load("MART_SHARE_OF_WALLET")
opps = load("MART_CROSSSELL_OPPORTUNITIES")
footprint = load("MART_MERCHANT_FOOTPRINT")

tab1, tab2, tab3 = st.tabs(["Share of Wallet", "Cross-Sell Opportunities", "Footprint"])

with tab1:
    st.subheader("Product-portfolio coverage per merchant")
    st.dataframe(
        sow[["MERCHANT", "PRODUCTS_USED", "PRODUCTS_AVAILABLE", "PORTFOLIO_COVERAGE",
             "PRODUCTS_LIST", "TOTAL_REVENUE", "DCC_PENETRATION_PCT"]],
        use_container_width=True, hide_index=True,
    )
    st.bar_chart(sow.set_index("MERCHANT")["PORTFOLIO_COVERAGE"])

with tab2:
    st.subheader("Ranked cross-sell opportunities")
    band = st.multiselect("Confidence band", ["HIGH", "MEDIUM", "LOW"], default=["HIGH", "MEDIUM"])
    view = opps[opps["CONFIDENCE_BAND"].isin(band)].sort_values("PRIORITY_SCORE", ascending=False)
    st.dataframe(
        view[["MERCHANT", "VERTICAL", "OPPORTUNITY_TYPE", "RATIONALE", "ANNUAL_VOLUME_EUR",
              "PRIORITY_SCORE", "CONFIDENCE_BAND", "HAS_OPEN_SF_OPPORTUNITY"]],
        use_container_width=True, hide_index=True,
    )

with tab3:
    st.subheader("Served footprint by merchant & country")
    merchant = st.selectbox("Merchant", sorted(footprint["MERCHANT"].unique()))
    st.dataframe(
        footprint[footprint["MERCHANT"] == merchant]
        .sort_values("GATEWAY_VOLUME_EUR", ascending=False),
        use_container_width=True, hide_index=True,
    )
