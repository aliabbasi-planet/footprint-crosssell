{#
  Canonicalise a raw country string to a single uppercase name so internal
  (DIM_CCL_CUSTOMER) and external (brand filings / registers) footprints join
  cleanly. Strips parenthetical noise like " (S)" / " (D)", drops non-country
  tokens, and maps common aliases (UK, USA, CZECHIA, UAE, KOREA, ...).

  Returns NULL for noise rows so they are excluded from footprint grain.
#}
{% macro normalize_country(col) -%}
{%- set cleaned = "upper(trim(regexp_replace(" ~ col ~ ", ' *[(][^)]*[)]', '')))" -%}
case
    when {{ cleaned }} in ('', 'NONE', 'NULL', 'N/A', 'NA', 'OTHER', 'VARIOUS',
                           'MARKETING REBATES', 'EUROPEAN UNION', 'UNKNOWN') then null
    when {{ cleaned }} in ('UK', 'U.K.', 'GREAT BRITAIN', 'ENGLAND', 'SCOTLAND',
                           'WALES', 'NORTHERN IRELAND', 'ROYAUME UNI', 'UNITED KINGDOM')
        then 'UNITED KINGDOM'
    when {{ cleaned }} in ('USA', 'U.S.A.', 'US', 'U.S.', 'ETATS UNIS',
                           'UNITED STATES OF AMERICA', 'UNITED STATES') then 'UNITED STATES'
    when {{ cleaned }} in ('CZECHIA', 'CZECH REPUBLIC', 'CZECH REP') then 'CZECH REPUBLIC'
    when {{ cleaned }} in ('UAE', 'U.A.E.', 'UNITED ARAB EMIRATES') then 'UNITED ARAB EMIRATES'
    when {{ cleaned }} in ('KOREA', 'REPUBLIC OF KOREA', 'KOREA, REPUBLIC OF',
                           'KOREA REPUBLIC OF', 'SOUTH KOREA') then 'SOUTH KOREA'
    when {{ cleaned }} in ('RUSSIAN FEDERATION', 'RUSSIA') then 'RUSSIA'
    when {{ cleaned }} in ('HOLLAND', 'THE NETHERLANDS', 'NETHERLANDS') then 'NETHERLANDS'
    when {{ cleaned }} in ('HONG KONG SAR', 'HONG KONG, CHINA', 'HONG KONG') then 'HONG KONG'
    when {{ cleaned }} in ('MACAO', 'MACAU') then 'MACAU'
    when {{ cleaned }} in ('TURKIYE', 'TÜRKIYE', 'TURKEY') then 'TURKEY'
    when {{ cleaned }} in ('ST KITTS AND NEVIS', 'ST. KITTS AND NEVIS',
                           'SAINT KITTS AND NEVIS') then 'SAINT KITTS AND NEVIS'
    when {{ cleaned }} in ('UAE - DUBAI', 'DUBAI', 'ABU DHABI') then 'UNITED ARAB EMIRATES'
    when {{ cleaned }} in ('VIRGIN ISLANDS, U.S.', 'U.S. VIRGIN ISLANDS', 'US VIRGIN ISLANDS')
        then 'US VIRGIN ISLANDS'
    else {{ cleaned }}
end
{%- endmacro %}
